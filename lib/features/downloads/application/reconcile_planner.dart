import 'package:flutter/foundation.dart' show immutable;

import '../data/archive_transport.dart';
import '../domain/archive_task_id.dart';
import '../domain/volume_download.dart';

// 起動時の照合（OS 側の転送と台帳の突き合わせ）のうち、状態を持たない判断。
//
// DownloadQueue から切り出した（#29）。台帳や転送を実際に書き換えるのは
// キューの側で、ここは「どの転送をどう扱うか」だけを決める。台帳の行は巻ごとに
// その時点の値を渡す（照合の await の間にユーザーが中断 / 削除しうるので、
// 最初にまとめて読んだ値で全部を決めない）。

/// 照合で 1 巻の転送をどう扱うか。
enum ReconcileAction {
  /// 止めて捨てる（台帳に無い / 中断・失敗・完了の巻の不要な転送 /
  /// プロセスごと殺されて消えた転送）。
  discard,

  /// 今の転送として登録だけする（ユーザーが止めた転送・中断した「更新あり」の
  /// 取り直しの再開データ。「再開」で続きから取る）。
  keepPaused,

  /// 待機 / 走行中。そのまま見守る。
  watch,

  /// 書き上がっている。確定する。
  install,

  /// 一時停止している（ユーザーは止めていない）。再開し、だめなら積み直す。
  resume,

  /// 失敗している。失敗として解釈する（回数は数え直す）。
  retryFailure,

  /// アプリが死んでいる間に通知の Cancel ボタンで止められた。転送は捨て、
  /// 台帳は中断にする。
  canceledByUser,
}

/// 照合する転送を、自分のセッションの巻ごとの候補と、他のセッション
/// （または壊れた ID）のものに分けたもの。
@immutable
class ReconcileGroups {
  const ReconcileGroups({required this.byVolume, required this.foreign});

  /// 巻ごとの候補（一覧に出てきた順）。
  final Map<int, List<(ArchiveTaskId, TransferSnapshot)>> byVolume;

  /// 他のセッションの転送 / 壊れた ID（止めて捨てる）。
  final List<(TransferSnapshot, ArchiveTaskId?)> foreign;
}

/// 照合の前に届いた完了（[earlyCompleted]）を一覧に反映する（F6）。
///
/// 記録が消えていても、完了が届いたなら書き上がった ZIP がある。照合が
/// それを孤児として掃除しないよう、完了として一覧に載せる。
List<TransferSnapshot> mergeEarlyCompleted(
  List<TransferSnapshot> snapshots,
  Set<String> earlyCompleted,
) {
  final early = {...earlyCompleted};
  return [
    for (final snapshot in snapshots)
      if (early.remove(snapshot.taskId))
        TransferSnapshot(
          taskId: snapshot.taskId,
          state: TransferState.completed,
        )
      else
        snapshot,
    for (final taskId in early)
      TransferSnapshot(taskId: taskId, state: TransferState.completed),
  ];
}

/// 一覧を巻ごとに分ける。
///
/// [sessionTag] が `null`（破棄の途中）なら、すべて他のセッションのものとして
/// 扱う（#15）。
ReconcileGroups groupForReconcile(
  List<TransferSnapshot> snapshots,
  String? sessionTag,
) {
  final foreign = <(TransferSnapshot, ArchiveTaskId?)>[];
  final byVolume = <int, List<(ArchiveTaskId, TransferSnapshot)>>{};
  for (final snapshot in snapshots) {
    final task = ArchiveTaskId.tryParse(snapshot.taskId);
    if (task == null || sessionTag == null || task.sessionTag != sessionTag) {
      foreign.add((snapshot, task));
      continue;
    }
    (byVolume[task.volumeId] ??= []).add((task, snapshot));
  }
  return ReconcileGroups(byVolume: byVolume, foreign: foreign);
}

/// 同じ巻に残った転送から 1 つを選ぶ。残りは捨てる側（`duplicates`）。
///
/// 世代違いが残っていたら新しい世代だけを見る。同じ世代の別の投入（ID の
/// ノンス違い）が残っていたら、今の転送（[current]）→ 書き上がったもの →
/// 生きているもの → 続きを取れるもの、の順に選ぶ（二重に落とさない）。
({
  (ArchiveTaskId, TransferSnapshot) chosen,
  List<(ArchiveTaskId, TransferSnapshot)> duplicates,
})
pickReconcileCandidate(
  List<(ArchiveTaskId, TransferSnapshot)> candidates,
  ArchiveTaskId? current,
) {
  final sorted = [...candidates]
    ..sort((a, b) {
      final byVersion = b.$1.filesVersion.compareTo(a.$1.filesVersion);
      if (byVersion != 0) return byVersion;
      final byCurrent = (b.$1 == current ? 1 : 0).compareTo(
        a.$1 == current ? 1 : 0,
      );
      if (byCurrent != 0) return byCurrent;
      return _reconcileRank(a.$2.state).compareTo(_reconcileRank(b.$2.state));
    });
  return (chosen: sorted.first, duplicates: sorted.skip(1).toList());
}

/// 選んだ転送をどう扱うかを、台帳の行（[download]）から決める。
///
/// | 台帳 | 自分のタグの転送 | 処理 |
/// | --- | --- | --- |
/// | 待機 / 取得中 | 待機 / 走行中 | そのまま見守る |
/// | 待機 / 取得中 | 完了 | 確定する |
/// | 待機 / 取得中 | 一時停止 | 再開。だめなら積み直す |
/// | 待機 / 取得中 | 失敗 | 失敗として解釈する（回数は数え直す） |
/// | 待機 / 取得中 | 取り消し | 通知の Cancel。中断にする |
/// | 待機 / 取得中 | 無し / 消えた | 積み直す（新しいトークンで） |
/// | 中断 / 失敗 | 一時停止 | 再開データとして残す |
/// | 完了（旧世代）| 新世代の一時停止 / 完了 | 残す / 確定する |
/// | 中断 / 失敗 / 完了 | それ以外 | 止めて捨てる |
/// | 無し | 何か | 止めて捨てる |
ReconcileAction reconcileActionFor(
  ArchiveTaskId task,
  TransferState transferState,
  VolumeDownload? download,
) {
  if (download == null) return ReconcileAction.discard;
  if (download.isCompleted) {
    // 中断した「更新あり」の取り直し（台帳は旧世代の完了に戻してある）。
    // 再開データは「更新あり」から続きを取るために残し、止める前に
    // 書き上がっていたものは確定する（数百 MB を落とし直させない）。
    final isPausedRefetch = task.filesVersion > download.filesVersion;
    if (isPausedRefetch && transferState == TransferState.paused) {
      return ReconcileAction.keepPaused;
    }
    if (isPausedRefetch && transferState == TransferState.completed) {
      return ReconcileAction.install;
    }
    return ReconcileAction.discard;
  }
  if (!download.isActive) {
    // ユーザーが止めた転送の再開データは残す（「再開」で続きから取る）。
    return transferState == TransferState.paused
        ? ReconcileAction.keepPaused
        : ReconcileAction.discard;
  }
  return switch (transferState) {
    TransferState.enqueued ||
    TransferState.running ||
    TransferState.waitingToRetry => ReconcileAction.watch,
    TransferState.completed => ReconcileAction.install,
    TransferState.paused => ReconcileAction.resume,
    TransferState.failed => ReconcileAction.retryFailure,
    TransferState.canceled => ReconcileAction.canceledByUser,
    // プロセスごと殺されて消えた（holding queue の中身はメモリにしか無い）。
    // 照合の最後に新しいトークンで積み直す。
    TransferState.notFound => ReconcileAction.discard,
  };
}

/// 捨てる転送のうち、まだ動いている（取り消しを送る）もの。
bool isAliveForDiscard(TransferState state) =>
    state == TransferState.enqueued ||
    state == TransferState.running ||
    state == TransferState.waitingToRetry ||
    state == TransferState.paused;

/// 照合で同じ巻・同じ世代の転送が複数あるときの優先順（小さいほど優先）。
int _reconcileRank(TransferState state) => switch (state) {
  TransferState.completed => 0,
  TransferState.running => 1,
  TransferState.enqueued || TransferState.waitingToRetry => 2,
  TransferState.paused => 3,
  TransferState.failed => 4,
  TransferState.canceled || TransferState.notFound => 5,
};
