import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'download_store.dart';
import 'zip_page_index.dart';

part 'downloaded_page_source.g.dart';

/// ダウンロード済み ZIP からページ画像を取り出す口（#11）。
///
/// `ComicImageLoader` から呼ばれる。テストではフェイクに差し替えられるように
/// 抽象を切る（ZIP を作らずに解決順だけ確かめられるようにするため）。
abstract interface class DownloadedPageSource {
  /// 端末にあるページのバイト列。無ければ `null`（キャッシュ / ネットワークへ）。
  ///
  /// [filesVersion] はサーバーが返した世代。**食い違ったら `null` を返す**
  /// （勝手に消さず「更新あり」としてネットワークから取りに行かせる）。
  Future<Uint8List?> readPage({
    required int volumeId,
    required int page,
    required int filesVersion,
  });
}

/// 何も持っていない実装（ダウンロード機能を使わない経路 / テストの既定）。
class NoDownloadedPageSource implements DownloadedPageSource {
  const NoDownloadedPageSource();

  @override
  Future<Uint8List?> readPage({
    required int volumeId,
    required int page,
    required int filesVersion,
  }) async => null;
}

/// ZIP のまま保持したアーカイブから 1 ページだけ取り出す実装。
///
/// **読んだページを一時キャッシュへ写さない**。1 ページの取り出しは
/// セントラルディレクトリの位置情報で対象エントリだけを展開するので軽く、
/// - 同じ画像をディスクに二重に持たない（ダウンロード済み巻の容量が倍にならない）
/// - LRU の枠をダウンロード済みのページで埋めない（未ダウンロードの巻の
///   キャッシュを追い出さない）
/// 方が得なので、素直に毎回 ZIP から読む。デコード済み画像は Flutter の
/// `ImageCache` に乗るので、同じページの連続表示ではここまで来ない。
///
/// ページ送りを UI isolate で止めないために（#25）:
/// - セントラルディレクトリとマニフェストの解析結果（[ZipPageIndex]）を
///   `(volumeId, filesVersion)` ごとに控え、ページごとに作り直さない。先読みと
///   合わせて 1 回のページ送りで 5 回解析し直していたのをやめる。
/// - ファイルの読み込みと展開（inflate）は [BackgroundRunner]（既定は
///   `Isolate.run`）の先で行う。台帳の検索（drift）は元から別 isolate で走る。
///
/// 控えは**ファイルハンドルを持たない**（オフセットと数値だけ）。削除・
/// ログアウトの全削除・取り直しの rename を妨げず、閉じ忘れも起きない。
/// 古い控えで読まないよう、毎回
/// - 台帳の世代（取り直しの確定 / 削除 / ログアウトで変わる・消える）と
/// - isolate 側で ZIP / マニフェストのサイズと更新時刻
/// を確かめ、食い違えば捨てて作り直す。
class ZipDownloadedPageSource implements DownloadedPageSource {
  ZipDownloadedPageSource(this._store, {BackgroundRunner? runner})
    : _run = runner ?? _runInIsolate;

  final DownloadStore _store;
  final BackgroundRunner _run;

  /// 控えておく巻の数。読書中の巻と、行き来する前後の巻が入れば足りる
  /// （1 巻あたりエントリ数ぶんの数値だけなので小さい）。
  static const maxCachedVolumes = 4;

  /// 巻 ID → 控え。挿入順を「最近使った順」として古いものから捨てる。
  final _indexes = <int, _CachedIndex>{};

  static Future<R> _runInIsolate<R>(FutureOr<R> Function() computation) =>
      Isolate.run(computation);

  @override
  Future<Uint8List?> readPage({
    required int volumeId,
    required int page,
    required int filesVersion,
  }) async {
    final download = await _store.find(volumeId);
    if (download == null) {
      // 削除 / ログアウトで台帳から消えた巻の控えは要らない。
      _indexes.remove(volumeId);
      return null;
    }
    // 取得済みの世代がサーバーと違う = 「更新あり」。古い絵を新しい URL の
    // 内容として見せない（消すのはユーザーの操作だけ）。
    if (download.filesVersion != filesVersion) return null;
    // status は見ない。「更新あり」の取り直し中・中断中も台帳は旧世代を指した
    // ままで、その ZIP は端末に残っていて読める（#11 のレビュー指摘）。実体が
    // あるかどうかは解析（isolate 側）が確かめる。初回の取得中は台帳の
    // `filesVersion` が 0 なので、上の比較で弾かれる。

    final archivePath = _store
        .archiveFile(volumeId: volumeId, filesVersion: filesVersion)
        .path;
    final manifestPath = _store
        .manifestFile(volumeId: volumeId, filesVersion: filesVersion)
        .path;

    // 1 回目が「控えが古い」なら作り直してもう 1 回だけ読む。それでも合わない
    // （読んでいる最中に差し替わり続けている）なら次の経路へ落とす。
    for (var attempt = 0; attempt < 2; attempt++) {
      final cached = _indexFor(
        volumeId: volumeId,
        filesVersion: filesVersion,
        archivePath: archivePath,
        manifestPath: manifestPath,
      );
      final ZipPageIndex? index;
      try {
        index = await cached.index;
      } on Object {
        _forget(volumeId, cached);
        return null;
      }
      if (index == null) {
        // ZIP が無い / 壊れている。失敗は控えない（次に読むときに確かめ直す）。
        _forget(volumeId, cached);
        return null;
      }

      // マニフェストがあるなら、ページ番号が画像エントリを指していることを
      // 確かめる。`/books/view/{volumeId}/{page}` の page は **ZIP のエントリ
      // 番号**なので、画像でないエントリ（テキスト等）を指す番号で呼ばれても
      // 返さないようにする。
      final knownPages = index.knownPages;
      if (knownPages != null && !knownPages.contains(page)) return null;
      if (page < 0 || page >= index.entries.length) return null;
      final entry = index.entries[page];
      if (entry == null) return null;

      final ZipPageRead read;
      try {
        read = await readZipEntryInBackground(
          _run,
          archivePath: archivePath,
          manifestPath: manifestPath,
          archiveStamp: index.archiveStamp,
          manifestStamp: index.manifestStamp,
          entry: entry,
        );
      } on Object {
        // isolate を起こせない等。読書を止めず次の経路へ落とす。
        return null;
      }
      switch (read) {
        case ZipPageBytes(:final bytes):
          return bytes;
        case ZipPageStale():
          _forget(volumeId, cached);
      }
    }
    return null;
  }

  /// 控えを返す（無ければ解析を始めて控える）。
  ///
  /// 先読みで同じ巻のページが同時に来ても、解析は 1 回にまとめる
  /// （控えるのは結果ではなく Future）。
  _CachedIndex _indexFor({
    required int volumeId,
    required int filesVersion,
    required String archivePath,
    required String manifestPath,
  }) {
    final existing = _indexes.remove(volumeId);
    if (existing != null && existing.filesVersion == filesVersion) {
      // 最近使った順の末尾へ入れ直す。
      _indexes[volumeId] = existing;
      return existing;
    }
    // 世代が変わった（取り直しの確定）控えは捨てて作り直す。
    final created = _CachedIndex(
      filesVersion: filesVersion,
      index: buildZipPageIndexInBackground(
        _run,
        archivePath: archivePath,
        manifestPath: manifestPath,
      ),
    );
    _indexes[volumeId] = created;
    while (_indexes.length > maxCachedVolumes) {
      _indexes.remove(_indexes.keys.first);
    }
    return created;
  }

  /// [cached] がまだ控えにあれば捨てる（同時に読んでいた側が作り直した
  /// 新しい控えは消さない）。
  void _forget(int volumeId, _CachedIndex cached) {
    if (identical(_indexes[volumeId], cached)) _indexes.remove(volumeId);
  }
}

class _CachedIndex {
  _CachedIndex({required this.filesVersion, required this.index});

  final int filesVersion;
  final Future<ZipPageIndex?> index;
}

@Riverpod(keepAlive: true)
Future<DownloadedPageSource> downloadedPageSource(Ref ref) async {
  return ZipDownloadedPageSource(await ref.watch(downloadStoreProvider.future));
}
