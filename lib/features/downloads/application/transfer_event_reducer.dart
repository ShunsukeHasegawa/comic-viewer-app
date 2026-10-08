import 'package:flutter/foundation.dart';

import '../data/archive_transport.dart';
import '../domain/archive_task_id.dart';
import '../domain/volume_download.dart';
import 'download_progress_book.dart';
import 'download_queue_memory.dart';
import 'transfer_cleanup.dart';

/// OS の転送から届いたイベント（状態 / 進捗）を、届いた順に 1 つずつ
/// 台帳とメモリの印へ反映する（#32）。
///
/// 照合（`ready`）が終わるまでは処理を待たせる。照合の前は「今の転送」が
/// 分からないので、届いた完了を自分のものと判断できない（取りこぼすか、
/// 古い世代を確定してしまう）。確定・再試行・積み直しは自分では行わず、
/// [DownloadQueueHost] を通して調停役に頼む。
class TransferEventReducer {
  TransferEventReducer(this._memory, this._host, this._cleanup);

  final DownloadQueueMemory _memory;
  final DownloadQueueHost _host;
  final TransferCleanup _cleanup;

  /// 転送のイベントを受け取る（`ArchiveTransport.events` の購読先）。
  void onEvent(TransferEvent event) {
    final ready = _host.ready;
    final generation = _host.generation;
    if (!ready.isCompleted &&
        event is TransferStateChanged &&
        event.state == TransferState.completed) {
      // 照合の前に届いた完了。照合の一覧に載っていなくても書き上がった ZIP が
      // あるので、照合に教えて孤児として掃除させない（F6）。
      _memory.earlyCompleted.add(event.taskId);
    }
    final link = _memory.eventChain.then((_) async {
      await ready.future;
      if (_host.isStale(generation)) return;
      await _handleEvent(event, generation);
    });
    _memory.eventChain = link.catchError((Object _) {});
    _host.track(link);
  }

  Future<void> _handleEvent(TransferEvent event, int generation) async {
    final task = ArchiveTaskId.tryParse(event.taskId);
    final tag = _host.sessionTag;
    if (task == null || tag == null || task.sessionTag != tag) {
      // 前のセッション（ログアウト前）の転送、または壊れた ID。取り込まない。
      await _discardForeign(event, task);
      return;
    }
    final isCurrent = _memory.tasks[task.volumeId] == task;
    switch (event) {
      case TransferProgressed(:final received, :final total):
        if (isCurrent) _onProgress(task.volumeId, received, total);
      case TransferStateChanged(:final state, :final failure):
        await _onStateChanged(
          task,
          state,
          failure,
          isCurrent: isCurrent,
          generation: generation,
        );
    }
  }

  Future<void> _onStateChanged(
    ArchiveTaskId task,
    TransferState transferState,
    TransferFailure? failure, {
    required bool isCurrent,
    required int generation,
  }) async {
    final volumeId = task.volumeId;
    final download = _host.ledger?[volumeId];
    switch (transferState) {
      case TransferState.enqueued || TransferState.waitingToRetry:
        if (!isCurrent) return;
        _memory.liveTasks.add(volumeId);
        _memory.runningTasks.remove(volumeId);
        // 「待機中」。Wi-Fi 待ちかどうかの表示は DownloadGate が出す。
        if (download != null &&
            download.isActive &&
            download.status != VolumeDownloadStatus.queued) {
          await _host.save(
            download.copyWith(status: VolumeDownloadStatus.queued),
          );
        }
      case TransferState.running:
        if (!isCurrent) return;
        _memory.liveTasks.add(volumeId);
        _memory.runningTasks.add(volumeId);
        _memory.hadProgress.add(volumeId);
        if (download != null &&
            download.isActive &&
            download.status != VolumeDownloadStatus.downloading) {
          await _host.save(
            download.copyWith(status: VolumeDownloadStatus.downloading),
          );
        }
      case TransferState.paused:
        // F1: 台帳が「中断」ならユーザーが止めたもの（既に書いてある）。
        // 台帳が待機中 / 取得中のままなら、9 分の時間切れや Wi-Fi 設定の
        // 反映による一時的な停止で、ネイティブがすぐ再投入する。どちらも
        // 台帳は変えない（「中断中」にすると、勝手に止まったように見える）。
        if (!isCurrent) return;
        // 時間切れの再投入が走り出すまでは走っていない（F11）。ただし
        // 再開データはネイティブにあるので、中断は印に任せる（hadProgress）。
        _memory.runningTasks.remove(volumeId);
        _memory.hadProgress.add(volumeId);
        _memory.pausedEventPending.remove(volumeId);
        if (_memory.pausing.contains(volumeId)) {
          _memory.pausedSeen.add(volumeId);
        }
        if (_memory.resumeOnPaused.remove(volumeId)) {
          // F3: 止め終わる前に「再開」が押されていた。再開データが揃ったので
          // 続きを取る。
          if (download != null && download.isActive) {
            _host.track(_host.resumeOrSubmit(task, generation: generation));
          }
          return;
        }
        if (!(download?.isActive ?? false)) _memory.liveTasks.remove(volumeId);
      case TransferState.canceled:
        final expected = _memory.cancelling.remove(task.toString());
        if (isCurrent && !expected && download != null && download.isActive) {
          // 通知の Cancel ボタン（Dart を経由しない取り消し）。ユーザーが
          // 止めたので中断として扱う。取り直しなら旧世代へ戻し、完了済みの
          // ZIP と台帳は消さない（削除は画面の操作だけにする）。
          _memory.clearTask(volumeId);
          await _host.savePaused(download);
          await _cleanup.deleteStaging(task);
          await _cleanup.forgetQuietly(task);
          return;
        }
        // 自分で取り消したもの。まだ今の転送なら（isCurrent）触らない。
        if (isCurrent && !expected) _memory.clearTask(volumeId);
        if (isCurrent && expected) return;
        await _cleanup.deleteStagingUnlessCurrent(task);
        await _cleanup.forgetQuietly(task);
      case TransferState.failed || TransferState.notFound:
        if (!isCurrent) {
          await _cleanup.deleteStagingUnlessCurrent(task);
          await _cleanup.forgetQuietly(task);
          return;
        }
        _memory.liveTasks.remove(volumeId);
        _memory.runningTasks.remove(volumeId);
        // 失敗でパッケージは再開データを捨てている（積み直しは先頭から）。
        _memory.hadProgress.remove(volumeId);
        if (download == null || !download.isActive) {
          _memory.clearTask(volumeId);
          await _cleanup.forgetQuietly(task);
          return;
        }
        // 再試行の待ち時間でイベントの処理（次の巻の進捗など）を止めない。
        _host.track(
          _host.applyFailure(
            task,
            failure ?? const TransferFailure(kind: TransferFailureKind.other),
            generation: generation,
          ),
        );
      case TransferState.completed:
        if (isCurrent) {
          _memory.liveTasks.remove(volumeId);
          _memory.runningTasks.remove(volumeId);
          _memory.hadProgress.remove(volumeId);
        }
        _host.scheduleInstall(task);
    }
  }

  /// 他のセッションの転送（または壊れた ID）を片付ける。
  Future<void> _discardForeign(TransferEvent event, ArchiveTaskId? task) async {
    final terminal =
        event is TransferStateChanged &&
        (event.state == TransferState.completed ||
            event.state == TransferState.failed ||
            event.state == TransferState.canceled ||
            event.state == TransferState.notFound);
    if (!terminal) {
      // まだ動いている。止める（止まったら canceled で戻ってくる）。
      if (_memory.cancelling.add(event.taskId)) {
        try {
          await _host.transport?.cancel(event.taskId);
        } on Object catch (error) {
          debugPrint('[downloads] cancel foreign failed: $error');
        }
      }
      return;
    }
    _memory.cancelling.remove(event.taskId);
    if (task != null) await _cleanup.deleteStagingUnlessCurrent(task);
    // 記録には前のユーザーの Bearer が入っている。パッケージはこの更新の
    // 書き込みを非同期に積んでから通知してくるので、消した後に書き戻される
    // ことがある。書き戻されても消し直す方で捨てる（#15）。
    await _cleanup.forgetForeignQuietly(event.taskId);
  }

  void _onProgress(int volumeId, int received, int? total) {
    final current = _host.ledger?[volumeId];
    if (current == null || !current.isActive) return;
    final next = applyProgress(current, received, total);
    final totalBytes = next.totalBytes;
    _host.emit(next);
    // 進捗が届く = 走っている（`running` を取りこぼしても一時停止できる）。
    _memory.liveTasks.add(volumeId);
    _memory.runningTasks.add(volumeId);
    _memory.hadProgress.add(volumeId);
    if (totalBytes > 0) {
      _memory.reservations.reserveRemaining(
        volumeId,
        total: totalBytes,
        received: received,
      );
    }

    if (!_memory.persistThrottle.shouldPersist(volumeId, received)) return;
    final store = _host.store;
    if (store != null) _host.track(store.save(next));
  }
}
