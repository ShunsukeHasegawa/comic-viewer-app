import 'dart:async';

import 'package:flutter/foundation.dart';

/// 前のセッションのタスクの記録を、後から書き戻されても消し直す（#15）。
///
/// パッケージはタスクの状態が変わるたびに、タスクの JSON（ヘッダーの
/// `Authorization: Bearer ...` を含む）を記録に書く。この書き込みは
/// 状態の通知より先に**非同期のキューに積まれるだけ**で、いつ終わるかは
/// 分からない（`base_downloader.dart` の `_updateTaskInDatabase`）。
/// ログアウトで記録を消しても、取り消した転送の canceled が後から届くと
/// 記録ごと書き戻され、ログアウトしたユーザーのトークンが端末に残る。
///
/// そこで「二度と使わない ID」（セッションタグが古いもの）だけを覚えておき、
/// 少し待って消す → もう一度確かめる、を記録が無くなるまで繰り返す。
/// 今のセッションの ID は同じ ID で積み直すことがあるので扱わない
/// （新しい転送の記録や再開データまで消してしまう）。
class TaskRecordScrubber {
  TaskRecordScrubber({
    required this.erase,
    required this.exists,
    this.delay = const Duration(milliseconds: 500),
    this.maxRounds = 6,
  });

  /// 記録・再開データ・一時停止中のタスクを消す。
  final Future<void> Function(String taskId) erase;

  /// 記録がまだあるか。
  final Future<bool> Function(String taskId) exists;

  /// 書き戻しが落ち着くまで待つ時間。
  final Duration delay;

  /// 1 回の掃除で消し直す上限（書き戻しが続いても無限に回さない）。
  final int maxRounds;

  final _purged = <String>{};
  final _chains = <String, Future<void>>{};

  /// 消すと決めた ID か。
  bool isPurged(String taskId) => _purged.contains(taskId);

  /// [taskIds] を「二度と使わない」として覚え、消し直しを予約する。
  void purge(Iterable<String> taskIds) {
    for (final taskId in taskIds) {
      _purged.add(taskId);
      _schedule(taskId);
    }
  }

  /// パッケージから更新が届いた。消すと決めた ID なら、その更新が書き戻す
  /// 記録を消し直す（更新はキューに積まれた書き込みより後に届く）。
  void onUpdate(String taskId) {
    if (_purged.contains(taskId)) _schedule(taskId);
  }

  /// 予約した消し直しがすべて終わるまで待つ（テスト用）。
  @visibleForTesting
  Future<void> get idle async {
    while (_chains.isNotEmpty) {
      await Future.wait(_chains.values.toList());
    }
  }

  void _schedule(String taskId) {
    // 同じ ID の掃除は 1 本ずつ流す（並べても結果は同じで、回数だけ増える）。
    final previous = _chains[taskId] ?? Future<void>.value();
    late final Future<void> next;
    next = previous.then((_) => _scrub(taskId)).whenComplete(() {
      if (identical(_chains[taskId], next)) _chains.remove(taskId);
    });
    _chains[taskId] = next;
  }

  Future<void> _scrub(String taskId) async {
    for (var round = 0; round < maxRounds; round++) {
      await Future<void>.delayed(delay);
      try {
        await erase(taskId);
        await Future<void>.delayed(delay);
        if (!await exists(taskId)) return;
      } on Object catch (error) {
        debugPrint('[transfer] scrub $taskId failed: $error');
      }
    }
  }
}
