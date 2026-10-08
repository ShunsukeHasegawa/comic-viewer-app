import 'package:flutter/foundation.dart';

import '../data/archive_transport.dart';
import '../domain/archive_task_id.dart';
import '../domain/volume_download.dart';
import 'download_queue_memory.dart';
import 'reconcile_planner.dart';
import 'transfer_cleanup.dart';

/// 起動時の照合の実行（OS 側の転送と台帳の突き合わせ）（#32）。
///
/// 巻ごとの判断は [reconcileActionFor] の表（reconcile_planner.dart）に任せ、
/// ここではそれに従って「今の転送」を登録し、要らない転送を捨て、確定 /
/// 再開 / 再試行 / 投入を調停役に頼む。
///
/// プラグインの自動再投入は使わない（古いトークンのまま、この照合と並んで
/// 積み直すので二重になる。F5）。
class StartupReconciler {
  StartupReconciler(this._memory, this._host, this._cleanup);

  final DownloadQueueMemory _memory;
  final DownloadQueueHost _host;
  final TransferCleanup _cleanup;

  /// 照合する。他のタグの転送は止めて捨てる。
  Future<void> run(List<TransferSnapshot> snapshots, int generation) async {
    final store = _host.store;
    if (store == null) return;

    // 照合の前に届いた完了を一覧に反映する（F6）。記録が消えていても、
    // 完了が届いたなら書き上がった ZIP がある（下の sweep で孤児として消さない）。
    final merged = mergeEarlyCompleted(snapshots, _memory.earlyCompleted);
    _memory.earlyCompleted.clear();
    final groups = groupForReconcile(merged, _host.sessionTag);

    final installs = <ArchiveTaskId>[];
    final resumes = <ArchiveTaskId>[];
    final failures = <ArchiveTaskId>[];
    final discards = <(TransferSnapshot, ArchiveTaskId?)>[];
    for (final MapEntry(key: volumeId, value: candidates)
        in groups.byVolume.entries) {
      final (:chosen, :duplicates) = pickReconcileCandidate(
        candidates,
        _memory.tasks[volumeId],
      );
      for (final (task, snapshot) in duplicates) {
        discards.add((snapshot, task));
      }
      final (task, snapshot) = chosen;
      // 台帳は巻ごとに読み直す（照合の await の間に中断 / 削除されうる）。
      final download = _host.ledger?[volumeId];

      switch (reconcileActionFor(task, snapshot.state, download)) {
        case ReconcileAction.discard:
          discards.add((snapshot, task));
        case ReconcileAction.keepPaused:
          _memory.tasks[volumeId] = task;
        case ReconcileAction.watch:
          _memory.tasks[volumeId] = task;
          _memory.liveTasks.add(volumeId);
          _memory.reservations.reserveRemaining(
            volumeId,
            total: download!.totalBytes,
            received: download.receivedBytes,
          );
          if (snapshot.state == TransferState.running) {
            _memory.runningTasks.add(volumeId);
            _memory.hadProgress.add(volumeId);
            await _host.save(
              download.copyWith(status: VolumeDownloadStatus.downloading),
            );
          }
        case ReconcileAction.install:
          _memory.tasks[volumeId] = task;
          installs.add(task);
        case ReconcileAction.resume:
          _memory.tasks[volumeId] = task;
          resumes.add(task);
        case ReconcileAction.retryFailure:
          _memory.tasks[volumeId] = task;
          _memory.attempts.reset(volumeId);
          failures.add(task);
        case ReconcileAction.canceledByUser:
          // アプリが死んでいる間に通知の Cancel ボタンで止められた。
          discards.add((snapshot, task));
          await _host.savePaused(download!);
      }
      if (_host.isStale(generation)) return;
    }

    // 自分の転送を登録してから捨てる（同じ巻・同じ世代の書き込み先を、
    // 別セッションの転送の後始末で消さないため）。
    for (final (snapshot, task) in discards) {
      await _discardSnapshot(snapshot, task);
    }
    for (final (snapshot, task) in groups.foreign) {
      await _discardSnapshot(snapshot, task, foreign: true);
    }
    if (_host.isStale(generation)) return;

    await store.sweep(
      ledger: _host.ledger ?? const {},
      liveStagingPaths: {
        for (final MapEntry(key: volumeId, value: task)
            in _memory.tasks.entries)
          store
              .stagingFile(volumeId: volumeId, filesVersion: task.filesVersion)
              .path,
      },
    );
    if (_host.isStale(generation)) return;
    // 失敗で置き去りになったパッケージの一時ファイル（F9）。積み直しを
    // 始める前に消す（走っている転送があれば古いものだけ）。投入は照合が
    // 終わる（ready）まで待つので、ここでは投入と並ばない。
    await _cleanup.sweepTempFiles(staleOnly: _memory.liveTasks.isNotEmpty);
    if (_host.isStale(generation)) return;

    for (final task in installs) {
      _host.scheduleInstall(task);
    }
    for (final task in resumes) {
      _host.track(_host.resumeOrSubmit(task, generation: generation));
    }
    for (final task in failures) {
      _host.track(
        _host.applyFailure(
          task,
          const TransferFailure(kind: TransferFailureKind.other),
          generation: generation,
        ),
      );
    }
    for (final download in _host.ledger?.values ?? const <VolumeDownload>[]) {
      if (download.isActive && !_memory.tasks.containsKey(download.volumeId)) {
        _host.scheduleSubmit(download.volumeId);
      }
    }
  }

  Future<void> _discardSnapshot(
    TransferSnapshot snapshot,
    ArchiveTaskId? task, {
    bool foreign = false,
  }) async {
    if (isAliveForDiscard(snapshot.state)) {
      _memory.cancelling.add(snapshot.taskId);
      try {
        await _host.transport?.cancel(snapshot.taskId);
      } on Object catch (error) {
        debugPrint('[downloads] cancel failed: $error');
      }
    }
    if (task != null) await _cleanup.deleteStagingUnlessCurrent(task);
    if (foreign) {
      // ログアウトの直後に落ちて、取り消しの書き戻しが残った記録など（#15）。
      await _cleanup.forgetForeignQuietly(snapshot.taskId);
    } else {
      await _cleanup.forgetQuietly(snapshot.taskId);
    }
  }
}
