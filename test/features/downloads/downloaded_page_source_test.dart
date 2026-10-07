import 'dart:async';
import 'dart:isolate';
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

  // 「更新あり」の取り直しを始めて（中断して）から圏外に出ても、旧世代の ZIP は
  // 端末に残っている。status で弾くと手元に完全な ZIP があるのに読めなくなる（#11）。
  test('取り直しを中断した巻でも、台帳が指す世代の ZIP があれば読める', () async {
    final installed = await installVolume(
      status: VolumeDownloadStatus.downloading,
    );
    final source = ZipDownloadedPageSource(installed.store);

    final bytes = await source.readPage(
      volumeId: _volumeId,
      page: 1,
      filesVersion: _filesVersion,
    );

    expect(bytes, isNotNull);
    expect(bytes!.first, 0x43);
  });

  test('初回の取得中は読めない（台帳がまだ実体を指していない）', () async {
    final cache = CacheHarness.create();
    final store = DownloadStore(
      database: cache.database,
      directories: cache.directories,
      now: cache.clock.now,
    );
    // 完了するまで世代は書かれないので、台帳の filesVersion は 0 のまま。
    await store.save(
      const VolumeDownload(
        volumeId: _volumeId,
        bookId: 12,
        filesVersion: 0,
        status: VolumeDownloadStatus.downloading,
      ),
    );
    final source = ZipDownloadedPageSource(store);

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

  // #25: ページ送りのたびに UI isolate で ZIP を解析し直すとカクつく。
  group('解析の控えと isolate への切り出し（#25）', () {
    test('先読みで同じ巻を同時に読んでも、解析は 1 回にまとめ、以降は読むだけ', () async {
      final installed = await installVolume(pages: 5);
      final runner = _CountingRunner();
      final source = ZipDownloadedPageSource(
        installed.store,
        runner: runner.call,
      );

      // 表示中のページ + 先読み 4 ページが同時に来る。
      final pages = await Future.wait([
        for (var page = 0; page < 5; page++)
          source.readPage(
            volumeId: _volumeId,
            page: page,
            filesVersion: _filesVersion,
          ),
      ]);
      expect(
        [for (final bytes in pages) bytes!.first],
        [for (var i = 0; i < 5; i++) 0x42 + i],
      );
      // 解析 1 回 + 読み出し 5 回。すべて runner（= 別 isolate）の先で走る。
      expect(runner.calls, 6);

      await source.readPage(
        volumeId: _volumeId,
        page: 2,
        filesVersion: _filesVersion,
      );
      expect(runner.calls, 7, reason: '次のページ送りでは解析し直さない');
    });

    // Windows では開いたままのファイルを消せない。控えがハンドルを握って
    // いると、削除 / ログアウトの全削除が黙って失敗し ZIP が残る。
    test('読んだ後でも巻の実体を消せ、消した後は古い控えで読まない', () async {
      final installed = await installVolume();
      final source = ZipDownloadedPageSource(installed.store);
      expect(
        await source.readPage(
          volumeId: _volumeId,
          page: 0,
          filesVersion: _filesVersion,
        ),
        isNotNull,
      );

      await installed.store.deleteFiles(_volumeId);
      expect(installed.store.volumeDirectory(_volumeId).existsSync(), isFalse);

      // 台帳が残ったまま実体だけ消えても（削除の途中など）次の経路へ落とす。
      expect(
        await source.readPage(
          volumeId: _volumeId,
          page: 0,
          filesVersion: _filesVersion,
        ),
        isNull,
      );
    });

    test('ログアウトの全削除の後は読まない（台帳も実体も無い）', () async {
      final installed = await installVolume();
      final source = ZipDownloadedPageSource(installed.store);
      await source.readPage(
        volumeId: _volumeId,
        page: 0,
        filesVersion: _filesVersion,
      );

      await installed.store.deleteAllRows();
      await installed.store.deleteAllFiles();

      expect(
        await source.readPage(
          volumeId: _volumeId,
          page: 0,
          filesVersion: _filesVersion,
        ),
        isNull,
      );
    });

    // 同じ世代のまま取り直す経路（既存の ZIP を消して rename）がある。古い
    // オフセットのまま新しいファイルを読むと、壊れた画像や別のページが出る。
    test('同じ世代のまま差し替わった ZIP は解析し直して読む', () async {
      final installed = await installVolume();
      final source = ZipDownloadedPageSource(installed.store);
      final before = await source.readPage(
        volumeId: _volumeId,
        page: 1,
        filesVersion: _filesVersion,
      );
      expect(before!.length, 64);

      installed.store
          .archiveFile(volumeId: _volumeId, filesVersion: _filesVersion)
          .writeAsBytesSync(zipWithPages(3, bytesPerPage: 300));

      final after = await source.readPage(
        volumeId: _volumeId,
        page: 1,
        filesVersion: _filesVersion,
      );
      expect(after, isNotNull);
      expect(after!.length, 300);
      expect(after.first, 0x43);
    });

    test('取り直しで台帳の世代が進んだら、新しい世代の ZIP を読む', () async {
      final installed = await installVolume();
      final source = ZipDownloadedPageSource(installed.store);
      await source.readPage(
        volumeId: _volumeId,
        page: 0,
        filesVersion: _filesVersion,
      );

      const next = _filesVersion + 1;
      final archive = zipWithPages(3, bytesPerPage: 200);
      installed.store
          .archiveFile(volumeId: _volumeId, filesVersion: next)
          .writeAsBytesSync(archive);
      await installed.store.writeManifest(
        testManifest(
          id: _volumeId,
          filesVersion: next,
          archiveBytes: archive.length,
        ),
      );
      await installed.store.save(
        VolumeDownload(
          volumeId: _volumeId,
          bookId: 12,
          filesVersion: next,
          status: VolumeDownloadStatus.completed,
          totalBytes: archive.length,
          pageCount: 3,
        ),
      );

      final bytes = await source.readPage(
        volumeId: _volumeId,
        page: 0,
        filesVersion: next,
      );
      expect(bytes!.length, 200);
      expect(
        await source.readPage(
          volumeId: _volumeId,
          page: 0,
          filesVersion: _filesVersion,
        ),
        isNull,
        reason: '台帳が新しい世代を指したら、古い世代の URL には答えない',
      );
    });

    // 確定の途中で落ちた巻はマニフェストが後から書かれる。無かったときの
    // 「絞り込まない」を控えたまま使い続けない。
    test('後から書かれたマニフェストのページ一覧を反映する', () async {
      final installed = await installVolume(writeManifest: false);
      final source = ZipDownloadedPageSource(installed.store);
      expect(
        await source.readPage(
          volumeId: _volumeId,
          page: 2,
          filesVersion: _filesVersion,
        ),
        isNotNull,
      );

      await installed.store.writeManifest(
        installed.manifest.copyWith(
          pages: [
            for (final page in installed.manifest.pages)
              if (page.index != 2) page,
          ],
        ),
      );

      // 1 回目は控えの食い違いに気づいて作り直し、新しい一覧で弾く。
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
          page: 2,
          filesVersion: _filesVersion,
        ),
        isNull,
      );
    });

    test('別 isolate を起こせなくても例外を出さず次の経路へ落とす', () async {
      final installed = await installVolume();
      final source = ZipDownloadedPageSource(
        installed.store,
        runner: <R>(computation) => Future<R>.error(StateError('no isolate')),
      );

      expect(
        await source.readPage(
          volumeId: _volumeId,
          page: 0,
          filesVersion: _filesVersion,
        ),
        isNull,
      );
    });
  });
}

/// 本物の `Isolate.run` に渡しつつ、外へ出した回数を数える。
class _CountingRunner {
  var calls = 0;

  Future<R> call<R>(FutureOr<R> Function() computation) {
    calls++;
    return Isolate.run(computation);
  }
}
