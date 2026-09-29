import 'dart:io';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/features/downloads/application/download_queue.dart';
import 'package:comic_laz/features/downloads/data/archive_transport.dart';
import 'package:comic_laz/features/downloads/domain/archive_task_id.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/download_fakes.dart';

/// 起動時の照合（アプリが死んでいる間に OS 側で進んだ転送と台帳の突き合わせ）。
///
/// 台帳と OS 側の状態を先に用意してからキューを作る（キューの build が照合する）。
const volumeId = 340;
const bookId = 12;

void main() {
  late DownloadHarness harness;
  late String tag;
  ProviderContainer? container;

  setUp(() async {
    final bytes = zipWithPages(3);
    harness = DownloadHarness.create(
      manifest: testManifest(
        id: volumeId,
        bookId: bookId,
        archiveBytes: bytes.length,
      ),
      archiveBytes: bytes,
    );
    // キューと同じ永続化されたタグ（再起動を跨いで同じものが読まれる）。
    tag = await harness.store.readSessionTag();
  });

  String taskIdOf(int id, {int filesVersion = 111, String? sessionTag}) =>
      ArchiveTaskId(
        volumeId: id,
        filesVersion: filesVersion,
        sessionTag: sessionTag ?? tag,
      ).toString();

  Future<void> saveRow(
    VolumeDownloadStatus status, {
    int id = volumeId,
    int filesVersion = 0,
    int pageCount = 0,
  }) => harness.store.save(
    VolumeDownload(
      volumeId: id,
      bookId: bookId,
      filesVersion: filesVersion,
      status: status,
      pageCount: pageCount,
      totalBytes: harness.api.archiveBytes.length,
    ),
  );

  /// 投入前に書くマニフェスト（前回の起動で書かれていたもの）。
  Future<void> writeManifest() async {
    await harness.store.ensureVolumeDirectory(volumeId);
    await harness.store.writeManifest(harness.api.manifest);
  }

  File stagingOf(int id, {int filesVersion = 111}) =>
      harness.store.stagingFile(volumeId: id, filesVersion: filesVersion);

  void snapshots(Map<String, TransferState> states) {
    harness.transport.snapshotResult = [
      for (final MapEntry(key: taskId, value: state) in states.entries)
        TransferSnapshot(taskId: taskId, state: state),
    ];
  }

  Future<ProviderContainer> start() async {
    final created = ProviderContainer(overrides: harness.overrides());
    addTearDown(created.dispose);
    created.listen(downloadQueueProvider, (_, _) {});
    container = created;
    await settleDownloads(created);
    return created;
  }

  Future<void> settle() => settleDownloads(container!);

  VolumeDownload? downloadOf(
    ProviderContainer container, [
    int id = volumeId,
  ]) => container.read(downloadQueueProvider).value?[id];

  group('台帳が待機中 / 取得中', () {
    test('走行中の転送はそのまま見守り、二重に積まない', () async {
      await saveRow(VolumeDownloadStatus.downloading);
      await writeManifest();
      snapshots({taskIdOf(volumeId): TransferState.running});

      final container = await start();

      expect(harness.transport.enqueued, isEmpty);
      expect(harness.transport.canceled, isEmpty);
      expect(downloadOf(container)!.status, VolumeDownloadStatus.downloading);

      harness.transport.completeTask(
        taskIdOf(volumeId),
        harness.api.archiveBytes,
      );
      await settle();
      expect(downloadOf(container)!.status, VolumeDownloadStatus.completed);
    });

    test('アプリが死んでいる間に完了した巻は、起動時にネットワーク無しで確定する', () async {
      await saveRow(VolumeDownloadStatus.downloading);
      await writeManifest();
      stagingOf(volumeId).writeAsBytesSync(harness.api.archiveBytes);
      snapshots({taskIdOf(volumeId): TransferState.completed});
      // 圏外で起動した。
      harness.api.manifestError = const NetworkException();

      final container = await start();

      final download = downloadOf(container)!;
      expect(download.status, VolumeDownloadStatus.completed);
      expect(download.filesVersion, 111);
      expect(harness.api.manifestCalls, 0, reason: '投入前に書いたマニフェストで検証できる');
      expect(harness.archiveFile().existsSync(), isTrue);
      expect(harness.transport.forgotten, contains(taskIdOf(volumeId)));
    });

    test('rename の後に落ちて完了が再送されても壊れない', () async {
      // 書きかけは既に {v}.zip に rename 済みで、台帳の確定と forget の前に落ちた。
      await saveRow(VolumeDownloadStatus.downloading);
      await writeManifest();
      harness.archiveFile().writeAsBytesSync(harness.api.archiveBytes);
      snapshots({taskIdOf(volumeId): TransferState.completed});

      final container = await start();

      final download = downloadOf(container)!;
      expect(download.status, VolumeDownloadStatus.completed);
      expect(download.failureReason, isNull);
      expect(harness.archiveFile().existsSync(), isTrue);
      expect(harness.transport.enqueued, isEmpty, reason: '落とし直さない');
    });

    test('一時停止のまま残った転送は再開する', () async {
      await saveRow(VolumeDownloadStatus.queued);
      await writeManifest();
      snapshots({taskIdOf(volumeId): TransferState.paused});

      await start();

      expect(harness.transport.resumed, [taskIdOf(volumeId)]);
      expect(harness.transport.enqueued, isEmpty, reason: '先頭から落とし直さない');
    });

    test('再開データが無ければ積み直す', () async {
      await saveRow(VolumeDownloadStatus.queued);
      snapshots({taskIdOf(volumeId): TransferState.paused});
      harness.transport.resumeResult = false;

      await start();

      expect(harness.transport.enqueued, hasLength(1));
      expect(harness.transport.forgotten, contains(taskIdOf(volumeId)));
    });

    test('失敗で終わっていた転送は回数を数え直して再開する', () async {
      await saveRow(VolumeDownloadStatus.queued);
      snapshots({taskIdOf(volumeId): TransferState.failed});

      final container = await start();

      expect(harness.delays, [const Duration(seconds: 2)]);
      expect(harness.transport.resumed, [taskIdOf(volumeId)]);
      expect(downloadOf(container)!.isActive, isTrue);
    });

    test('通知の Cancel でアプリが死んでいる間に止められた巻は中断にする', () async {
      await saveRow(VolumeDownloadStatus.downloading);
      snapshots({taskIdOf(volumeId): TransferState.canceled});

      final container = await start();

      expect(downloadOf(container)!.status, VolumeDownloadStatus.paused);
      expect(harness.transport.enqueued, isEmpty);
      expect(harness.transport.forgotten, contains(taskIdOf(volumeId)));
    });

    test('プラグインの自動再投入に任せず、新しいトークンで積み直す', () async {
      await saveRow(VolumeDownloadStatus.downloading);
      // プロセスごと殺されて holding queue の中身が消えた。
      snapshots({taskIdOf(volumeId): TransferState.notFound});
      harness.authStore.token = 'token-2';

      await start();

      expect(harness.transport.enqueued, hasLength(1));
      expect(harness.transport.enqueued.single.headers, {
        'Authorization': 'Bearer token-2',
      }, reason: '古いトークンを焼き込んだまま積み直すと 401 になる（F5）');
      expect(harness.transport.forgotten, contains(taskIdOf(volumeId)));
    });

    test('Wi-Fi 待ちのままアプリが落ちても、次に起動すれば積み直す', () async {
      await saveRow(VolumeDownloadStatus.queued);

      final container = await start();

      expect(
        harness.transport.enqueued,
        hasLength(1),
        reason: '「Wi-Fi に戻ると再開」の約束をアプリの再起動で破らない',
      );
      expect(downloadOf(container)!.isActive, isTrue);
    });
  });

  group('止めて捨てる', () {
    test('中断 / 失敗 / 完了の巻に生きている転送が残っていたら止めて捨てる', () async {
      await saveRow(VolumeDownloadStatus.paused);
      await saveRow(VolumeDownloadStatus.failed, id: 341);
      await saveRow(
        VolumeDownloadStatus.completed,
        id: 342,
        filesVersion: 100,
        pageCount: 3,
      );
      for (final id in [volumeId, 341, 342]) {
        await harness.store.ensureVolumeDirectory(id);
        stagingOf(id).writeAsBytesSync([1, 2, 3]);
      }
      snapshots({
        taskIdOf(volumeId): TransferState.running,
        taskIdOf(341): TransferState.enqueued,
        taskIdOf(342): TransferState.running,
      });

      await start();

      expect(
        harness.transport.canceled,
        unorderedEquals([taskIdOf(volumeId), taskIdOf(341), taskIdOf(342)]),
        reason: '止めたはずの巻が裏で数百 MB を落とし続けないように',
      );
      for (final id in [volumeId, 341, 342]) {
        expect(stagingOf(id).existsSync(), isFalse);
      }
      expect(harness.transport.enqueued, isEmpty);
    });

    test('ユーザーが止めた巻の再開データは残し、再開で続きから取る', () async {
      await saveRow(VolumeDownloadStatus.paused);
      snapshots({taskIdOf(volumeId): TransferState.paused});

      final container = await start();

      expect(harness.transport.canceled, isEmpty);
      expect(downloadOf(container)!.status, VolumeDownloadStatus.paused);

      await container.read(downloadQueueProvider.notifier).resume(volumeId);
      await settle();

      expect(harness.transport.resumed, [taskIdOf(volumeId)]);
      expect(harness.transport.enqueued, isEmpty);
    });

    test('台帳に無い巻の転送は止めて捨てる', () async {
      await harness.store.ensureVolumeDirectory(999);
      stagingOf(999).writeAsBytesSync([1, 2, 3]);
      snapshots({taskIdOf(999): TransferState.running});

      await start();

      expect(harness.transport.canceled, [taskIdOf(999)]);
      expect(harness.transport.forgotten, contains(taskIdOf(999)));
      expect(
        harness.store.volumeDirectory(999).existsSync(),
        isFalse,
        reason: '削除の途中で落ちた巻の残りを端末に残さない',
      );
    });

    test('別のセッションのタグの転送は取り込まない', () async {
      await saveRow(VolumeDownloadStatus.queued);
      await writeManifest();
      final foreign = taskIdOf(volumeId, sessionTag: 'PreviousUser1');
      stagingOf(volumeId).writeAsBytesSync(harness.api.archiveBytes);
      snapshots({foreign: TransferState.completed});

      final container = await start();

      expect(
        downloadOf(container)!.status,
        isNot(VolumeDownloadStatus.completed),
        reason: 'ログアウト前のユーザーの転送を今のユーザーの巻として確定しない（#15）',
      );
      expect(harness.transport.forgotten, contains(foreign));
      expect(
        ArchiveTaskId.tryParse(harness.transport.enqueued.single.taskId)!
            .sessionTag,
        tag,
        reason: '今のセッションとして積み直す',
      );
    });

    test('他の用途の taskId は止めて捨てる', () async {
      snapshots({'something-else': TransferState.running});

      await start();

      expect(harness.transport.canceled, ['something-else']);
      expect(harness.transport.forgotten, contains('something-else'));
    });
  });

  test('旧 Dio の .part と孤児の .zip.download と余った json を掃除する', () async {
    await saveRow(
      VolumeDownloadStatus.completed,
      filesVersion: 111,
      pageCount: 3,
    );
    await writeManifest();
    harness.archiveFile().writeAsBytesSync(harness.api.archiveBytes);
    final directory = harness.store.volumeDirectory(volumeId).path;
    final legacyPart = File(p.join(directory, '111.zip.part'))
      ..writeAsBytesSync([1]);
    final orphan = File(p.join(directory, '50.zip.download'))
      ..writeAsBytesSync([1]);
    final staleJson = File(p.join(directory, '99.json'))
      ..writeAsStringSync('{}');

    await start();

    expect(legacyPart.existsSync(), isFalse, reason: '新しい経路では続きに使えない');
    expect(orphan.existsSync(), isFalse, reason: '対応する転送が無い書きかけ');
    expect(staleJson.existsSync(), isFalse);
    expect(harness.archiveFile().existsSync(), isTrue, reason: 'オフラインで読める実体');
    expect(
      await harness.store.readManifest(volumeId: volumeId, filesVersion: 111),
      isNotNull,
    );
  });
}
