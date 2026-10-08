import 'dart:io';

import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/core/storage/app_directories.dart';
import 'package:comic_laz/features/downloads/data/download_store.dart';
import 'package:comic_laz/features/downloads/domain/archive_task_id.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/cache_fakes.dart';

void main() {
  late CacheHarness cache;
  late DownloadStore store;

  setUp(() {
    cache = CacheHarness.create();
    store = DownloadStore(
      database: cache.database,
      directories: cache.directories,
      now: cache.clock.now,
    );
  });

  File touch(File file) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('x');
    return file;
  }

  File fileIn(int volumeId, String name) =>
      File(p.join(store.volumeDirectory(volumeId).path, name));

  VolumeDownload completed(int volumeId, int filesVersion) => VolumeDownload(
    volumeId: volumeId,
    bookId: 1,
    filesVersion: filesVersion,
    status: VolumeDownloadStatus.completed,
    pageCount: 10,
  );

  group('ステージングファイルの置き場', () {
    test('OS の転送に渡す相対パスが、アプリが見る絶対パスと同じ場所を指す', () {
      // 転送は application support からの相対パスで保存先を解決するので、
      // ここがずれると完了したファイルをアプリが見つけられない。
      final relative = store.stagingDirectoryRelative(340);
      final resolved = p.join(
        cache.directories.support.path,
        p.joinAll(relative.split('/')),
        DownloadStore.stagingFilename(7),
      );

      expect(relative, 'downloads/340');
      expect(
        p.equals(
          resolved,
          store.stagingFile(volumeId: 340, filesVersion: 7).path,
        ),
        isTrue,
      );
      expect(
        p.basename(store.stagingFile(volumeId: 340, filesVersion: 7).path),
        '7.zip.download',
      );
    });
  });

  group('セッションタグ', () {
    test('一度作ったタグは再起動（別インスタンス）でも変わらない', () async {
      // 再起動のたびに変わると、アプリが死んでいる間に終わった転送を
      // 「別セッションのもの」と見なして捨ててしまう。
      final first = await store.readSessionTag();
      final reopened = DownloadStore(
        database: cache.database,
        directories: cache.directories,
      );

      expect(first, matches(RegExp(r'^[A-Za-z0-9]{12}$')));
      expect(await store.readSessionTag(), first);
      expect(await reopened.readSessionTag(), first);
    });

    test('タスク ID に埋め込んで parse できる形になっている', () async {
      // parse できないタグだと、自分の転送を見分けられなくなる。
      final tag = await store.readSessionTag();
      final id = ArchiveTaskId(
        volumeId: 1,
        filesVersion: 2,
        sessionTag: tag,
        nonce: ArchiveTaskId.newNonce(),
      );

      expect(ArchiveTaskId.tryParse(id.toString()), id);
    });

    test('作り直すと別のタグになり、以後はそれが読まれる', () async {
      // ログアウト後に前のユーザーの転送の完了が届いても取り込まないため。
      final before = await store.readSessionTag();
      final rotated = await store.rotateSessionTag();

      expect(rotated, isNot(before));
      expect(rotated, matches(RegExp(r'^[A-Za-z0-9]{12}$')));
      expect(await store.readSessionTag(), rotated);
    });

    test('同時に読まれても 1 つのタグに揃う', () async {
      // 起動直後に複数の経路から読まれても、別々のタグで転送を投入しない。
      final tags = await Future.wait([
        store.readSessionTag(),
        store.readSessionTag(),
        store.readSessionTag(),
      ]);

      expect(tags.toSet(), hasLength(1));
    });

    test('壊れた値が保存されていたら作り直す', () async {
      // タスク ID に使えない文字が入っていると parse できず、自分の転送を
      // 永遠に見分けられなくなる。
      await cache.database
          .into(cache.database.settings)
          .insertOnConflictUpdate(
            const SettingRow(key: DownloadStore.sessionTagKey, value: 'a.b'),
          );

      expect(
        await store.readSessionTag(),
        matches(RegExp(r'^[A-Za-z0-9]{12}$')),
      );
    });
  });

  group('sweep', () {
    test('孤児と旧形式を消し、読める実体と生きている転送は残す', () async {
      // 巻 1: 台帳あり（世代 5）。更新の取り直しが世代 6 で転送中。
      final installedZip = touch(fileIn(1, '5.zip'));
      final installedJson = touch(fileIn(1, '5.json'));
      final liveStaging = touch(
        store.stagingFile(volumeId: 1, filesVersion: 6),
      );
      final liveJson = touch(fileIn(1, '6.json'));
      final staleJson = touch(fileIn(1, '4.json'));
      final orphanStaging = touch(
        store.stagingFile(volumeId: 1, filesVersion: 3),
      );
      final legacyPart = touch(fileIn(1, '5.zip.part'));
      // 巻 2: 台帳に無い（削除の途中で落ちた残り）。
      final orphanDirectory = store.volumeDirectory(2);
      touch(fileIn(2, '9.zip'));
      // 数字でないディレクトリは巻ではないので触らない。
      final foreign = Directory(
        p.join(cache.directories.downloads.path, 'other'),
      )..createSync(recursive: true);

      await store.sweep(
        ledger: {1: completed(1, 5)},
        liveStagingPaths: {liveStaging.path},
      );

      expect(installedZip.existsSync(), isTrue);
      expect(installedJson.existsSync(), isTrue);
      expect(liveStaging.existsSync(), isTrue);
      expect(liveJson.existsSync(), isTrue);
      expect(staleJson.existsSync(), isFalse);
      expect(orphanStaging.existsSync(), isFalse);
      expect(legacyPart.existsSync(), isFalse);
      expect(orphanDirectory.existsSync(), isFalse);
      expect(foreign.existsSync(), isTrue);
    });

    test('台帳に無くても生きている転送の書き込み先は消さない', () async {
      // 突き合わせで取り消し損ねた転送の書き込み先を消すと、OS 側の転送が
      // 失敗して通知だけが残る。消すのは転送を取り消してからにする。
      final liveStaging = touch(
        store.stagingFile(volumeId: 3, filesVersion: 1),
      );

      await store.sweep(ledger: const {}, liveStagingPaths: {liveStaging.path});

      expect(liveStaging.existsSync(), isTrue);
    });

    test('ダウンロード領域が無くても例外を投げない', () async {
      // 起動時の復元の最後に呼ぶので、ここで落ちると復元が止まる。
      final missing = DownloadStore(
        database: cache.database,
        directories: AppDirectories(
          support: Directory(p.join(cache.directories.support.path, 'nope')),
          cache: cache.directories.cache,
        ),
      );

      await expectLater(
        missing.sweep(ledger: const {}, liveStagingPaths: const {}),
        completes,
      );
    });
  });

  group('削除', () {
    test('巻の削除とログアウト時の全削除はステージングファイルも消す', () async {
      // 前のユーザーの部分データを端末に残さない（#15）。
      final first = touch(store.stagingFile(volumeId: 1, filesVersion: 1));
      final second = touch(store.stagingFile(volumeId: 2, filesVersion: 1));

      await store.deleteFiles(1);
      expect(first.existsSync(), isFalse);
      expect(second.existsSync(), isTrue);

      await store.deleteAllFiles();
      expect(second.existsSync(), isFalse);
    });

    DownloadStore storeWithoutDownloads() => DownloadStore(
      database: cache.database,
      directories: AppDirectories(
        support: Directory(p.join(cache.directories.support.path, 'nope')),
        cache: cache.directories.cache,
      ),
    );

    test('ダウンロード領域がまだ無ければ、全削除・別世代の掃除・巻の削除は何もせず終わる', () async {
      // 一度もダウンロードしていない端末でもログアウトの破棄は走る。「無い」を
      // 失敗にすると破棄の印が残り、起動のたびにやり直しになる（#15）。
      final missing = storeWithoutDownloads();

      await expectLater(missing.deleteAllFiles(), completes);
      await expectLater(
        missing.deleteOtherVersions(volumeId: 1, keepFilesVersion: 1),
        completes,
      );
      await expectLater(missing.deleteFiles(1), completes);
      expect(await missing.readManifest(volumeId: 1, filesVersion: 1), isNull);
    });

    test('ダウンロード領域が一覧できないときの全削除は投げる（黙って成功にしない）', () async {
      // 一覧を非同期にしても、「無い」以外の失敗を握ると破棄の印が消え、
      // 前のユーザーの ZIP が端末に残り続ける（#15）。ディレクトリの代わりに
      // ファイルを置いて、一覧そのものを失敗させる。
      final broken = storeWithoutDownloads();
      final support = broken.directories.support..createSync(recursive: true);
      File(p.join(support.path, 'downloads')).writeAsStringSync('x');

      await expectLater(
        broken.deleteAllFiles(),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('ディレクトリが無くても巻の保存先を作れる（同じ巻をもう一度作っても失敗しない）', () async {
      await store.ensureVolumeDirectory(4);
      await store.ensureVolumeDirectory(4);

      expect(store.volumeDirectory(4).existsSync(), isTrue);
    });

    test('取り直しの後は残す世代のファイルだけ残し、他の巻には触らない', () async {
      // 更新を落とし直したあとの掃除。残す世代の ZIP / 書きかけ / マニフェストを
      // 消すとオフラインで読めなくなる（判断は一覧を非同期にしても変えない）。
      final keepZip = touch(store.archiveFile(volumeId: 1, filesVersion: 7));
      final keepStaging = touch(
        store.stagingFile(volumeId: 1, filesVersion: 7),
      );
      final keepJson = touch(fileIn(1, '7.json'));
      final oldZip = touch(store.archiveFile(volumeId: 1, filesVersion: 6));
      final oldJson = touch(fileIn(1, '6.json'));
      final otherVolume = touch(
        store.archiveFile(volumeId: 2, filesVersion: 6),
      );

      await store.deleteOtherVersions(volumeId: 1, keepFilesVersion: 7);

      expect(keepZip.existsSync(), isTrue);
      expect(keepStaging.existsSync(), isTrue);
      expect(keepJson.existsSync(), isTrue);
      expect(oldZip.existsSync(), isFalse);
      expect(oldJson.existsSync(), isFalse);
      expect(otherVolume.existsSync(), isTrue);
    });
  });

  test('確定時刻は書き直しても進めない（自動削除の時計が完了行の保存のたびに振り出しへ戻らない）', () async {
    final installedAt = cache.clock.now();
    await store.save(completed(1, 3).copyWith(completedAt: installedAt));
    cache.clock.advance(const Duration(days: 10));

    // 取り直しの失敗で旧世代へ戻すなど、同じ完了行をもう一度書く。
    final loaded = (await store.loadAll())[1]!;
    await store.save(loaded.copyWith(failureReason: '更新の取得に失敗'));

    expect((await store.loadAll())[1]!.completedAt?.toUtc(), installedAt);
  });

  test('完了していない行には確定時刻を残さない（待機中の行の時刻で消さない）', () async {
    await store.save(
      completed(1, 3).copyWith(
        status: VolumeDownloadStatus.queued,
        completedAt: cache.clock.now(),
      ),
    );

    expect((await store.loadAll())[1]!.completedAt, isNull);
  });
}
