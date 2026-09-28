import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/app_database.dart';
import '../storage/app_directories.dart';
import 'cache_settings.dart';

part 'image_cache_store.g.dart';

/// キャッシュから取り出した画像。
class CachedImage {
  const CachedImage({required this.bytes, this.contentType});

  final Uint8List bytes;
  final String? contentType;
}

/// 種別ごとの使用量。
class CacheUsage {
  const CacheUsage({
    required this.pageBytes,
    required this.pageCount,
    required this.thumbnailBytes,
    required this.thumbnailCount,
  });

  static const empty = CacheUsage(
    pageBytes: 0,
    pageCount: 0,
    thumbnailBytes: 0,
    thumbnailCount: 0,
  );

  final int pageBytes;
  final int pageCount;
  final int thumbnailBytes;
  final int thumbnailCount;

  int get totalBytes => pageBytes + thumbnailBytes;

  int get totalCount => pageCount + thumbnailCount;

  int bytesOf(CachedImageKind kind) =>
      kind == CachedImageKind.page ? pageBytes : thumbnailBytes;

  int countOf(CachedImageKind kind) =>
      kind == CachedImageKind.page ? pageCount : thumbnailCount;

  @override
  bool operator ==(Object other) =>
      other is CacheUsage &&
      other.pageBytes == pageBytes &&
      other.pageCount == pageCount &&
      other.thumbnailBytes == thumbnailBytes &&
      other.thumbnailCount == thumbnailCount;

  @override
  int get hashCode =>
      Object.hash(pageBytes, pageCount, thumbnailBytes, thumbnailCount);

  @override
  String toString() =>
      'CacheUsage(page: $pageCount/$pageBytes, '
      'thumbnail: $thumbnailCount/$thumbnailBytes)';
}

/// 画像の一時キャッシュ（ディスク LRU + メタ情報は drift）。
///
/// - 上限は**種別ごと**に持つ（ページは大きく数が少ない、サムネイルは小さく数が多い）
/// - 上限超過は最後に使った時刻の古い順に削除する
/// - 保持期間を過ぎたものも削除する
/// - **ダウンロード済みデータ（#9）はこの対象外**（勝手に消さない）
///
/// メモリ上のデコード済み画像は Flutter の `ImageCache` が持つため、ここでは
/// ディスクのみを扱う（二重に持たない）。
class ImageCacheStore {
  ImageCacheStore({
    required this.database,
    required this.directories,
    required this.settingsStore,
    this.now = DateTime.now,
  });

  final AppDatabase database;
  final AppDirectories directories;
  final CacheSettingsStore settingsStore;

  /// 現在時刻。保持期間 / LRU の順序をテストから決められるようにする。
  final DateTime Function() now;

  /// 掃除は同時に走らせない（直列化のための鎖）。
  Future<void>? _eviction;

  /// キーからファイル名を作る（キーには `/` が含まれるため符号化する）。
  static String fileNameFor(String key) =>
      base64Url.encode(utf8.encode(key)).replaceAll('=', '');

  File _fileFor(String fileName) =>
      File(p.join(directories.imageCache.path, fileName));

  /// キャッシュから読む。無ければ `null`。
  Future<CachedImage?> read(String key) async {
    final row = await (database.select(
      database.cachedImages,
    )..where((table) => table.key.equals(key))).getSingleOrNull();
    if (row == null) return null;

    final file = _fileFor(row.fileName);
    if (!file.existsSync()) {
      // 実体だけ消えている（OS によるキャッシュ削除など）。メタ情報も捨てる。
      await _deleteRows([row]);
      return null;
    }

    // LRU の基準を更新する（読めなかった場合に備え、読み出しは先に行う）。
    final bytes = await file.readAsBytes();
    await (database.update(database.cachedImages)
          ..where((table) => table.key.equals(key)))
        .write(CachedImagesCompanion(lastUsedAt: Value(now())));

    return CachedImage(bytes: bytes, contentType: row.contentType);
  }

  /// キャッシュへ書く。書いたあと必要なら古いものを削除する。
  Future<void> write({
    required String key,
    required CachedImageKind kind,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final fileName = fileNameFor(key);
    final file = _fileFor(fileName);
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: false);

    final writtenAt = now();
    await database
        .into(database.cachedImages)
        .insertOnConflictUpdate(
          CachedImageRow(
            key: key,
            kind: kind,
            fileName: fileName,
            bytes: bytes.length,
            contentType: contentType,
            createdAt: writtenAt,
            lastUsedAt: writtenAt,
          ),
        );

    // 書き込みのたびに待たせない（次の読み出しを妨げない）。
    // 掃除の失敗で画像の表示を失敗扱いにはしない。
    unawaited(evictIfNeeded().catchError((Object _) {}));
  }

  /// 使用量（種別ごと）。
  Future<CacheUsage> usage() async {
    final bytes = database.cachedImages.bytes.sum();
    final count = database.cachedImages.key.count();
    final query = database.selectOnly(database.cachedImages)
      ..addColumns([database.cachedImages.kind, bytes, count])
      ..groupBy([database.cachedImages.kind]);

    var pageBytes = 0;
    var pageCount = 0;
    var thumbnailBytes = 0;
    var thumbnailCount = 0;

    for (final row in await query.get()) {
      // `selectOnly` は変換前（DB に入っている文字列）で返ってくる。
      final kind = row.read(database.cachedImages.kind);
      final sum = row.read(bytes) ?? 0;
      final rows = row.read(count) ?? 0;
      if (kind == CachedImageKind.page.name) {
        pageBytes = sum;
        pageCount = rows;
      } else {
        thumbnailBytes = sum;
        thumbnailCount = rows;
      }
    }

    return CacheUsage(
      pageBytes: pageBytes,
      pageCount: pageCount,
      thumbnailBytes: thumbnailBytes,
      thumbnailCount: thumbnailCount,
    );
  }

  /// 上限超過分と期限切れを削除する。
  ///
  /// 走っている掃除がある場合は**その後ろに並べる**（同じ future を返してしまうと、
  /// 上限を下げた直後の呼び出しが古い設定の掃除で終わったことになる）。
  Future<void> evictIfNeeded() {
    final previous = _eviction ?? Future<void>.value();
    final next = previous.then((_) => _evict());
    // 直列化のための鎖なので、失敗しても次の掃除は続けられるようにする。
    _eviction = next.catchError((Object _) {});
    return next;
  }

  Future<void> _evict() async {
    final settings = await settingsStore.read();

    // 期限切れ（保持期間を過ぎたもの）。
    if (settings.retention.duration case final retention?) {
      final threshold = now().subtract(retention);
      final expired =
          await (database.select(database.cachedImages)..where(
                (table) => table.lastUsedAt.isSmallerThanValue(threshold),
              ))
              .get();
      await _deleteRows(expired);
    }

    // 種別ごとの上限。
    for (final kind in CachedImageKind.values) {
      final limit = kind == CachedImageKind.page
          ? settings.pageLimit.bytes
          : settings.thumbnailLimit.bytes;
      if (limit == null) continue;
      await evictToLimit(kind, limit);
    }
  }

  /// [kind] の合計が [limitBytes] 以下になるまで、古い順に削除する。
  ///
  /// 設定の上限は 256MB 以上なので、削除順の検証はここを直接呼ぶ。
  @visibleForTesting
  Future<void> evictToLimit(CachedImageKind kind, int limitBytes) async {
    final rows =
        await (database.select(database.cachedImages)
              ..where((table) => table.kind.equalsValue(kind))
              // 古い順（最後に使った時刻）に消す。
              ..orderBy([(table) => OrderingTerm.asc(table.lastUsedAt)]))
            .get();

    var total = rows.fold<int>(0, (sum, row) => sum + row.bytes);
    if (total <= limitBytes) return;

    final victims = <CachedImageRow>[];
    for (final row in rows) {
      if (total <= limitBytes) break;
      victims.add(row);
      total -= row.bytes;
    }
    await _deleteRows(victims);
  }

  /// 一時キャッシュを削除する。[kind] を指定するとその種別だけ。
  ///
  /// **ダウンロード済みデータは消さない**（別領域 / 別テーブル）。
  Future<void> clear({CachedImageKind? kind}) async {
    final query = database.select(database.cachedImages);
    if (kind != null) query.where((table) => table.kind.equalsValue(kind));
    await _deleteRows(await query.get());
  }

  /// ZIP が差し替わった巻の古い世代を捨てる。
  ///
  /// キーは `v{volumeId}/{filesVersion}/{page}` なので、巻の接頭辞で選んで
  /// 現在の世代以外を消す。
  Future<void> evictOtherVersions({
    required int volumeId,
    required int keepFilesVersion,
  }) async {
    final prefix = 'v$volumeId/';
    final keepPrefix = 'v$volumeId/$keepFilesVersion/';
    final rows = await (database.select(
      database.cachedImages,
    )..where((table) => table.key.like('$prefix%'))).get();

    await _deleteRows([
      for (final row in rows)
        if (!row.key.startsWith(keepPrefix)) row,
    ]);
  }

  Future<void> _deleteRows(List<CachedImageRow> rows) async {
    if (rows.isEmpty) return;

    for (final row in rows) {
      final file = _fileFor(row.fileName);
      try {
        if (file.existsSync()) await file.delete();
      } on FileSystemException {
        // 消せなくてもメタ情報は消す（次回の書き込みで上書きされる）。
      }
    }

    await database.batch((batch) {
      batch.deleteWhere(
        database.cachedImages,
        (table) => table.key.isIn(rows.map((row) => row.key)),
      );
    });
  }
}

@Riverpod(keepAlive: true)
Future<ImageCacheStore> imageCacheStore(Ref ref) async {
  return ImageCacheStore(
    database: ref.watch(appDatabaseProvider),
    directories: await ref.watch(appDirectoriesProvider.future),
    settingsStore: ref.watch(cacheSettingsStoreProvider),
  );
}

/// 巻を開いたときに、その巻の**古い世代**のキャッシュを捨てる処理。
///
/// キーに `files_version` を含めているので古い画像が表示されることは無いが、
/// 放置すると二度と使われないファイルが容量を食い続ける。
/// テストでは差し替える（キャッシュ本体を用意せずに済むように）。
typedef StaleCacheEvictor = Future<void> Function({
  required int volumeId,
  required int keepFilesVersion,
});

@Riverpod(keepAlive: true)
StaleCacheEvictor staleCacheEvictor(Ref ref) {
  return ({required int volumeId, required int keepFilesVersion}) async {
    final store = await ref.read(imageCacheStoreProvider.future);
    await store.evictOtherVersions(
      volumeId: volumeId,
      keepFilesVersion: keepFilesVersion,
    );
  };
}
