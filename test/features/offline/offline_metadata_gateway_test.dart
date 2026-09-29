import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/domain/models/read_volume.dart';
import 'package:comic_laz/features/downloads/data/download_store.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/offline/application/offline_metadata_gateway.dart';
import 'package:comic_laz/features/offline/data/offline_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/download_fakes.dart';
import '../../support/offline_fakes.dart';

const _volumeId = 340;
const _bookId = 12;
const _filesVersion = 111;

BookDetail _detail() => const BookDetail(
  id: _bookId,
  title: '進撃の巨人',
  volumes: [
    BookVolume(id: _volumeId, volume: 1, thumbnail: '/books/thumbnail/340?m=7'),
    BookVolume(id: 341, volume: 2, thumbnail: '/books/thumbnail/341?m=8'),
  ],
);

ReadVolume _volume() => const ReadVolume(
  id: _volumeId,
  volume: 1,
  files: [0, 1, 2],
  filesVersion: _filesVersion,
  nextVolumeId: 341,
  book: Book(id: _bookId),
);

({
  OfflineMetadataGateway gateway,
  OfflineCatalog catalog,
  DownloadStore downloads,
})
createGateway() {
  final offline = createOfflineCatalog();
  final store = DownloadStore(
    database: offline.cache.database,
    directories: offline.cache.directories,
    now: offline.cache.clock.now,
  );
  return (
    gateway: CatalogOfflineMetadataGateway(
      catalog: offline.catalog,
      downloads: () async => store,
    ),
    catalog: offline.catalog,
    downloads: store,
  );
}

/// ダウンロード済みの巻（台帳 + ZIP + マニフェスト）を作る。
Future<void> installVolume(
  DownloadStore store, {
  VolumeDownloadStatus status = VolumeDownloadStatus.completed,
}) async {
  final archive = zipWithPages(3);
  await store.ensureVolumeDirectory(_volumeId);
  store
      .archiveFile(volumeId: _volumeId, filesVersion: _filesVersion)
      .writeAsBytesSync(archive);
  await store.writeManifest(
    testManifest(
      id: _volumeId,
      bookId: _bookId,
      filesVersion: _filesVersion,
      archiveBytes: archive.length,
    ),
  );
  await store.save(
    VolumeDownload(
      volumeId: _volumeId,
      bookId: _bookId,
      filesVersion: _filesVersion,
      status: status,
      pageCount: 3,
    ),
  );
}

void main() {
  group('控える範囲', () {
    test('ダウンロード済みの巻を持たないタイトルの詳細は控えない（容量を食うだけ）', () async {
      final fixture = createGateway();

      await fixture.gateway.saveBookDetail(_detail());

      expect(await fixture.catalog.readBookDetail(_bookId), isNull);
    });

    test('ダウンロード済みなら詳細を控える', () async {
      final fixture = createGateway();
      await installVolume(fixture.downloads);

      await fixture.gateway.saveBookDetail(_detail());

      expect(await fixture.gateway.readBookDetail(_bookId), isNotNull);
    });

    test('ダウンロードしていない巻の巻情報は控えない', () async {
      final fixture = createGateway();

      await fixture.gateway.saveVolume(_volume());

      expect(await fixture.catalog.readVolume(_volumeId), isNull);
    });
  });

  group('圏外で巻を開く', () {
    test('ダウンロードしていない巻は開けない', () async {
      final fixture = createGateway();
      await fixture.catalog.writeVolume(_volume());

      expect(await fixture.gateway.readVolume(_volumeId), isNull);
    });

    test('開いたことがある巻は控えをそのまま使う', () async {
      final fixture = createGateway();
      await installVolume(fixture.downloads);
      await fixture.gateway.saveVolume(_volume());

      final volume = await fixture.gateway.readVolume(_volumeId);

      expect(volume?.files, [0, 1, 2]);
      expect(volume?.nextVolumeId, 341);
    });

    // ダウンロードしただけでビューアを開いていない巻（控えが無い）。
    test('開いたことが無くてもマニフェストと詳細から組み立てる', () async {
      final fixture = createGateway();
      await installVolume(fixture.downloads);
      await fixture.gateway.saveBookDetail(_detail());

      final volume = await fixture.gateway.readVolume(_volumeId);

      expect(volume?.files, [0, 1, 2]);
      expect(volume?.filesVersion, _filesVersion);
      expect(volume?.volume, 1);
      expect(volume?.nextVolumeId, 341, reason: '巻一覧の次の巻へ進める');
    });

    test('取得中の巻は開けない（途中のデータを読ませない）', () async {
      final fixture = createGateway();
      await installVolume(
        fixture.downloads,
        status: VolumeDownloadStatus.downloading,
      );
      await fixture.catalog.writeVolume(_volume());

      expect(await fixture.gateway.readVolume(_volumeId), isNull);
    });
  });

  group('掃除', () {
    test('ダウンロードを消したタイトル / 巻の控えを捨てる', () async {
      final fixture = createGateway();
      await installVolume(fixture.downloads);
      await fixture.gateway.saveBookDetail(_detail());
      await fixture.gateway.saveVolume(_volume());

      // ユーザーがダウンロードを削除した
      await fixture.downloads.deleteRow(_volumeId);
      await fixture.gateway.prune();

      expect(await fixture.catalog.readBookDetail(_bookId), isNull);
      expect(await fixture.catalog.readVolume(_volumeId), isNull);
    });

    test('残っているダウンロードの控えは消さない', () async {
      final fixture = createGateway();
      await installVolume(fixture.downloads);
      await fixture.gateway.saveBookDetail(_detail());
      await fixture.gateway.saveVolume(_volume());

      await fixture.gateway.prune();

      expect(await fixture.catalog.readBookDetail(_bookId), isNotNull);
      expect(await fixture.catalog.readVolume(_volumeId), isNotNull);
    });
  });
}
