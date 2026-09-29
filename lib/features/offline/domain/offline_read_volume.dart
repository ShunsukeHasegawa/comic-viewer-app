import '../../../domain/models/book.dart';
import '../../../domain/models/book_detail.dart';
import '../../../domain/models/read_volume.dart';
import '../../../domain/models/volume_manifest.dart';
import '../../downloads/domain/volume_download.dart';

/// 端末にある情報だけで [ReadVolume] を組み立てる（#11）。
///
/// 圏外では `GET /api/books/read/volume/{id}` が使えないので、
/// - ビューアで一度開いた巻は保存済みの [stored] をそのまま使う
/// - ダウンロードしただけで開いていない巻は、**マニフェスト**（ZIP のページ
///   エントリ番号）と**タイトル詳細**（巻数 / 次巻 / 表紙）から組み立てる
///
/// 「実体が無い巻は開けない」ことをここで担保する（[download] が端末の ZIP を
/// 指していなければ必ず `null`）。ページ画像は ZIP からしか出せないため、実体の
/// 無い巻を開かせても真っ黒な画面になるだけ。判定に status を使わないのは、
/// 「更新あり」の取り直し中も旧世代の ZIP は読めるため（#11 のレビュー指摘）。
ReadVolume? buildOfflineReadVolume({
  required int volumeId,
  required VolumeDownload? download,
  ReadVolume? stored,
  BookDetail? detail,
  VolumeManifest? manifest,
}) {
  if (download == null || !download.hasInstalledArchive) return null;

  // 保存済みの巻情報が手元の ZIP と同じ世代なら、それが一番情報量が多い
  // （サーバーが返した next_volume_id / 次巻サムネイルを含む）。
  if (stored != null &&
      stored.files.isNotEmpty &&
      stored.filesVersion == download.filesVersion) {
    return stored;
  }

  final pages = manifest?.pages ?? const <VolumeManifestPage>[];
  final files = [for (final page in pages) page.index];
  if (files.isEmpty) return null;

  final volumes = detail?.volumes ?? const <BookVolume>[];
  final index = volumes.indexWhere((volume) => volume.id == volumeId);
  final self = index < 0 ? null : volumes[index];
  final next = index < 0 || index + 1 >= volumes.length
      ? null
      : volumes[index + 1];

  return ReadVolume(
    id: volumeId,
    volume: self?.volume ?? 0,
    // サーバーの進捗は分からないので 1 ページ目から。未送信のローカル進捗
    // （#12）があればビューア側がそちらを優先する。
    currentPage: self?.userStatus?.currentPage ?? 1,
    nextVolumeId: next?.id,
    nextVolumeThumbnail: next?.thumbnail,
    files: files,
    filesVersion: download.filesVersion,
    book: Book(
      id: detail?.id ?? download.bookId,
      title: detail?.title ?? '',
      isComplete: detail?.isComplete ?? false,
    ),
  );
}
