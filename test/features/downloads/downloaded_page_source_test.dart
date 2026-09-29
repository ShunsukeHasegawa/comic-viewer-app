import 'dart:typed_data';

import 'package:comic_laz/domain/models/volume_manifest.dart';
import 'package:comic_laz/features/downloads/data/download_store.dart';
import 'package:comic_laz/features/downloads/data/downloaded_page_source.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/cache_fakes.dart';
import '../../support/download_fakes.dart';

const _volumeId = 340;
const _filesVersion = 111;

/// ダウンロード済みの巻（台帳 + ZIP + マニフェスト）を用意する。
Future<({DownloadStore store, Uint8List archive, VolumeManifest manifest})>
installVolume({
  int pages = 3,
  int filesVersion = _filesVersion,
  VolumeDownloadStatus status = VolumeDownloadStatus.completed,
  bool writeManifest = true,
}) async {
  final cache = CacheHarness.create();
  final store = DownloadStore(
    database: cache.database,
    directories: cache.directories,
    now: cache.clock.now,
  );
  final archive = zipWithPages(pages);
  final manifest = testManifest(
    id: _volumeId,
    filesVersion: filesVersion,
    archiveBytes: archive.length,
    pageCount: pages,
  );

  await store.ensureVolumeDirectory(_volumeId);
  store
      .archiveFile(volumeId: _volumeId, filesVersion: filesVersion)
      .writeAsBytesSync(archive);
  if (writeManifest) await store.writeManifest(manifest);
  await store.save(
    VolumeDownload(
      volumeId: _volumeId,
      bookId: 12,
      filesVersion: filesVersion,
      status: status,
      totalBytes: archive.length,
      pageCount: pages,
    ),
  );
  return (store: store, archive: archive, manifest: manifest);
}

void main() {
  test('ダウンロード済みの ZIP からページを取り出す', () async {
    final installed = await installVolume();
    final source = ZipDownloadedPageSource(installed.store);

    // `/books/view/{volumeId}/{page}` の page は ZIP のエントリ番号。
    final bytes = await source.readPage(
      volumeId: _volumeId,
      page: 1,
      filesVersion: _filesVersion,
    );

    // zipWithPages は n 枚目を 0x42 + n で埋める（2 枚目 = index 1）。
    expect(bytes, isNotNull);
    expect(bytes!.first, 0x43);
    expect(bytes.length, 64);
  });

  test('サーバーの files_version と食い違うローカルは使わない（更新あり）', () async {
    final installed = await installVolume();
    final source = ZipDownloadedPageSource(installed.store);

    final bytes = await source.readPage(
      volumeId: _volumeId,
      page: 0,
      // サーバー側で ZIP が差し替わった
      filesVersion: _filesVersion + 1,
    );

    expect(bytes, isNull, reason: '古い絵を新しい世代の内容として見せない');
    expect(
      installed.store
          .archiveFile(volumeId: _volumeId, filesVersion: _filesVersion)
          .existsSync(),
      isTrue,
      reason: '勝手に消さない（ユーザーが取り直すまでオフラインでは旧世代を読む）',
    );
  });

  test('完了していない巻は使わない（途中のデータを読ませない）', () async {
    final installed = await installVolume(status: VolumeDownloadStatus.paused);
    final source = ZipDownloadedPageSource(installed.store);

    expect(
      await source.readPage(
        volumeId: _volumeId,
        page: 0,
        filesVersion: _filesVersion,
      ),
      isNull,
    );
  });

  test('台帳に無い巻は null（未ダウンロード）', () async {
    final installed = await installVolume();
    final source = ZipDownloadedPageSource(installed.store);

    expect(
      await source.readPage(
        volumeId: 999,
        page: 0,
        filesVersion: _filesVersion,
      ),
      isNull,
    );
  });

  test('マニフェストに無いページ番号は返さない（画像以外のエントリを指す番号）', () async {
    final installed = await installVolume(pages: 2);
    final source = ZipDownloadedPageSource(installed.store);

    expect(
      await source.readPage(
        volumeId: _volumeId,
        page: 5,
        filesVersion: _filesVersion,
      ),
      isNull,
    );
  });

  test('マニフェストが無くても ZIP の範囲内なら読める（取得後に消えた場合）', () async {
    final installed = await installVolume(writeManifest: false);
    final source = ZipDownloadedPageSource(installed.store);

    expect(
      await source.readPage(
        volumeId: _volumeId,
        page: 0,
        filesVersion: _filesVersion,
      ),
      isNotNull,
    );
    expect(
      await source.readPage(
        volumeId: _volumeId,
        page: 99,
        filesVersion: _filesVersion,
      ),
      isNull,
    );
  });

  test('壊れた ZIP は null（読書を止めず、次の経路へ落とす）', () async {
    final installed = await installVolume();
    installed.store
        .archiveFile(volumeId: _volumeId, filesVersion: _filesVersion)
        .writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
    final source = ZipDownloadedPageSource(installed.store);

    expect(
      await source.readPage(
        volumeId: _volumeId,
        page: 0,
        filesVersion: _filesVersion,
      ),
      isNull,
    );
  });
}
