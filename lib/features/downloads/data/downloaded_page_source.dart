import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/models/volume_manifest.dart';
import 'download_store.dart';

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
/// **読んだページを一時キャッシュへ写さない**。計測すると、1 巻 200 ページ・
/// 約 100MB の ZIP から 1 ページ取り出すのに数ミリ秒しかかからない
/// （`ZipDecoder.decodeStream` はセントラルディレクトリだけを読み、
/// 対象エントリだけを展開する。全ページの展開はしない）。それなら
/// - 同じ画像をディスクに二重に持たない（ダウンロード済み巻の容量が倍にならない）
/// - LRU の枠をダウンロード済みのページで埋めない（未ダウンロードの巻の
///   キャッシュを追い出さない）
/// 方が得なので、素直に毎回 ZIP から読む。デコード済み画像は Flutter の
/// `ImageCache` に乗るので、同じページの連続表示ではここまで来ない。
class ZipDownloadedPageSource implements DownloadedPageSource {
  const ZipDownloadedPageSource(this._store);

  final DownloadStore _store;

  @override
  Future<Uint8List?> readPage({
    required int volumeId,
    required int page,
    required int filesVersion,
  }) async {
    final download = await _store.find(volumeId);
    if (download == null || !download.isCompleted) return null;
    // 取得済みの世代がサーバーと違う = 「更新あり」。古い絵を新しい URL の
    // 内容として見せない（消すのはユーザーの操作だけ）。
    if (download.filesVersion != filesVersion) return null;

    final archive = _store.archiveFile(
      volumeId: volumeId,
      filesVersion: filesVersion,
    );
    if (!archive.existsSync()) return null;

    final manifest = await _store.readManifest(
      volumeId: volumeId,
      filesVersion: filesVersion,
    );
    // マニフェストがあるなら、ページ番号が画像エントリを指していることを確かめる。
    // `/books/view/{volumeId}/{page}` の page は **ZIP のエントリ番号**なので、
    // 画像でないエントリ（テキスト等）を指す番号で呼ばれても返さないようにする。
    if (manifest != null && !_isKnownPage(manifest, page)) return null;

    return _readEntry(archive, page);
  }

  static bool _isKnownPage(VolumeManifest manifest, int page) {
    if (manifest.pages.isEmpty) return true;
    for (final entry in manifest.pages) {
      if (entry.index == page) return true;
    }
    return false;
  }

  /// ZIP の [index] 番目のエントリを読む。
  ///
  /// サーバー（`VolumeService::readPageFromZip`）が `getFromIndex()` で返すのと
  /// 同じ「セントラルディレクトリの並び順」で数える。`ZipDecoder` もこの順で
  /// エントリを作るので、番号はそのまま使える。
  Future<Uint8List?> _readEntry(File archive, int index) async {
    final input = InputFileStream(archive.path);
    try {
      final decoded = ZipDecoder().decodeStream(input);
      if (index < 0 || index >= decoded.files.length) return null;
      final entry = decoded.files[index];
      if (!entry.isFile) return null;
      final bytes = entry.readBytes();
      return bytes == null || bytes.isEmpty ? null : bytes;
    } on Object {
      // 壊れた ZIP でも読書を止めない（キャッシュ / ネットワークへ落ちる）。
      // 台帳と実体はここでは消さない（削除はユーザーの操作だけ）。
      return null;
    } finally {
      await input.close();
    }
  }
}

@Riverpod(keepAlive: true)
Future<DownloadedPageSource> downloadedPageSource(Ref ref) async {
  return ZipDownloadedPageSource(await ref.watch(downloadStoreProvider.future));
}
