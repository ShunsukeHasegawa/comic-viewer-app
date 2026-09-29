import 'dart:async';
import 'dart:typed_data';

import 'package:comic_laz/core/device/network_kind_monitor.dart';
import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/features/downloads/application/download_queue.dart';
import 'package:comic_laz/features/downloads/application/download_settings.dart';
import 'package:comic_laz/features/downloads/data/archive_transport.dart';
import 'package:comic_laz/features/downloads/data/archive_verifier.dart';
import 'package:comic_laz/features/downloads/domain/archive_task_id.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/download_fakes.dart';

/// テスト対象の巻。
const volumeId = 340;
const bookId = 12;

typedef QueueScope = ({
  DownloadHarness harness,
  ProviderContainer container,
  DownloadQueue queue,
});

/// 設定が読めない端末（drift が壊れている等）。
class _BrokenWifiOnly extends DownloadWifiOnly {
  @override
  Future<bool> build() async => throw StateError('settings unavailable');
}

void main() {
  /// 直近に組み立てたキュー（[settle] が「落ち着いたか」を見るのに使う）。
  ProviderContainer? active;

  /// キューが落ち着くまで待つ（[settleDownloads] のコメント参照）。
  Future<void> settle() => settleDownloads(active!);

  /// 3 ページの ZIP を配る一式（キューはまだ作らない）。
  DownloadHarness createHarness({
    Uint8List? archiveBytes,
    int pageCount = 3,
    int? archiveBytesOverride,
    int filesVersion = 111,
    ArchiveVerifier? verifier,
    NetworkKind network = NetworkKind.unmetered,
  }) {
    final bytes = archiveBytes ?? zipWithPages(3);
    final harness = DownloadHarness.create(
      manifest: testManifest(
        id: volumeId,
        bookId: bookId,
        filesVersion: filesVersion,
        archiveBytes: archiveBytesOverride ?? bytes.length,
        pageCount: pageCount,
      ),
      archiveBytes: bytes,
    )..verifier = verifier;
    harness.network.kind = network;
    return harness;
  }

  /// キューを組み立てる（台帳や OS 側の状態を用意してから呼ぶ）。
  QueueScope startQueue(
    DownloadHarness harness, {
    List<Override> overrides = const [],
  }) {
    final container = ProviderContainer(
      overrides: [...harness.overrides(), ...overrides],
    );
    addTearDown(container.dispose);
    // アプリと同じく購読しておく（購読の無い provider は一時停止され、
    // 回線の切り替えがキューに届かない。app.dart 参照）。
    container.listen(downloadQueueProvider, (_, _) {});
    active = container;
    return (
      harness: harness,
      container: container,
      queue: container.read(downloadQueueProvider.notifier),
    );
  }

  QueueScope setUpQueue({
    Uint8List? archiveBytes,
    int pageCount = 3,
    int? archiveBytesOverride,
    ArchiveVerifier? verifier,
    NetworkKind network = NetworkKind.unmetered,
  }) => startQueue(
    createHarness(
      archiveBytes: archiveBytes,
      pageCount: pageCount,
      archiveBytesOverride: archiveBytesOverride,
      verifier: verifier,
      network: network,
    ),
  );

  /// 条件が満たされるまで待つ（処理をゲートで止めているときは [settle] が
  /// 使えない）。
  Future<void> waitUntil(bool Function() condition) async {
    for (var round = 0; round < 200 && !condition(); round++) {
      await pumpEventQueue(times: 5);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  VolumeDownload? downloadOf(
    ProviderContainer container, [
    int id = volumeId,
  ]) => container.read(downloadQueueProvider).value?[id];

  /// 積んで OS に渡したところまで進める。
  Future<void> enqueueAndSubmit(QueueScope scope, [int id = volumeId]) async {
    await scope.queue.enqueue(volumeId: id, bookId: bookId);
    await settle();
  }

  /// 111 を落とし終えた状態にする。
  Future<QueueScope> setUpCompleted() async {
    final scope = setUpQueue();
    await enqueueAndSubmit(scope);
    scope.harness.transport.completeWith(
      volumeId,
      scope.harness.api.archiveBytes,
    );
    await settle();
    expect(downloadOf(scope.container)!.status, VolumeDownloadStatus.completed);
    return scope;
  }

  /// 111 を落とし終えたあと、サーバー側が 222 に差し替わった状態にする。
  Future<QueueScope> setUpOutdated() async {
    final scope = await setUpCompleted();
    scope.harness.api.manifest = testManifest(
      id: volumeId,
      bookId: bookId,
      filesVersion: 222,
      archiveBytes: scope.harness.api.archiveBytes.length,
    );
    return scope;
  }

  group('積む', () {
    test('1 巻から順に読めるよう、積んだ順に creationTime を増やして投入する', () async {
      final scope = setUpQueue();
      for (final id in [341, 342]) {
        scope.harness.api.manifests[id] = testManifest(
          id: id,
          bookId: bookId,
          archiveBytes: scope.harness.api.archiveBytes.length,
        );
      }

      await scope.queue.enqueueAll([
        (volumeId: volumeId, bookId: bookId),
        (volumeId: 341, bookId: bookId),
        (volumeId: 342, bookId: bookId),
      ]);
      await settle();

      final requests = scope.harness.transport.enqueued;
      expect(requests.map((r) => ArchiveTaskId.tryParse(r.taskId)!.volumeId), [
        volumeId,
        341,
        342,
      ]);
      final times = [
        for (final request in requests)
          request.creationTime.millisecondsSinceEpoch,
      ];
      for (var i = 1; i < times.length; i++) {
        expect(
          times[i],
          greaterThan(times[i - 1]),
          reason: 'holding queue は同じミリ秒の順序を保証しない（F4）',
        );
      }
      final first = requests.first;
      expect(first.directory, 'downloads/$volumeId');
      expect(first.filename, '111.zip.download');
      expect(
        first.uri.toString(),
        'http://localhost:8000/api/v2/volumes/$volumeId/archive',
      );
    });

    test('同じ巻を二重に積まない（自宅サーバーへ同じ ZIP を 2 回取りに行かない）', () async {
      final scope = setUpQueue();

      await enqueueAndSubmit(scope);
      await enqueueAndSubmit(scope);

      expect(scope.harness.transport.enqueued, hasLength(1));
    });

    test('マニフェスト取得中に止めた巻は投入しない', () async {
      final scope = setUpQueue();
      scope.harness.api.onManifest = () => scope.queue.pause(volumeId);

      await enqueueAndSubmit(scope);

      expect(
        scope.harness.transport.enqueued,
        isEmpty,
        reason: '「中断中」と表示したまま数百 MB を落としきってはいけない',
      );
      expect(downloadOf(scope.container)!.status, VolumeDownloadStatus.paused);
    });

    test('通信エラーで積めなかった巻は queued のまま残し、回線が戻ったら投入する', () async {
      final scope = setUpQueue();
      scope.harness.api.manifestError = const NetworkException();

      await enqueueAndSubmit(scope);

      final waiting = downloadOf(scope.container)!;
      expect(
        waiting.status,
        VolumeDownloadStatus.queued,
        reason: 'まとめて積んだ巻が圏外で一斉に「失敗」にならないように',
      );
      expect(scope.harness.transport.enqueued, isEmpty);

      scope.harness.api.manifestError = null;
      scope.harness.connectivity.restore();
      await settle();

      expect(scope.harness.transport.enqueued, hasLength(1));
    });

    test('前面に戻ったときも、積めずに残った巻を投入する', () async {
      final scope = setUpQueue();
      scope.harness.api.manifestError = const ApiTimeoutException();

      await enqueueAndSubmit(scope);
      expect(scope.harness.transport.enqueued, isEmpty);

      scope.harness.api.manifestError = null;
      scope.harness.lifecycle.resume();
      await settle();

      expect(scope.harness.transport.enqueued, hasLength(1));
    });

    test('削除済みの巻（404）は理由を残して失敗にする', () async {
      final scope = setUpQueue();
      scope.harness.api.manifestError = const NotFoundException();

      await enqueueAndSubmit(scope);

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.failed);
      expect(download.failureReason, const NotFoundException().message);
      expect(scope.harness.transport.enqueued, isEmpty);
    });

    test('空き容量には投入済みで未確定の巻の残りも含める', () async {
      final scope = setUpQueue();
      final size = scope.harness.api.archiveBytes.length;
      scope.harness.api.manifests[341] = testManifest(
        id: 341,
        bookId: bookId,
        archiveBytes: size,
      );
      // 1 巻なら入るが、2 巻目は「1 巻目の残り」を足すと入らない空き。
      scope.harness.freeSpace = freeSpaceMarginBytes + size + size ~/ 2;

      await scope.queue.enqueueAll([
        (volumeId: volumeId, bookId: bookId),
        (volumeId: 341, bookId: bookId),
      ]);
      await settle();

      expect(scope.harness.transport.enqueued, hasLength(1));
      final second = downloadOf(scope.container, 341)!;
      expect(
        second.status,
        VolumeDownloadStatus.failed,
        reason: '1 巻ずつ見ると全巻「入る」と判定され、後半が転送の途中で詰まる（F7）',
      );
      expect(second.failureReason, contains('空き容量'));
    });

    test('空き容量が取得できない端末では止めない', () async {
      final scope = setUpQueue();
      scope.harness.freeSpace = null;

      await enqueueAndSubmit(scope);

      expect(scope.harness.transport.enqueued, hasLength(1));
    });

    test('Bearer は API と同じオリジンにしか付けない', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      expect(scope.harness.transport.requestOf(volumeId).headers, {
        'Authorization': 'Bearer token-1',
      }, reason: 'ZIP は自宅サーバーの認証付きエンドポイント');
    });

    test('将来 CDN / 署名付き URL に変わっても、他のホストへトークンを送らない', () async {
      final other = setUpQueue();
      other.harness.api.archiveOrigin = 'https://cdn.example.com';
      await enqueueAndSubmit(other);
      expect(other.harness.transport.requestOf(volumeId).headers, isEmpty);
    });

    test('更新で世代が変わったら旧世代のタスクを取り消す', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      final oldTask = scope.harness.transport.taskIdOf(volumeId);
      await scope.queue.pause(volumeId);
      await settle();

      scope.harness.api.manifest = testManifest(
        id: volumeId,
        bookId: bookId,
        filesVersion: 222,
        archiveBytes: scope.harness.api.archiveBytes.length,
      );
      await enqueueAndSubmit(scope);

      expect(scope.harness.transport.canceled, contains(oldTask));
      expect(
        ArchiveTaskId.tryParse(scope.harness.transport.taskIdOf(volumeId))!
            .filesVersion,
        222,
      );
    });

    test('アプリが閉じている間に確定できるよう、投入前にマニフェストを書く', () async {
      final scope = setUpQueue();

      await enqueueAndSubmit(scope);

      expect(
        await scope.harness.store.readManifest(
          volumeId: volumeId,
          filesVersion: 111,
        ),
        isNotNull,
      );
      expect(
        downloadOf(scope.container)!.filesVersion,
        0,
        reason: '台帳の世代は検証が通るまで書かない（#11 は台帳の世代だけを見る）',
      );
    });

    test('通知の許可は最初に積んだときに一度だけ求める', () async {
      final harness = createHarness();
      harness.api.manifests[341] = testManifest(
        id: 341,
        bookId: bookId,
        archiveBytes: harness.api.archiveBytes.length,
      );
      final scope = startQueue(harness);

      await enqueueAndSubmit(scope);
      await enqueueAndSubmit(scope, 341);

      expect(
        harness.transport.notificationRequests,
        1,
        reason: '断られた後に積むたびダイアログを出し直さない',
      );
      expect(
        await scope.container
            .read(downloadSettingsStoreProvider)
            .readNotificationPermissionRequested(),
        isTrue,
        reason: 'アプリを開き直しても聞き直さない',
      );
    });
  });

  group('完了', () {
    test('検証を通ってから初めて世代の 3 項目を書く', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      final before = downloadOf(scope.container)!;
      expect(before.filesVersion, 0);
      expect(before.pageCount, 0);
      expect(before.archiveEtag, isNull);

      final taskId = scope.harness.transport.taskIdOf(volumeId);
      scope.harness.transport.completeWith(
        volumeId,
        scope.harness.api.archiveBytes,
      );
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.completed);
      expect(download.filesVersion, 111);
      expect(download.pageCount, 3);
      expect(download.archiveEtag, 'a1b2-c3d4');
      expect(download.receivedBytes, download.totalBytes);
      expect(scope.harness.archiveFile().existsSync(), isTrue);
      expect(
        scope.harness.stagingFile().existsSync(),
        isFalse,
        reason: '書きかけは rename で消える（中途半端なデータを残さない）',
      );
      expect(scope.harness.transport.forgotten, contains(taskId));
      // アプリを開き直しても「ダウンロード済み」と分かるよう台帳にも残る。
      expect(
        (await scope.harness.store.find(volumeId))?.status,
        VolumeDownloadStatus.completed,
      );
    });

    // 詳細画面（autoDispose）は「ダウンロードを始めてすぐ一覧へ戻る」だけで
    // 破棄されるので、完了時に詳細を控えられない（#11 のレビュー指摘）。
    test('完了したらオフライン用の詳細を控えに行く（画面が無くても）', () async {
      final scope = await setUpCompleted();

      expect(scope.harness.warmedBooks, [bookId]);
    });

    test('完了が再送されても一度しか確定しない', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      final taskId = scope.harness.transport.taskIdOf(volumeId);
      scope.harness.transport.completeWith(
        volumeId,
        scope.harness.api.archiveBytes,
      );
      await settle();

      // `start` のたびに完了が再送される / markDownloadedComplete。
      scope.harness.transport.emit(
        TransferStateChanged(taskId, TransferState.completed),
      );
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.completed);
      expect(download.failureReason, isNull);
      expect(scope.harness.warmedBooks, [bookId]);
      expect(scope.harness.archiveFile().existsSync(), isTrue);
    });

    test('rename 済みでマニフェストが無い巻は確定し直すときに書き直す', () async {
      final harness = createHarness();
      // rename は済んだが {v}.json を書く前に落ちた状態。
      await harness.store.ensureVolumeDirectory(volumeId);
      harness.archiveFile().writeAsBytesSync(harness.api.archiveBytes);
      final scope = startQueue(harness);

      await enqueueAndSubmit(scope);

      expect(
        harness.transport.enqueued,
        isEmpty,
        reason: '同じ世代が手元にあるので落とし直さない',
      );
      expect(
        downloadOf(scope.container)!.status,
        VolumeDownloadStatus.completed,
      );
      expect(
        await harness.store.readManifest(volumeId: volumeId, filesVersion: 111),
        isNotNull,
        reason: '{v}.json が無いまま確定すると #11 がページを解決できない',
      );
    });

    test('確定の直前に取り消したら「ダウンロード済み」を復活させない', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      // rename は済み、旧世代の掃除で待っている状態を作る。
      final gate = Completer<void>();
      scope.harness.store.beforeDeleteOtherVersions = gate;
      scope.harness.transport.completeWith(
        volumeId,
        scope.harness.api.archiveBytes,
      );
      await waitUntil(() => scope.harness.archiveFile().existsSync());

      await scope.queue.remove(volumeId);
      gate.complete();
      await settle();

      expect(downloadOf(scope.container), isNull);
      expect(
        await scope.harness.store.find(volumeId),
        isNull,
        reason: '実体を消したあとに completed の行が残ると、読めない「ダウンロード済み」が出る',
      );
      expect(scope.harness.archiveFile().existsSync(), isFalse);
    });

    test('削除と競合した完了で completed を復活させない', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      final taskId = scope.harness.transport.taskIdOf(volumeId);

      await scope.queue.remove(volumeId);
      // 取り消しが届く前に、OS 側では書き終わっていた。
      scope.harness.transport.completeTask(
        taskId,
        scope.harness.api.archiveBytes,
      );
      await settle();

      expect(downloadOf(scope.container), isNull);
      expect(await scope.harness.store.find(volumeId), isNull);
      expect(scope.harness.archiveFile().existsSync(), isFalse);
      expect(scope.harness.stagingFile().existsSync(), isFalse);
    });

    test('積んだ巻をすべて確定する（まとめて積む）', () async {
      final scope = setUpQueue();
      scope.harness.api.manifests[341] = testManifest(
        id: 341,
        archiveBytes: scope.harness.api.archiveBytes.length,
      );
      await scope.queue.enqueueAll([
        (volumeId: volumeId, bookId: bookId),
        (volumeId: 341, bookId: bookId),
      ]);
      await settle();

      for (final id in [volumeId, 341]) {
        scope.harness.transport.completeWith(
          id,
          scope.harness.api.archiveBytes,
        );
      }
      await settle();

      expect(
        downloadOf(scope.container)!.status,
        VolumeDownloadStatus.completed,
      );
      expect(
        downloadOf(scope.container, 341)!.status,
        VolumeDownloadStatus.completed,
      );
    });
  });

  group('検証', () {
    Future<VolumeDownload> completeWithBytes(
      QueueScope scope,
      List<int> bytes,
    ) async {
      await enqueueAndSubmit(scope);
      scope.harness.transport.completeWith(volumeId, bytes);
      await settle();
      return downloadOf(scope.container)!;
    }

    test('サイズが一致しなければ「ダウンロード済み」にせず書きかけを捨てる', () async {
      final bytes = zipWithPages(3);
      // サーバーの申告より短いデータしか届かなかった状況。
      final scope = setUpQueue(
        archiveBytes: bytes,
        archiveBytesOverride: bytes.length + 128,
      );

      final download = await completeWithBytes(scope, bytes);

      expect(download.status, VolumeDownloadStatus.failed);
      expect(download.failureReason, contains('サイズが一致しません'));
      expect(scope.harness.archiveFile().existsSync(), isFalse);
      expect(
        scope.harness.stagingFile().existsSync(),
        isFalse,
        reason: '捨てておかないと次の取得も同じところで詰まる',
      );
    });

    test('ページ数がマニフェストと違えば失敗にする', () async {
      final scope = setUpQueue(pageCount: 5);

      final download = await completeWithBytes(
        scope,
        scope.harness.api.archiveBytes,
      );

      expect(download.status, VolumeDownloadStatus.failed);
      expect(download.failureReason, contains('ページ数が一致しません'));
      expect(scope.harness.archiveFile().existsSync(), isFalse);
    });

    test('ZIP として開けなければ失敗にする', () async {
      // ZIP ではないバイト列（プロキシがエラーページを返した等）。
      final broken = Uint8List.fromList(List<int>.filled(512, 0x41));
      final scope = setUpQueue(archiveBytes: broken);

      final download = await completeWithBytes(scope, broken);

      expect(download.status, VolumeDownloadStatus.failed);
      expect(download.failureReason, isNotNull);
      expect(scope.harness.stagingFile().existsSync(), isFalse);
      expect(
        scope.harness.transport.enqueued,
        hasLength(1),
        reason: '壊れたものを自動で取り直し続けると自宅サーバーを叩き続ける',
      );
    });

    test('検証が例外を投げても失敗として扱う（想定外の例外を UI に漏らさない）', () async {
      final scope = setUpQueue(
        verifier: (file) async => throw StateError('壊れた'),
      );

      final download = await completeWithBytes(
        scope,
        scope.harness.api.archiveBytes,
      );

      expect(download.status, VolumeDownloadStatus.failed);
      expect(scope.harness.stagingFile().existsSync(), isFalse);
    });

    test('ArchiveVerificationException の文言をそのまま見せる', () async {
      final scope = setUpQueue(
        verifier: (file) async =>
            throw const ArchiveVerificationException('ダウンロードしたファイルを開けませんでした。'),
      );

      final download = await completeWithBytes(
        scope,
        scope.harness.api.archiveBytes,
      );

      expect(download.failureReason, 'ダウンロードしたファイルを開けませんでした。');
    });

    test('検証に落ちて files_version が変わっていたら自動で取り直す', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      // 転送の途中でサーバー側の ZIP が差し替わった（落ちてきたのは混ざりもの）。
      scope.harness.api.manifest = testManifest(
        id: volumeId,
        bookId: bookId,
        filesVersion: 222,
        archiveBytes: scope.harness.api.archiveBytes.length,
      );
      scope.harness.transport.completeWith(
        volumeId,
        Uint8List.fromList(
          List<int>.filled(scope.harness.api.archiveBytes.length, 0x41),
        ),
      );
      await settle();

      expect(scope.harness.transport.enqueued, hasLength(2));
      expect(
        ArchiveTaskId.tryParse(scope.harness.transport.taskIdOf(volumeId))!
            .filesVersion,
        222,
      );
      expect(downloadOf(scope.container)!.isActive, isTrue);

      scope.harness.transport.completeWith(
        volumeId,
        scope.harness.api.archiveBytes,
      );
      await settle();
      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.completed);
      expect(download.filesVersion, 222);
    });
  });

  group('一時停止（F1）', () {
    test('9 分の時間切れによる一時停止はユーザーの中断ではないので、取得中のまま続ける', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      scope.harness.transport.setState(volumeId, TransferState.running);
      await settle();
      expect(
        downloadOf(scope.container)!.status,
        VolumeDownloadStatus.downloading,
      );

      // WorkManager の時間切れ。ネイティブが 1 秒後に自分で再投入する。
      scope.harness.transport.setState(volumeId, TransferState.paused);
      await settle();

      expect(
        downloadOf(scope.container)!.status,
        VolumeDownloadStatus.downloading,
        reason: '「中断中」にすると勝手に止まったように見え、次の起動の照合で殺してしまう',
      );
      expect(scope.harness.transport.canceled, isEmpty);
    });

    test('ユーザーが止めた巻に届いた paused は何も変えない', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      final taskId = scope.harness.transport.taskIdOf(volumeId);
      scope.harness.transport.setState(volumeId, TransferState.running);
      await settle();

      await scope.queue.pause(volumeId);
      scope.harness.transport.setState(volumeId, TransferState.paused);
      await settle();

      expect(scope.harness.transport.paused, [taskId]);
      expect(downloadOf(scope.container)!.status, VolumeDownloadStatus.paused);
      expect(scope.harness.transport.canceled, isEmpty);

      await scope.queue.resume(volumeId);
      await settle();

      expect(scope.harness.transport.resumed, [
        taskId,
      ], reason: '再開データから続きを取る（先頭から落とし直さない）');
      expect(scope.harness.transport.enqueued, hasLength(1));
      expect(downloadOf(scope.container)!.isActive, isTrue);
    });

    test('走っていない巻の中断は取り消しに切り替え、中断として残す', () async {
      final scope = setUpQueue();
      scope.harness.transport.pauseResult = false;
      await enqueueAndSubmit(scope);
      final taskId = scope.harness.transport.taskIdOf(volumeId);
      scope.harness.stagingFile().writeAsBytesSync([1, 2, 3]);

      await scope.queue.pause(volumeId);
      await settle();

      expect(scope.harness.transport.canceled, [
        taskId,
      ], reason: 'holding queue で待っている転送は一時停止できない。止めないと後で走り出す');
      expect(downloadOf(scope.container)!.status, VolumeDownloadStatus.paused);
      expect(scope.harness.stagingFile().existsSync(), isFalse);
    });

    test('再開データが無ければ投入し直す', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      await scope.queue.pause(volumeId);
      await settle();

      scope.harness.transport.resumeResult = false;
      await scope.queue.resume(volumeId);
      await settle();

      expect(scope.harness.transport.enqueued, hasLength(2));
      expect(downloadOf(scope.container)!.status, VolumeDownloadStatus.queued);
    });

    test('Wi-Fi 待ちの巻もユーザーが中断できる', () async {
      final scope = setUpQueue(network: NetworkKind.metered);
      await enqueueAndSubmit(scope);

      await scope.queue.pause(volumeId);
      await settle();

      expect(downloadOf(scope.container)!.status, VolumeDownloadStatus.paused);
      expect(scope.harness.transport.paused, hasLength(1));
    });

    test('通知の Cancel は中断として扱い、完了済みの ZIP は消さない', () async {
      final scope = await setUpOutdated();
      await enqueueAndSubmit(scope);

      // 通知のボタンから止められた（Dart を経由しない取り消し）。
      scope.harness.transport.setState(volumeId, TransferState.canceled);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(
        download.status,
        VolumeDownloadStatus.completed,
        reason: '取り直しの中断は旧世代へ戻す（読める 111 を指す行を消さない）',
      );
      expect(download.filesVersion, 111);
      expect(scope.harness.archiveFile(filesVersion: 111).existsSync(), isTrue);
    });

    test('通知の Cancel で止まった初回の巻は中断として台帳に残す', () async {
      final fresh = setUpQueue();
      await enqueueAndSubmit(fresh);
      fresh.harness.transport.setState(volumeId, TransferState.canceled);
      await settle();
      expect(
        downloadOf(fresh.container)!.status,
        VolumeDownloadStatus.paused,
        reason: '削除は画面の操作だけ。通知から消えた巻を台帳から消さない',
      );
    });
  });

  group('失敗', () {
    test('ネイティブの 401 ではすぐにログアウトさせず、マニフェストを取り直して本当に失効しているか確かめる', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      // タスクに焼き込んだトークンだけが古い（アプリでは再ログイン済み）。
      scope.harness.authStore.token = 'token-2';

      scope.harness.transport.fail(volumeId, TransferFailureKind.unauthorized);
      await settle();

      expect(scope.harness.api.manifestCalls, 2);
      expect(scope.harness.transport.enqueued, hasLength(2));
      expect(scope.harness.transport.enqueued.last.headers, {
        'Authorization': 'Bearer token-2',
      }, reason: '生きていれば新しいトークンで積み直す');
      expect(downloadOf(scope.container)!.isActive, isTrue);
    });

    test('本当に失効していれば AuthInterceptor の 1 経路でだけログアウトする', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      var sessionExpired = 0;
      // AuthInterceptor の振る舞い（401 → handleSessionExpired → 破棄）を模す。
      scope.harness.api.onManifest = () async {
        sessionExpired++;
        await scope.queue.purgeAll();
      };
      scope.harness.api.manifestError = const UnauthorizedException();

      scope.harness.transport.fail(volumeId, TransferFailureKind.unauthorized);
      await settle();

      expect(sessionExpired, 1);
      expect(scope.container.read(downloadQueueProvider).value, isEmpty);
      expect(scope.harness.transport.resetCount, 1);
      expect(
        scope.harness.transport.enqueued,
        hasLength(1),
        reason: '失効したトークンで積み直さない',
      );
    });

    test('5xx は 3 回まで待って再開する', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      final taskId = scope.harness.transport.taskIdOf(volumeId);

      for (var i = 0; i < maxDownloadAttempts; i++) {
        scope.harness.transport.fail(volumeId, TransferFailureKind.server);
        await settle();
      }

      expect(scope.harness.delays, [
        const Duration(seconds: 2),
        const Duration(seconds: 4),
      ], reason: '自宅サーバーを叩き続けない');
      expect(scope.harness.transport.resumed, [taskId, taskId]);
      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.failed);
      expect(download.failureReason, isNotNull);
      expect(
        scope.harness.transport.forgotten,
        isNot(contains(taskId)),
        reason: '通信の失敗で手元の進捗（再開データ）を捨てない',
      );

      await scope.queue.resume(volumeId);
      await settle();
      expect(scope.harness.transport.resumed, hasLength(3));
    });

    test('Wi-Fi 限定で Wi-Fi が切れた失敗は回数に数えない', () async {
      final scope = setUpQueue(network: NetworkKind.metered);
      await enqueueAndSubmit(scope);
      expect(
        scope.container.read(downloadGateProvider),
        DownloadGate.waitingForWifi,
      );

      for (var i = 0; i < maxDownloadAttempts + 1; i++) {
        scope.harness.transport.fail(volumeId, TransferFailureKind.connection);
        await settle();
      }

      expect(
        downloadOf(scope.container)!.isActive,
        isTrue,
        reason: 'Wi-Fi が 3 回途切れるだけで「失敗」にしない（F3）',
      );
      expect(scope.harness.delays, isEmpty);
      expect(
        scope.harness.transport.resumed,
        hasLength(maxDownloadAttempts + 1),
      );
    });

    test('resumeMismatch は先頭から取り直す', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      scope.harness.stagingFile().writeAsBytesSync([1, 2, 3]);

      scope.harness.transport.fail(
        volumeId,
        TransferFailureKind.resumeMismatch,
      );
      await settle();

      expect(scope.harness.transport.resumed, isEmpty, reason: '続きを足すと別世代が混ざる');
      expect(scope.harness.api.manifestCalls, 2);
      expect(scope.harness.transport.enqueued, hasLength(2));
      expect(scope.harness.stagingFile().existsSync(), isFalse);
    });

    test('容量不足は再試行しない', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);

      scope.harness.transport.fail(
        volumeId,
        TransferFailureKind.fileSystem,
        message: 'java.io.IOException: No space left on device',
      );
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.failed);
      expect(download.failureReason, contains('空き容量'));
      expect(scope.harness.delays, isEmpty);
      expect(scope.harness.transport.enqueued, hasLength(1));
    });

    test('権限が無い巻（403）は再試行しない', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);

      scope.harness.transport.fail(volumeId, TransferFailureKind.forbidden);
      await settle();

      expect(downloadOf(scope.container)!.status, VolumeDownloadStatus.failed);
      expect(scope.harness.delays, isEmpty);
      expect(scope.harness.transport.resumed, isEmpty);
    });

    test('投入を断られたら理由を出して失敗にする', () async {
      final scope = setUpQueue();
      scope.harness.transport.enqueueResult = false;

      await enqueueAndSubmit(scope);

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.failed);
      expect(download.failureReason, '転送を開始できませんでした。');
    });
  });

  group('進捗', () {
    test('進捗は表示には毎回、DB には 4MB ごとに書く', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      final taskId = scope.harness.transport.taskIdOf(volumeId);
      const mb = 1024 * 1024;

      scope.harness.transport.emit(
        TransferProgressed(taskId, received: mb, total: 10 * mb),
      );
      await settle();

      final shown = downloadOf(scope.container)!;
      expect(shown.receivedBytes, mb);
      expect(shown.status, VolumeDownloadStatus.downloading);
      expect(
        (await scope.harness.store.find(volumeId))!.receivedBytes,
        0,
        reason: '1 巻で数千回の UPDATE にしない',
      );

      scope.harness.transport.emit(
        TransferProgressed(taskId, received: 5 * mb, total: 10 * mb),
      );
      await settle();
      expect((await scope.harness.store.find(volumeId))!.receivedBytes, 5 * mb);
    });
  });

  group('Wi-Fi 限定（#10）', () {
    test('Wi-Fi 限定でもモバイル回線のうちに積んでおき、Wi-Fi を待つのは OS に任せる', () async {
      final scope = setUpQueue(network: NetworkKind.metered);

      await enqueueAndSubmit(scope);

      expect(
        scope.harness.transport.startCalls.single.wifiOnly,
        isTrue,
        reason: 'アプリが閉じていても Wi-Fi に繋がったら始まるように、制限は OS 側で掛ける',
      );
      expect(scope.harness.transport.enqueued, hasLength(1));
      expect(
        scope.container.read(downloadGateProvider),
        DownloadGate.waitingForWifi,
        reason: '画面の「Wi-Fi 待ち」表示は DownloadGate が出す',
      );
    });

    test('設定の変更をネイティブの requireWiFi に反映する', () async {
      final scope = setUpQueue(network: NetworkKind.metered);
      await settle();

      await scope.container.read(downloadWifiOnlyProvider.notifier).set(false);
      await settle();

      expect(scope.harness.transport.wifiOnlyCalls, [false]);
      // アプリを開き直しても OFF のまま。
      expect(
        await scope.container
            .read(downloadSettingsStoreProvider)
            .readWifiOnly(),
        isFalse,
      );
    });

    test('設定が読めなければモバイル回線で落とさないよう Wi-Fi 限定にする', () async {
      final scope = startQueue(
        createHarness(),
        overrides: [downloadWifiOnlyProvider.overrideWith(_BrokenWifiOnly.new)],
      );

      await settle();

      expect(scope.harness.transport.startCalls.single.wifiOnly, isTrue);
    });
  });

  group('更新と削除', () {
    test('files_version が変わると「更新あり」になり、落とし直すと古い世代を捨てる', () async {
      final scope = await setUpCompleted();
      expect(downloadOf(scope.container)!.isOutdated(222), isTrue);
      expect(downloadOf(scope.container)!.isOutdated(111), isFalse);
      expect(
        downloadOf(scope.container)!.isOutdated(null),
        isFalse,
        reason: 'サーバー側が分からないだけで「更新あり」にはしない',
      );

      scope.harness.api.manifest = testManifest(
        id: volumeId,
        bookId: bookId,
        filesVersion: 222,
        archiveBytes: scope.harness.api.archiveBytes.length,
      );
      await enqueueAndSubmit(scope);
      scope.harness.transport.completeWith(
        volumeId,
        scope.harness.api.archiveBytes,
      );
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.completed);
      expect(download.filesVersion, 222);
      expect(scope.harness.archiveFile(filesVersion: 222).existsSync(), isTrue);
      expect(
        scope.harness.archiveFile(filesVersion: 111).existsSync(),
        isFalse,
        reason: '古い世代を残すと容量を二重に食う',
      );
    });

    test('巻単位で削除できる', () async {
      final scope = await setUpCompleted();

      await scope.queue.remove(volumeId);
      await settle();

      expect(downloadOf(scope.container), isNull);
      expect(scope.harness.archiveFile().existsSync(), isFalse);
      expect(await scope.harness.store.find(volumeId), isNull);
    });

    test('取得中に削除すると転送を止め、書きかけも台帳も残さない', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      final taskId = scope.harness.transport.taskIdOf(volumeId);
      scope.harness.stagingFile().writeAsBytesSync([1, 2, 3]);

      await scope.queue.remove(volumeId);
      await settle();

      expect(scope.harness.transport.canceled, [taskId]);
      expect(downloadOf(scope.container), isNull);
      expect(scope.harness.stagingFile().existsSync(), isFalse);
      expect(await scope.harness.store.find(volumeId), isNull);
    });
  });

  group('更新の取り直し', () {
    test('マニフェストが取れなくても完了済みを失敗にしない', () async {
      final scope = await setUpOutdated();
      // オフラインで「更新あり」を押した状況。
      scope.harness.api.manifestError = const NetworkException();

      await enqueueAndSubmit(scope);

      final download = downloadOf(scope.container)!;
      expect(
        download.status,
        VolumeDownloadStatus.completed,
        reason: '通信エラーで手元のキャッシュ（オフラインで読める旧世代）を捨てない',
      );
      expect(download.filesVersion, 111);
      expect(
        download.failureReason,
        const NetworkException().message,
        reason: '失敗を黙って隠さない（UI が理由を出す）',
      );
      expect(scope.harness.archiveFile(filesVersion: 111).existsSync(), isTrue);
    });

    test('取得が失敗したら手元の旧世代を「ダウンロード済み」として残す', () async {
      final scope = await setUpOutdated();
      await enqueueAndSubmit(scope);

      scope.harness.transport.fail(volumeId, TransferFailureKind.notFound);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.completed);
      expect(
        download.filesVersion,
        111,
        reason: '失敗した世代（222）を指すと、実体のある 111 を指す行がどこにも無くなる',
      );
      expect(download.failureReason, isNotNull);
      expect(scope.harness.archiveFile(filesVersion: 111).existsSync(), isTrue);
    });

    test('検証に落ちても旧世代の ZIP は読めるまま残す', () async {
      final scope = await setUpOutdated();
      await enqueueAndSubmit(scope);

      // 落とせたが ZIP が壊れていた（差し替え途中の ZIP を掴んだ）。
      scope.harness.transport.completeWith(
        volumeId,
        Uint8List.fromList(
          List<int>.filled(scope.harness.api.archiveBytes.length, 0x41),
        ),
      );
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.completed);
      expect(download.filesVersion, 111);
      expect(download.failureReason, isNotNull);
      expect(scope.harness.archiveFile(filesVersion: 111).existsSync(), isTrue);
      expect(
        scope.harness.stagingFile(filesVersion: 222).existsSync(),
        isFalse,
      );
    });

    test('取り直しを中断しても旧世代を指したまま、もう一度押せば続きから取る', () async {
      final scope = await setUpOutdated();
      await enqueueAndSubmit(scope);
      final newTask = scope.harness.transport.taskIdOf(volumeId);
      scope.harness.transport.setState(volumeId, TransferState.running);
      await settle();

      await scope.queue.pause(volumeId);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(
        download.status,
        VolumeDownloadStatus.completed,
        reason: '「中断中（222）」にすると、読める 111 を指す行が消える',
      );
      expect(download.filesVersion, 111);
      expect(download.failureReason, isNull, reason: '自分で止めたのは失敗ではない');
      expect(scope.harness.transport.paused, [newTask]);

      await enqueueAndSubmit(scope);

      expect(scope.harness.transport.resumed, [newTask]);
      expect(
        scope.harness.transport.enqueued,
        hasLength(2),
        reason: '111 と 222 の 1 回ずつ。222 を先頭から落とし直さない',
      );
    });
  });

  group('一時キャッシュとの独立', () {
    test('キャッシュの全削除でも LRU でもダウンロード済みは消えない', () async {
      final scope = await setUpCompleted();

      // ログアウト以外のキャッシュ削除（設定画面 / 上限超過）を全部走らせる。
      await scope.harness.cache.store.clear();
      await scope.harness.cache.store.evictToLimit(CachedImageKind.page, 0);

      expect(scope.harness.archiveFile().existsSync(), isTrue);
      expect(
        (await scope.harness.store.find(volumeId))?.status,
        VolumeDownloadStatus.completed,
      );
    });
  });

  group('ログアウト', () {
    test('破棄するとダウンロード済みの実体も台帳も残らない', () async {
      final scope = await setUpCompleted();

      await scope.queue.purgeAll();
      await settle();

      expect(scope.container.read(downloadQueueProvider).value, isEmpty);
      expect(scope.harness.archiveFile().existsSync(), isFalse);
      expect(await scope.harness.store.find(volumeId), isNull);
    });

    test('purgeAll は平文のトークンを含むタスクを先に消してからファイルを消す', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);

      await scope.queue.purgeAll();
      await settle();

      final log = scope.harness.log;
      expect(scope.harness.transport.resetCount, 1);
      expect(
        log.indexOf('reset'),
        lessThan(log.indexOf('deleteAllFiles')),
        reason: 'ファイル削除の途中で落ちても、Bearer 入りのタスク記録を残さない（#15）',
      );
    });

    test('タグを作り直し、前のセッションの完了が後から届いてもファイルを残さない', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      final oldTask = scope.harness.transport.taskIdOf(volumeId);
      final oldTag = ArchiveTaskId.tryParse(oldTask)!.sessionTag;

      await scope.queue.purgeAll();
      await settle();
      // 取り消しが間に合わず、OS 側で前のユーザーの転送が書き終わった。
      scope.harness.transport.completeTask(
        oldTask,
        scope.harness.api.archiveBytes,
      );
      await settle();

      expect(scope.container.read(downloadQueueProvider).value, isEmpty);
      expect(scope.harness.stagingFile().existsSync(), isFalse);
      expect(scope.harness.archiveFile().existsSync(), isFalse);
      expect(scope.harness.transport.forgotten, contains(oldTask));
      expect(await scope.harness.store.readSessionTag(), isNot(oldTag));
    });

    test('purge の await の隙に届いた完了を書き戻さない', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      final oldTask = scope.harness.transport.taskIdOf(volumeId);
      // タスクを消している最中に、書き終わった完了が届く。
      scope.harness.transport.onReset = () async {
        scope.harness.transport.completeTask(
          oldTask,
          scope.harness.api.archiveBytes,
        );
        await pumpEventQueue();
      };

      await scope.queue.purgeAll();
      await settle();

      expect(scope.container.read(downloadQueueProvider).value, isEmpty);
      expect(
        await scope.harness.store.find(volumeId),
        isNull,
        reason: '前のユーザーの巻が端末に残ってはいけない（#15）',
      );
      expect(scope.harness.archiveFile().existsSync(), isFalse);
    });

    test('破棄の途中で届いた取り消しを台帳へ書き戻さない', () async {
      final scope = setUpQueue();
      await enqueueAndSubmit(scope);
      final oldTask = scope.harness.transport.taskIdOf(volumeId);

      // 行の削除は終わり、実体の削除で待っている「破棄の途中」を作る。
      final gate = Completer<void>();
      scope.harness.store.beforeDeleteAllFiles = gate;
      final purge = scope.queue.purgeAll();
      await waitUntil(() => scope.harness.log.contains('deleteAllFiles'));

      scope.harness.transport.emit(
        TransferStateChanged(oldTask, TransferState.canceled),
      );
      await pumpEventQueue();
      gate.complete();
      await purge;
      await settle();

      expect(
        await scope.harness.store.find(volumeId),
        isNull,
        reason: '前のユーザーの巻が「中断中」として端末に残ってはいけない（#15）',
      );
      expect(scope.container.read(downloadQueueProvider).value, isEmpty);
    });
  });
}
