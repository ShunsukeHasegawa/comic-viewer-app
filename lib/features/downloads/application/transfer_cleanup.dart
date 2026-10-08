import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/archive_task_id.dart';
import 'download_queue_memory.dart';

/// 転送の取り消しと、書きかけ / 転送の記録 / 一時ファイルの後始末（#32）。
///
/// 消してよいかの判断（今の転送と同じ書き込み先なら消さない）もここに置く。
/// 完了済みの ZIP（本番のファイル名）には触らない。巻ごと消すのは
/// `DownloadQueue.remove` / `purgeAll` だけ。
class TransferCleanup {
  TransferCleanup(this._memory, this._host);

  final DownloadQueueMemory _memory;
  final DownloadQueueHost _host;

  /// 転送を取り消し、書きかけと記録も捨てる。
  Future<void> cancelTask(ArchiveTaskId task) async {
    if (_memory.tasks[task.volumeId] == task) {
      _memory.clearTask(task.volumeId);
    }
    _memory.cancelling.add(task.toString());
    try {
      await _host.transport?.cancel(task.toString());
    } on Object catch (error) {
      debugPrint('[downloads] cancel failed: $error');
    }
    await deleteStagingUnlessCurrent(task);
    await forgetQuietly(task);
  }

  Future<void> forgetQuietly(Object task) async {
    try {
      await _host.transport?.forget(task.toString());
    } on Object catch (error) {
      debugPrint('[downloads] forget failed: $error');
    }
  }

  /// 前のセッションの転送の記録を、書き戻されても消し直す方で捨てる（#15）。
  Future<void> forgetForeignQuietly(String taskId) async {
    try {
      await _host.transport?.forgetForeign(taskId);
    } on Object catch (error) {
      debugPrint('[downloads] forget foreign failed: $error');
    }
  }

  /// 置き去りの一時ファイルを消す（F9）。
  ///
  /// 投入と同じ鎖に載せる。転送側は「ネイティブの一覧を見る → 消す」の間に
  /// await を挟むので、並んで積まれた転送の書きかけ（同じ名前）を一覧に無い
  /// ものとして消しうる（完了時の移動が失敗する）。鎖の上では投入が走らない
  /// ので、載った時点の `liveTasks` で決めてよい: 何も生きていなければ全部、
  /// 生きていればしばらく書き込まれていないものだけを消す。まとめて積んだ
  /// 巻が走り続ける間も、失敗した巻の書きかけ（数百 MB）を溜めないため。
  /// 最後の判断は転送側（ネイティブの一覧）でもう一度する。
  void scheduleTempSweep() {
    if (!_host.mounted || _memory.tempSweepQueued) return;
    _memory.tempSweepQueued = true;
    final generation = _host.generation;
    final ready = _host.ready;
    final link = _memory.submitChain.then((_) async {
      _memory.tempSweepQueued = false;
      await ready.future;
      if (_host.isStale(generation)) return;
      await sweepTempFiles(staleOnly: _memory.liveTasks.isNotEmpty);
    });
    _memory.submitChain = link.catchError((Object _) {});
    _host.track(link);
  }

  Future<void> sweepTempFiles({required bool staleOnly}) async {
    try {
      await _host.transport?.sweepOrphanTempFiles(staleOnly: staleOnly);
    } on Object catch (error) {
      debugPrint('[downloads] temp sweep failed: $error');
    }
  }

  Future<void> deleteStaging(ArchiveTaskId task) async {
    final store = _host.store;
    if (store == null) return;
    await deleteQuietly(
      store.stagingFile(
        volumeId: task.volumeId,
        filesVersion: task.filesVersion,
      ),
    );
  }

  /// 同じ巻・同じ世代の「今の転送」が同じファイルに書いているなら消さない。
  Future<void> deleteStagingUnlessCurrent(ArchiveTaskId task) async {
    final current = _memory.tasks[task.volumeId];
    if (current != null && current.filesVersion == task.filesVersion) return;
    await deleteStaging(task);
  }

  static Future<void> deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // 消せなくても次の起動の掃除（sweep）が拾う。
    }
  }
}
