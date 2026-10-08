import 'dart:async';
import 'dart:io';

import 'package:comic_laz/features/downloads/application/download_queue_memory.dart';
import 'package:comic_laz/features/downloads/application/transfer_cleanup.dart';
import 'package:comic_laz/features/downloads/application/transfer_event_reducer.dart';
import 'package:comic_laz/features/downloads/data/archive_transport.dart';
import 'package:comic_laz/features/downloads/data/download_store.dart';
import 'package:comic_laz/features/downloads/domain/archive_task_id.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../support/cache_fakes.dart';
import '../../support/download_fakes.dart';

const _tag = 'SESSION';

ArchiveTaskId _task(int volumeId, {int filesVersion = 100, String? tag}) =>
    ArchiveTaskId(
      volumeId: volumeId,
      filesVersion: filesVersion,
      sessionTag: tag ?? _tag,
      nonce: 'n$volumeId$filesVersion',
    );

VolumeDownload _active(int volumeId) => VolumeDownload(
  volumeId: volumeId,
  bookId: 1,
  filesVersion: 0,
  status: VolumeDownloadStatus.queued,
  totalBytes: 1000,
);

/// 部品の単体テスト用の調停役。台帳と頼まれたことを記録するだけ。
class _FakeHost implements DownloadQueueHost {
  _FakeHost({required this.store, required this.transport});

  @override
  final DownloadStore store;

  @override
  final FakeArchiveTransport transport;

  @override
  Ref get ref => throw UnimplementedError();

  @override
  bool mounted = true;

  @override
  int generation = 1;

  @override
  Completer<void> ready = Completer<void>();

  @override
  String? sessionTag = _tag;

  @override
  final Map<int, VolumeDownload> ledger = {};

  final tracked = <Future<void>>[];
  final installs = <ArchiveTaskId>[];
  final submits = <int>[];

  @override
  bool isStale(int generation) => generation != this.generation || !mounted;

  @override
  bool isCurrent(ArchiveTaskId task) => false;

  @override
  void track(Future<void> work) => tracked.add(work);

  /// 追跡中の処理が落ち着くまで待つ。
  Future<void> settle() async {
    while (tracked.isNotEmpty) {
      final batch = [...tracked];
      tracked.clear();
      await Future.wait(batch);
    }
  }

  @override
  void emit(VolumeDownload? download) {
    if (download != null) ledger[download.volumeId] = download;
  }

  @override
  Future<void> save(VolumeDownload download) async => emit(download);

  @override
  Future<void> savePaused(VolumeDownload current) =>
      save(current.copyWith(status: VolumeDownloadStatus.paused));

  @override
  Future<void> fail(
    int volumeId,
    String reason, {
    required int generation,
    bool resetProgress = false,
  }) async {}

  @override
  void scheduleSubmit(int volumeId) => submits.add(volumeId);

  @override
  void scheduleInstall(ArchiveTaskId task) => installs.add(task);

  @override
  Future<void> resumeOrSubmit(
    ArchiveTaskId task, {
    required int generation,
  }) async {}

  @override
  Future<void> applyFailure(
    ArchiveTaskId task,
    TransferFailure failure, {
    required int generation,
  }) async {}
}

void main() {
  group('DownloadQueueMemory', () {
    test('転送を手放しても試行回数と取り直しの戻り先は残す（積み直しをまたいで上限を数え、'
        '失敗したら旧世代へ戻すため）', () {
      final memory = DownloadQueueMemory();
      final task = _task(1);
      memory.tasks[1] = task;
      memory.liveTasks.add(1);
      memory.runningTasks.add(1);
      memory.hadProgress.add(1);
      memory.awaitingInstall.add(1);
      memory.installing.add(1);
      memory.resumeRequested.add(1);
      memory.pausedSeen.add(1);
      memory.resumeOnPaused.add(1);
      memory.pausedEventPending.add(1);
      memory.reservations.reserve(1, 500);
      memory.attempts.count(1);
      memory.installed[1] = _active(1);
      memory.pausing.add(1);
      memory.submitting.add(1);
      memory.cancelling.add(task.toString());

      memory.clearTask(1);

      expect(memory.tasks, isEmpty);
      expect(memory.liveTasks, isEmpty);
      expect(memory.runningTasks, isEmpty);
      expect(memory.hadProgress, isEmpty);
      expect(memory.awaitingInstall, isEmpty);
      expect(memory.installing, isEmpty);
      expect(memory.resumeRequested, isEmpty);
      expect(memory.pausedSeen, isEmpty);
      expect(memory.resumeOnPaused, isEmpty);
      expect(memory.pausedEventPending, isEmpty);
      expect(memory.reservations.reservedByOthers(2, isActive: (_) => true), 0);
      // 残すもの。
      expect(memory.attempts.current(1), 1);
      expect(memory.installed, contains(1));
      // 中断 / 投入の処理中の印は、処理している側が自分で外す。
      expect(memory.pausing, contains(1));
      expect(memory.submitting, contains(1));
      // 自分で取り消した印は、届いた canceled を見分けるまで残す。
      expect(memory.cancelling, contains(task.toString()));
    });

    test('reset は鎖も作り直す（前のセッションの処理の後ろに次の投入を並ばせない）', () async {
      final memory = DownloadQueueMemory();
      final blocker = Completer<void>();
      memory.submitChain = blocker.future;
      memory.eventChain = blocker.future;
      memory.installChain = blocker.future;
      memory.tempSweepQueued = true;
      memory.tasks[1] = _task(1);
      memory.earlyCompleted.add('x');

      memory.reset();

      expect(memory.tasks, isEmpty);
      expect(memory.earlyCompleted, isEmpty);
      expect(memory.tempSweepQueued, isFalse);
      // 止まったままの鎖を引き継いでいなければ、すぐ終わる。
      await memory.submitChain.timeout(const Duration(seconds: 1));
      await memory.eventChain.timeout(const Duration(seconds: 1));
      await memory.installChain.timeout(const Duration(seconds: 1));
    });
  });

  group('TransferCleanup', () {
    late CacheHarness cache;
    late DownloadStore store;
    late FakeArchiveTransport transport;
    late DownloadQueueMemory memory;
    late _FakeHost host;
    late TransferCleanup cleanup;

    setUp(() {
      cache = CacheHarness.create();
      store = DownloadStore(
        database: cache.database,
        directories: cache.directories,
        now: cache.clock.now,
      );
      transport = FakeArchiveTransport();
      memory = DownloadQueueMemory();
      host = _FakeHost(store: store, transport: transport);
      cleanup = TransferCleanup(memory, host);
    });

    File staging(ArchiveTaskId task) {
      final file = store.stagingFile(
        volumeId: task.volumeId,
        filesVersion: task.filesVersion,
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('x');
      return file;
    }

    test('同じ巻・同じ世代の今の転送が書いている一時ファイルは消さない'
        '（別の転送の後始末で、走っている転送の書きかけを壊さないため）', () async {
      final current = _task(1);
      final old = ArchiveTaskId(
        volumeId: 1,
        filesVersion: 100,
        sessionTag: 'OLD',
        nonce: 'old',
      );
      memory.tasks[1] = current;
      final file = staging(current);

      await cleanup.deleteStagingUnlessCurrent(old);
      expect(file.existsSync(), isTrue);

      // 世代が違えば書き込み先も違うので、古い方の書きかけは消してよい。
      final previous = _task(1, filesVersion: 50);
      final previousFile = staging(previous);
      await cleanup.deleteStagingUnlessCurrent(previous);
      expect(previousFile.existsSync(), isFalse);
      expect(file.existsSync(), isTrue);
    });

    test('取り消しは自分の印を付けてから送り、書きかけと記録も捨てる'
        '（届いた canceled を通知の Cancel ボタンと取り違えないため）', () async {
      final task = _task(1);
      memory.tasks[1] = task;
      memory.liveTasks.add(1);
      final file = staging(task);

      await cleanup.cancelTask(task);

      expect(memory.cancelling, contains(task.toString()));
      expect(memory.tasks, isEmpty);
      expect(memory.liveTasks, isEmpty);
      expect(transport.canceled, [task.toString()]);
      expect(transport.forgotten, [task.toString()]);
      expect(file.existsSync(), isFalse);
    });

    test('今の転送でない取り消しは、今の転送を手放さない'
        '（世代の変わった旧転送の取り消しで、新しい転送の印を消さないため）', () async {
      final current = _task(1, filesVersion: 200);
      memory.tasks[1] = current;
      memory.liveTasks.add(1);

      await cleanup.cancelTask(_task(1));

      expect(memory.tasks[1], current);
      expect(memory.liveTasks, contains(1));
    });

    test('一時ファイルの掃除は重ねて載せず、照合が終わるまで始めない'
        '（照合の前は生きている転送が分からず、書きかけを消しうるため）', () async {
      cleanup
        ..scheduleTempSweep()
        ..scheduleTempSweep();
      await Future<void>.delayed(Duration.zero);
      expect(transport.tempSweeps, 0);

      memory.liveTasks.add(1);
      host.ready.complete();
      await host.settle();

      // 生きている転送があるので、しばらく書き込まれていないものだけを消す。
      expect(transport.tempSweepModes, [true]);
    });

    test('ログアウトなどで世代が変わったら、載せていた掃除は走らせない', () async {
      cleanup.scheduleTempSweep();
      host.generation++;
      host.ready.complete();
      await host.settle();

      expect(transport.tempSweeps, 0);
    });
  });

  group('TransferEventReducer', () {
    late CacheHarness cache;
    late DownloadStore store;
    late FakeArchiveTransport transport;
    late DownloadQueueMemory memory;
    late _FakeHost host;
    late TransferEventReducer reducer;

    setUp(() {
      cache = CacheHarness.create();
      store = DownloadStore(
        database: cache.database,
        directories: cache.directories,
        now: cache.clock.now,
      );
      transport = FakeArchiveTransport();
      memory = DownloadQueueMemory();
      host = _FakeHost(store: store, transport: transport);
      reducer = TransferEventReducer(
        memory,
        host,
        TransferCleanup(memory, host),
      );
    });

    test('照合の前に届いた完了は控えるだけで、照合が終わるまで確定に回さない'
        '（照合の前は今の転送が分からず、古い世代を確定しかねないため）', () async {
      final task = _task(1);
      reducer.onEvent(
        TransferStateChanged(task.toString(), TransferState.completed),
      );
      await Future<void>.delayed(Duration.zero);

      expect(memory.earlyCompleted, {task.toString()});
      expect(host.installs, isEmpty);

      memory.tasks[1] = task;
      host.ready.complete();
      await host.settle();

      expect(host.installs, [task]);
    });

    test('今の転送の進捗は走っている印と残りの予約に反映し、古い転送の進捗は無視する', () async {
      final task = _task(1);
      memory.tasks[1] = task;
      host.ledger[1] = _active(1);
      host.ready.complete();

      reducer
        ..onEvent(
          TransferProgressed(task.toString(), received: 300, total: 1000),
        )
        ..onEvent(
          TransferProgressed(
            _task(1, filesVersion: 50).toString(),
            received: 900,
            total: 1000,
          ),
        );
      await host.settle();

      expect(host.ledger[1]!.receivedBytes, 300);
      expect(host.ledger[1]!.status, VolumeDownloadStatus.downloading);
      expect(memory.runningTasks, contains(1));
      expect(memory.hadProgress, contains(1));
      expect(
        memory.reservations.reservedByOthers(2, isActive: (_) => true),
        700,
      );
    });

    test('前のセッションの走っている転送は 1 回だけ取り消す'
        '（進捗が届くたびに取り消しを送り直さないため）', () async {
      final foreign = _task(1, tag: 'OLD').toString();
      host.ready.complete();

      reducer
        ..onEvent(TransferProgressed(foreign, received: 1, total: 10))
        ..onEvent(TransferProgressed(foreign, received: 2, total: 10));
      await host.settle();

      expect(transport.canceled, [foreign]);
      expect(host.ledger, isEmpty);
    });
  });
}
