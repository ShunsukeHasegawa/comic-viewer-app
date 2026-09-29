import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/domain/models/read_volume.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/offline/domain/offline_read_volume.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/download_fakes.dart';

VolumeDownload _download({
  int filesVersion = 111,
  int pageCount = 3,
  VolumeDownloadStatus status = VolumeDownloadStatus.completed,
}) => VolumeDownload(
  volumeId: 340,
  bookId: 12,
  filesVersion: filesVersion,
  status: status,
  pageCount: pageCount,
);

BookDetail _detail() => const BookDetail(
  id: 12,
  title: '進撃の巨人',
  isComplete: true,
  volumes: [
    BookVolume(
      id: 340,
      volume: 1,
      userStatus: VolumeUserStatus(currentPage: 2, maxPage: 3),
    ),
    BookVolume(id: 341, volume: 2, thumbnail: '/books/thumbnail/341?m=9'),
  ],
);

void main() {
  test('実体を指していない台帳の巻は開けない', () {
    expect(
      buildOfflineReadVolume(
        volumeId: 340,
        // 初回の取得中 / 中断中。完了するまで世代は書かれないので 0 のまま。
        download: _download(
          filesVersion: 0,
          pageCount: 0,
          status: VolumeDownloadStatus.paused,
        ),
        manifest: testManifest(archiveBytes: 100),
      ),
      isNull,
    );
    expect(
      buildOfflineReadVolume(volumeId: 340, download: null),
      isNull,
      reason: '台帳に無い巻（未ダウンロード）',
    );
  });

  // 「更新あり」の取り直し中・中断中は、台帳が旧世代を指したままで ZIP も残って
  // いる（世代にかかわる項目は検証が通ってからしか書かれない）。status で弾くと
  // 手元に完全な ZIP があるのに開けなくなる（#11 のレビュー指摘）。
  test('取り直し中の巻は、台帳が指す旧世代で開ける', () {
    final volume = buildOfflineReadVolume(
      volumeId: 340,
      download: _download(status: VolumeDownloadStatus.downloading),
      detail: _detail(),
      manifest: testManifest(archiveBytes: 100),
    );

    expect(volume?.files, [0, 1, 2]);
    expect(volume?.filesVersion, 111);
  });

  test('保存済みの巻情報が同じ世代ならそれを使う（next_volume_id を持っている）', () {
    final stored = ReadVolume(
      id: 340,
      volume: 1,
      files: const [0, 1, 2],
      filesVersion: 111,
      nextVolumeId: 341,
      book: const Book(id: 12),
    );

    final built = buildOfflineReadVolume(
      volumeId: 340,
      download: _download(),
      stored: stored,
      manifest: testManifest(archiveBytes: 100),
    );

    expect(built, same(stored));
  });

  test('世代が違う保存済みは使わず、手元の ZIP のマニフェストから組み直す', () {
    final stored = ReadVolume(
      id: 340,
      volume: 1,
      // 旧世代のページ構成
      files: const [0, 1],
      filesVersion: 99,
      book: const Book(id: 12),
    );

    final built = buildOfflineReadVolume(
      volumeId: 340,
      download: _download(),
      stored: stored,
      detail: _detail(),
      manifest: testManifest(archiveBytes: 100),
    );

    expect(built?.files, [0, 1, 2]);
    expect(built?.filesVersion, 111);
  });

  test('開いたことのない巻はマニフェストと詳細から組み立てる', () {
    final built = buildOfflineReadVolume(
      volumeId: 340,
      download: _download(),
      detail: _detail(),
      manifest: testManifest(archiveBytes: 100),
    );

    expect(built?.files, [0, 1, 2], reason: 'ページ番号は ZIP のエントリ番号');
    expect(built?.volume, 1);
    expect(built?.currentPage, 2, reason: '詳細に含まれる進捗から続きを開く');
    expect(built?.nextVolumeId, 341, reason: '巻一覧の次の巻が次巻');
    expect(built?.nextVolumeThumbnail, '/books/thumbnail/341?m=9');
    expect(built?.book.title, '進撃の巨人');
  });

  test('マニフェストが無ければ組み立てない（ページ番号が分からない）', () {
    expect(
      buildOfflineReadVolume(
        volumeId: 340,
        download: _download(),
        detail: _detail(),
      ),
      isNull,
    );
  });

  test('詳細が無くても読める形にはする（巻数や次巻は分からない）', () {
    final built = buildOfflineReadVolume(
      volumeId: 340,
      download: _download(),
      manifest: testManifest(archiveBytes: 100),
    );

    expect(built?.files, [0, 1, 2]);
    expect(built?.nextVolumeId, isNull);
    expect(built?.book.id, 12, reason: '台帳の book_id は分かる');
  });
}
