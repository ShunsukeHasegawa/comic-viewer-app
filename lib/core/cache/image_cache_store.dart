import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
/// - 保護印（[PinnedImages]）が付いた画像は LRU / 保持期間で消さない（#11）
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

  /// 実行中の掃除。
  Future<void>? _running;

  /// 実行中の掃除の後ろに並べた 1 本（何本も積まないための待ち合わせ）。
  Future<void>? _queued;

  /// 削除の世代。[clear] のたびに進む。
  ///
  /// ログアウト（`ImageCachePurger`）の破棄より前に始まった取得が、破棄の後に
  /// 完了して前のユーザーの画像を書き戻さないようにするための仕切り。
  int get generation => _generation;
  int _generation = 0;

  /// 1 文で消すキーの数。
  ///
  /// SQLite の変数上限（32766）を超えると `IN (?, ?, …)` の削除が丸ごと失敗し、
  /// 「実体だけ消えて行が残る」不整合になるため、必ず区切って消す。
  static const _deleteChunkSize = 500;

  /// 上限超過の掃除で 1 回に読む行の数。
  ///
  /// 超過は書き込み数件分のことがほとんどなので、全行を Dart に読み込まず
  /// 古い方から少しずつ読む。
  static const _evictPageSize = 200;

  /// ヒット時に `lastUsedAt` を書き直す最短の間隔。
  ///
  /// グリッドの再描画などで同じ画像が短時間に何度も読まれるたびに UPDATE を
  /// 打たないため。LRU / 保持期間の判断は分〜日の単位なので、この程度の
  /// ずれでは消す順番がほぼ変わらない。
  @visibleForTesting
  static const lastUsedRefreshInterval = Duration(minutes: 1);

  /// 書き込み中（実体はあるが行がまだ無い）のファイル名。
  ///
  /// 孤児の掃除が「書き終えて行を入れる直前」の実体を消さないための印。
  /// 掃除の列挙を非同期にしたので、その間に書き込みが割り込みうる。
  /// 値は並行して書いている本数（同じキーを同時に取得することがある）。
  final _writing = <String, int>{};

  /// 実行中の孤児の掃除ごとの「掃除の間に書き始めたファイル名」。
  final _sweepObservers = <Set<String>>[];

  /// キーからファイル名を作る（キーには `/` が含まれるため符号化する）。
  static String fileNameFor(String key) =>
      base64Url.encode(utf8.encode(key)).replaceAll('=', '');

  File _fileFor(String fileName) =>
      File(p.join(directories.imageCache.path, fileName));

  /// ファイルの読み出し。
  ///
  /// テストから I/O の失敗（掃除や OS のキャッシュ削除との競合）を再現するための
  /// 差し替え口。本番では [File.readAsBytes] そのもの。
  @visibleForTesting
  Future<Uint8List> readFileBytes(File file) => file.readAsBytes();

  /// ファイルの書き込み。
  ///
  /// テストから「実体は書き終えたが行はまだ無い」瞬間を作るための差し替え口。
  /// 本番では [File.writeAsBytes] そのもの。
  @visibleForTesting
  Future<void> writeFileBytes(File file, Uint8List bytes) =>
      file.writeAsBytes(bytes, flush: false);

  /// 孤児の掃除が行を読み終えた直後（ファイルを見ていく前）。
  ///
  /// テストから「行を読んだ後に書き込みが終わる」並びを作るための差し替え口。
  /// 本番では何もしない。
  @visibleForTesting
  Future<void> afterOrphanRowsRead() async {}

  /// キャッシュから読む。無ければ `null`。
  ///
  /// **読み出しの失敗は投げずにキャッシュミスとして返す**。ここで投げると
  /// ネットワークから取り直せるはずの画像が「読み込めませんでした」になる。
  Future<CachedImage?> read(String key) async {
    final row = await (database.select(
      database.cachedImages,
    )..where((table) => table.key.equals(key))).getSingleOrNull();
    if (row == null) return null;

    final file = _fileFor(row.fileName);
    final Uint8List bytes;
    try {
      // 事前に存在を確かめず、読んでみて失敗したらミスにする（UI isolate で
      // 同期の `existsSync` を打たない。確かめても直後に消されうるので同じこと）。
      bytes = await readFileBytes(file);
    } on PathNotFoundException {
      // 実体だけ消えている（OS によるキャッシュ削除 / 掃除 / 手動削除との競合）。
      // 無い実体のメタ情報は捨て、呼び出し側にはミスとして返す。
      await _deleteRows([row]);
      return null;
    } on FileSystemException {
      // ロック / ファイルを開きすぎ（EMFILE）/ 権限など一時的かもしれない失敗。
      // 実体はまだあるので消さず、今回だけミスにする（ネットワークから取り直す）。
      return null;
    }

    // LRU の基準を更新する（読めなかった場合に備え、読み出しの後で行う）。
    // 直近に更新したばかりなら書き直さない（ヒットのたびに UPDATE しない）。
    final usedAt = now();
    if (usedAt.difference(row.lastUsedAt) >= lastUsedRefreshInterval) {
      await (database.update(database.cachedImages)
            ..where((table) => table.key.equals(key)))
          .write(CachedImagesCompanion(lastUsedAt: Value(usedAt)));
    }

    return CachedImage(bytes: bytes, contentType: row.contentType);
  }

  /// キャッシュへ書く。書いたあと必要なら古いものを削除する。
  ///
  /// [generation] を渡すと、取得を始めた時点より後に [clear] が走っていた場合に
  /// 書き込みを捨てる（ログアウト後に前のユーザーの画像を書き戻さない）。
  Future<void> write({
    required String key,
    required CachedImageKind kind,
    required Uint8List bytes,
    String? contentType,
    int? generation,
  }) async {
    if (generation != null && generation != _generation) return;

    final fileName = fileNameFor(key);
    final file = _fileFor(fileName);
    // 印は本数で数える。単なる集合だと、同じキーを並行して書いたときに先に
    // 終わった方が印を外し、まだ行を入れていない方の実体が孤児扱いされうる。
    _writing[fileName] = (_writing[fileName] ?? 0) + 1;
    for (final observer in _sweepObservers) {
      observer.add(fileName);
    }
    try {
      // 既にあれば何もしない（OS がキャッシュディレクトリごと消すことがある）。
      await file.parent.create(recursive: true);
      await writeFileBytes(file, bytes);

      if (generation != null && generation != _generation) {
        // 書いている最中に全削除が入った。実体も残さない。
        await _deleteFile(file);
        return;
      }

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
    } finally {
      final remaining = (_writing[fileName] ?? 1) - 1;
      if (remaining <= 0) {
        _writing.remove(fileName);
      } else {
        _writing[fileName] = remaining;
      }
    }

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
  /// 走っている掃除がある場合は**その後ろに 1 本だけ並べる**。
  /// - 同じ future を返すと、上限を下げた直後の呼び出しが古い設定の掃除で
  ///   終わったことになる（並べた 1 本は設定を読み直してから走る）。
  /// - 呼ばれた回数だけ積むと、グリッドを一気にスクロールしたときに全件走査の
  ///   掃除が何十本も直列に走り、その後ろで画像の読み出しが待たされる。
  Future<void> evictIfNeeded() {
    final running = _running;
    if (running == null) return _startEviction();
    return _queued ??= running.then((_) => _startEviction());
  }

  Future<void> _startEviction() {
    // これから走るので「並んでいる 1 本」の席を空ける。
    _queued = null;
    final task = _evict();
    // 直列化のための鎖なので、失敗しても次の掃除は続けられるようにする。
    final chained = task.catchError((Object _) {});
    _running = chained;
    unawaited(
      chained.whenComplete(() {
        if (identical(_running, chained)) _running = null;
      }),
    );
    return task;
  }

  Future<void> _evict() async {
    final settings = await settingsStore.read();

    // 期限切れ（保持期間を過ぎたもの）。保護印の付いた画像は SQL 側で外し、
    // 期限切れの行だけを読む（全行も全部の印も Dart に読み込まない）。
    if (settings.retention.duration case final retention?) {
      final threshold = now().subtract(retention);
      final expired =
          await (database.select(database.cachedImages)..where(
                (table) =>
                    table.lastUsedAt.isSmallerThanValue(threshold) &
                    _isNotPinned(table),
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

  /// 保護印（#11）が付いていない行。
  Expression<bool> _isNotPinned($CachedImagesTable table) {
    final pinned = database.selectOnly(database.pinnedImages)
      ..addColumns([database.pinnedImages.key]);
    return table.key.isNotInQuery(pinned);
  }

  /// [kind] の合計バイト数（保護印の付いた画像も含む）。
  Future<int> _bytesOf(CachedImageKind kind) async {
    final sum = database.cachedImages.bytes.sum();
    final query = database.selectOnly(database.cachedImages)
      ..addColumns([sum])
      ..where(database.cachedImages.kind.equalsValue(kind));
    return (await query.getSingle()).read(sum) ?? 0;
  }

  /// [kind] の合計が [limitBytes] 以下になるまで、古い順に削除する。
  ///
  /// 設定の上限は 256MB 以上なので、削除順の検証はここを直接呼ぶ。
  ///
  /// 書き込みのたびに走るので、まず合計（`SUM(bytes)`）だけを確かめ、超えて
  /// いなければ行を読まない。超えていれば古い方から [_evictPageSize] 件ずつ
  /// 読んで消す（超過は数件分のことがほとんどで、全行を読むのは無駄）。
  ///
  /// 保護印の付いた画像は削除しないが、**合計には数える**。
  /// 数えないと上限を超えて使い続けることになるので、保護対象が多いときは
  /// その分だけ普通の画像が早く追い出される。
  @visibleForTesting
  Future<void> evictToLimit(CachedImageKind kind, int limitBytes) async {
    while (true) {
      // 合計は区切りごとに読み直す。手元で引き算し続けると、並行して走る
      // 削除（世代の入れ替え / 読み出し失敗の後始末）の分を二重に数えて
      // 消しすぎる。
      var total = await _bytesOf(kind);
      if (total <= limitBytes) return;

      final rows =
          await (database.select(database.cachedImages)
                ..where(
                  (table) => table.kind.equalsValue(kind) & _isNotPinned(table),
                )
                // 古い順（最後に使った時刻）に消す。同時刻はキーで順番を固定する。
                ..orderBy([
                  (table) => OrderingTerm.asc(table.lastUsedAt),
                  (table) => OrderingTerm.asc(table.key),
                ])
                ..limit(_evictPageSize))
              .get();
      // 残りが保護印つきだけなら、それ以上は消せない。
      if (rows.isEmpty) return;

      final victims = <CachedImageRow>[];
      for (final row in rows) {
        if (total <= limitBytes) break;
        victims.add(row);
        total -= row.bytes;
      }
      // 消した行は次の読み出しに現れないので、毎回先頭から読めばよい。
      await _deleteRows(victims);
    }
  }

  /// 保護印の付いたキャッシュキー（#11）。
  Future<Set<String>> pinnedKeys() async {
    final key = database.pinnedImages.key;
    final rows = await (database.selectOnly(
      database.pinnedImages,
    )..addColumns([key])).get();
    return {for (final row in rows) ?row.read(key)};
  }

  /// [bookId] のために [keys] を保護する。
  ///
  /// 実体がまだ無いキーでも印は置ける（次に取得したものがそのまま守られる）。
  Future<void> pin({
    required int bookId,
    required Iterable<String> keys,
  }) async {
    final rows = [
      for (final key in keys) PinnedImageRow(key: key, bookId: bookId),
    ];
    if (rows.isEmpty) return;
    await database.batch((batch) {
      batch.insertAllOnConflictUpdate(database.pinnedImages, rows);
    });
  }

  /// [bookIds] 以外のタイトルの保護印を外す（ダウンロードを消したとき）。
  Future<void> retainPins(Set<int> bookIds) async {
    final query = database.delete(database.pinnedImages);
    if (bookIds.isNotEmpty) {
      query.where((table) => table.bookId.isNotIn(bookIds));
    }
    await query.go();
  }

  /// 一時キャッシュを削除する。[kind] を指定するとその種別だけ。
  ///
  /// **ダウンロード済みデータは消さない**（別領域 / 別テーブル）。
  /// 保護印（#11）の付いた画像も、ユーザーが明示的に「削除」を選んだときは消す。
  /// 印そのものは残すので、オンラインで取り直した分から再び守られる
  /// （ログアウト時は `OfflineMetadataPurger` が印ごと捨てる）。
  Future<void> clear({CachedImageKind? kind}) async {
    // 進行中の取得が破棄の後に書き戻さないよう、世代を進める。
    _generation++;

    final table = database.cachedImages;
    if (kind == null) {
      // 全部消すとき（ログアウトなど数万件になりうる）は行を 1 文で消し、実体は
      // 下の孤児の掃除でディレクトリの列挙 1 回でまとめて消す（1 件ずつ存在を
      // 確かめない）。行が先なので、途中で失敗しても残るのは孤児の実体だけで、
      // 次の削除操作で回収される（行だけ残って使用量が嘘になることはない）。
      await database.delete(table).go();
    } else {
      // 消すのに要るのはキーとファイル名だけ。全列を行オブジェクトに
      // 変換しない（件数が多いと日時の変換だけで秒単位になる）。
      final query = database.selectOnly(table)
        ..addColumns([table.key, table.fileName])
        ..where(table.kind.equalsValue(kind));
      await _deleteEntries([
        for (final row in await query.get())
          (key: row.read(table.key)!, fileName: row.read(table.fileName)!),
      ]);
    }

    // 行を持たない実体（書き込みの途中で落ちた分）もここで回収する。
    await sweepOrphanFiles();
  }

  /// 行が無いのに残っている実体を消す。
  ///
  /// 書き込みは「実体 → 行」の順なので、途中で失敗したり OS に kill されたりすると
  /// 実体だけが残る。孤児は `usage()` にも [clear] にも現れず永久に容量を食うため、
  /// 削除操作のたびに回収する。
  ///
  /// 列挙は非同期（UI isolate を止めない）。**先に列挙してから行を読む**ので、
  /// 列挙の時点で行を入れ終えていた実体は必ず「既知」に入る。行を入れる前の
  /// 実体（書き込み中）は [_writing] で外す。
  @visibleForTesting
  Future<void> sweepOrphanFiles() async {
    // 掃除の間に始まった書き込みのファイル名。行を読んだ後に書き終えて
    // [_writing] から外れたものも、ここに残るので消さない。
    final startedDuringSweep = <String>{};
    _sweepObservers.add(startedDuringSweep);
    try {
      final files = <File>[];
      try {
        await for (final entity in directories.imageCache.list()) {
          if (entity is File) files.add(entity);
        }
      } on PathNotFoundException {
        // ディレクトリごと無い（OS が消した）なら孤児も無い。
        return;
      }
      // それ以外の列挙の失敗は投げる。握ると削除（ログアウト時の破棄）が
      // 成功扱いになり、やり直しの印が消えてしまう（#15）。
      if (files.isEmpty) return;

      // 行を読む**前**に書き込み中の名前を控える。行を読んだ後・ループが
      // そのファイルに届く前に書き終えたものは、行も [_writing] も見えない。
      final writingAtQuery = {..._writing.keys};
      final fileName = database.cachedImages.fileName;
      final rows = await (database.selectOnly(
        database.cachedImages,
      )..addColumns([fileName])).get();
      final known = {for (final row in rows) row.read(fileName)};
      await afterOrphanRowsRead();

      for (final file in files) {
        final name = p.basename(file.path);
        if (known.contains(name) ||
            writingAtQuery.contains(name) ||
            startedDuringSweep.contains(name) ||
            _writing.containsKey(name)) {
          continue;
        }
        await _deleteFile(file);
      }
    } finally {
      _sweepObservers.remove(startedDuringSweep);
    }
  }

  /// ZIP が差し替わった巻の古い世代を捨てる。
  ///
  /// キーは `v{volumeId}/{filesVersion}/{page}@{配信元}` なので、巻の接頭辞で
  /// 選んで現在の世代以外を消す。
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

  Future<void> _deleteFile(File file) async {
    try {
      // 先に確かめる（無いファイルの削除は例外になり、数万件の破棄で重い）。
      // `exists` は非同期版の方が遅い（avoid_slow_async_io）。確かめた直後に
      // 消えても下の catch で拾う。
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // 既に無い / 消せなくてもメタ情報は消す（次回の書き込みで上書きされる）。
    }
  }

  Future<void> _deleteRows(List<CachedImageRow> rows) => _deleteEntries([
    for (final row in rows) (key: row.key, fileName: row.fileName),
  ]);

  Future<void> _deleteEntries(List<_CacheEntry> rows) async {
    if (rows.isEmpty) return;

    // 実体と行を同じ区切りで消す（実体を全件消してから 1 文で行を消すと、
    // 変数上限に当たったときに「実体だけ消えて行が全部残る」不整合になる）。
    for (var start = 0; start < rows.length; start += _deleteChunkSize) {
      final chunk = rows.sublist(
        start,
        math.min(start + _deleteChunkSize, rows.length),
      );
      // 非同期の削除を 1 件ずつ待つと、数万件の破棄（ログアウト）で往復待ちが
      // 積み上がる。区切りの中はまとめて投げる（それぞれ別のファイル）。
      await Future.wait([
        for (final row in chunk) _deleteFile(_fileFor(row.fileName)),
      ]);
      await database.batch((batch) {
        batch.deleteWhere(
          database.cachedImages,
          (table) => table.key.isIn(chunk.map((row) => row.key)),
        );
      });
    }
  }
}

/// 削除に要る最小限（キーとファイル名）。
typedef _CacheEntry = ({String key, String fileName});

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
