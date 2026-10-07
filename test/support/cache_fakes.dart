import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:comic_laz/core/cache/cache_settings.dart';
import 'package:comic_laz/core/cache/image_cache_store.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/core/storage/app_directories.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// メモリ DB + 一時ディレクトリで動くキャッシュ一式。
///
/// ファイルの実体まで消えているかを確かめたいのでディスクは使うが、
/// 置き場所は一時ディレクトリにする（`path_provider` のプラットフォーム
/// チャネルは触らない）。
class CacheHarness {
  CacheHarness._({
    required this.database,
    required this.directories,
    required this.settingsStore,
    required this.store,
    required this.clock,
  });

  /// テスト用のキャッシュを組み立てる（後片付けも登録する）。
  factory CacheHarness.create({DateTime? now}) {
    final root = Directory.systemTemp.createTempSync('comic_laz_cache');
    final directories = AppDirectories(
      support: Directory(p.join(root.path, 'support')),
      cache: Directory(p.join(root.path, 'cache')),
    );
    for (final directory in [
      directories.support,
      directories.cache,
      directories.imageCache,
      directories.downloads,
    ]) {
      directory.createSync(recursive: true);
    }

    final database = AppDatabase(NativeDatabase.memory());
    final settingsStore = CacheSettingsStore(database);
    final clock = TestClock(now ?? DateTime.utc(2026, 1, 1, 12));
    final harness = CacheHarness._(
      database: database,
      directories: directories,
      settingsStore: settingsStore,
      clock: clock,
      store: ImageCacheStore(
        database: database,
        directories: directories,
        settingsStore: settingsStore,
        now: clock.now,
      ),
    );

    addTearDown(() async {
      await database.close();
      try {
        if (root.existsSync()) root.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows では掃除中のファイルが掴まれていることがある。
        // 一時ディレクトリなので OS に任せ、後片付けの失敗でテストは落とさない。
      }
    });
    return harness;
  }

  final AppDatabase database;
  final AppDirectories directories;
  final CacheSettingsStore settingsStore;
  final ImageCacheStore store;

  /// 保持期間 / LRU の順序をテストから決めるための時計。
  final TestClock clock;

  /// キャッシュディレクトリにある実ファイルの数。
  int get fileCount =>
      directories.imageCache.listSync().whereType<File>().length;

  /// [key] の実体が残っているか。
  bool hasFile(String key) => File(
    p.join(directories.imageCache.path, ImageCacheStore.fileNameFor(key)),
  ).existsSync();

  /// 保存済みのキー（最後に使った時刻の古い順）。
  Future<List<String>> keysByLastUsed() async {
    final rows = await (database.select(
      database.cachedImages,
    )..orderBy([(table) => OrderingTerm.asc(table.lastUsedAt)])).get();
    return [for (final row in rows) row.key];
  }

  /// 実ファイルを作らずにメタ情報だけ積む。
  ///
  /// - 上限（256MB 以上）を超えた状態を作れる（実際に数百 MB 書かない）
  /// - ファイル I/O が無いので `testWidgets`（擬似時間）でも詰まらない
  Future<void> record(
    String key, {
    required int bytes,
    CachedImageKind kind = CachedImageKind.page,
    Duration? after,
  }) async {
    if (after != null) clock.advance(after);
    final now = clock.now();
    await database
        .into(database.cachedImages)
        .insertOnConflictUpdate(
          CachedImageRow(
            key: key,
            kind: kind,
            fileName: ImageCacheStore.fileNameFor(key),
            bytes: bytes,
            createdAt: now,
            lastUsedAt: now,
          ),
        );
  }

  /// ダウンロード済み領域（#9）に置いたダミーファイル。
  ///
  /// 「キャッシュ削除でダウンロード済みデータが消えない」ことの確認に使う。
  File createDownloadedFile(String name) {
    final file = File(p.join(directories.downloads.path, name))
      ..writeAsBytesSync(imageBytes(8));
    return file;
  }

  /// 画像 1 枚を書き込む。`bytes` はサイズだけが意味を持つ。
  Future<void> write(
    String key, {
    required int bytes,
    CachedImageKind kind = CachedImageKind.page,
    Duration? after,
  }) async {
    if (after != null) clock.advance(after);
    await store.write(key: key, kind: kind, bytes: imageBytes(bytes));
  }

  /// 大量の行をまとめて積む（SQLite の変数上限を超える削除の検証用）。
  ///
  /// 1 件ずつ insert すると数万件で時間がかかるため、まとめて入れる。
  Future<void> recordMany(
    int count, {
    required int bytes,
    CachedImageKind kind = CachedImageKind.page,
    String prefix = 'v1/1/',
  }) async {
    final now = clock.now();
    await database.batch((batch) {
      batch.insertAll(database.cachedImages, [
        for (var i = 0; i < count; i++)
          CachedImageRow(
            key: '$prefix$i',
            kind: kind,
            fileName: ImageCacheStore.fileNameFor('$prefix$i'),
            bytes: bytes,
            createdAt: now,
            lastUsedAt: now,
          ),
      ]);
    });
  }

  /// 同じ DB / ディレクトリを使う別実装のキャッシュを作る（失敗の再現用）。
  T storeLike<T extends ImageCacheStore>(
    T Function({
      required AppDatabase database,
      required AppDirectories directories,
      required CacheSettingsStore settingsStore,
      DateTime Function() now,
    })
    build,
  ) => build(
    database: database,
    directories: directories,
    settingsStore: settingsStore,
    now: clock.now,
  );

  /// キャッシュ関連のプロバイダを差し替える override 群。
  ///
  /// [store] を渡すと本体だけ差し替える（削除が失敗する / 完了を待たせる等）。
  List<Override> overrides({ImageCacheStore? store}) => [
    appDatabaseProvider.overrideWithValue(database),
    appDirectoriesProvider.overrideWith((ref) async => directories),
    cacheSettingsStoreProvider.overrideWithValue(settingsStore),
    imageCacheStoreProvider.overrideWith((ref) async => store ?? this.store),
  ];
}

/// ファイルの読み出しだけが必ず失敗するキャッシュ。
///
/// 掃除や OS のキャッシュ削除が、行を読んだ直後に実体を消した状況を作る。
class BrokenFileCacheStore extends ImageCacheStore {
  BrokenFileCacheStore({
    required super.database,
    required super.directories,
    required super.settingsStore,
    super.now,
    this.error = const PathNotFoundException('cache', OSError('見つかりません', 2)),
  });

  /// 読み出しで投げる例外。既定は「実体が無い」。
  final FileSystemException error;

  @override
  Future<Uint8List> readFileBytes(File file) async => throw error;
}

/// 実体を書き終えたところで止まるキャッシュ（行を入れる前の瞬間を作る）。
///
/// 孤児の掃除がその瞬間に割り込んでも、書き込み中の実体を消さないことの確認用。
class GatedWriteCacheStore extends ImageCacheStore {
  GatedWriteCacheStore({
    required super.database,
    required super.directories,
    required super.settingsStore,
    super.now,
  });

  /// 実体を書き終えたら完了する。
  final written = Completer<void>();

  /// 完了させると行の登録へ進む。
  final gate = Completer<void>();

  @override
  Future<void> writeFileBytes(File file, Uint8List bytes) async {
    await super.writeFileBytes(file, bytes);
    written.complete();
    await gate.future;
  }
}

/// 孤児の掃除が行を読んだ直後に、止めておいた書き込みを最後まで進めるキャッシュ。
///
/// 「行を読んだ後・ループがそのファイルに届く前に書き込みが終わる」並びを
/// 確実に作る（その時点では行も書き込み中の印も見えない）。
class SweepInterleavingCacheStore extends GatedWriteCacheStore {
  SweepInterleavingCacheStore({
    required super.database,
    required super.directories,
    required super.settingsStore,
    super.now,
  });

  /// 掃除の途中で終わらせる書き込み。
  Future<void>? pendingWrite;

  @override
  Future<void> afterOrphanRowsRead() async {
    final write = pendingWrite;
    if (write == null) return;
    gate.complete();
    await write;
  }
}

/// 読み出しが必ず失敗するキャッシュ（DB ごと壊れた状況）。
class UnreadableCacheStore extends ImageCacheStore {
  UnreadableCacheStore({
    required super.database,
    required super.directories,
    required super.settingsStore,
    super.now,
  });

  @override
  Future<CachedImage?> read(String key) async =>
      throw const FileSystemException('キャッシュを読めません');
}

/// 削除が必ず失敗するキャッシュ（SQLite / ファイルの失敗をテストから作る）。
class FailingClearCacheStore extends ImageCacheStore {
  FailingClearCacheStore({
    required super.database,
    required super.directories,
    required super.settingsStore,
    super.now,
  });

  @override
  Future<void> clear({CachedImageKind? kind}) async =>
      throw const FileSystemException('キャッシュを削除できません');
}

/// 削除の完了を外から決められるキャッシュ（画面を離れる操作と競わせる）。
class GatedClearCacheStore extends ImageCacheStore {
  GatedClearCacheStore({
    required super.database,
    required super.directories,
    required super.settingsStore,
    super.now,
  });

  final gate = Completer<void>();

  @override
  Future<void> clear({CachedImageKind? kind}) async {
    await gate.future;
    return super.clear(kind: kind);
  }
}

/// 進む時刻を自分で決められる時計。
class TestClock {
  TestClock(this._now);

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);

  set value(DateTime next) => _now = next;
}

/// 指定サイズのダミー画像バイト列。
Uint8List imageBytes(int length, {int fill = 0x42}) =>
    Uint8List.fromList(List.filled(length, fill));
