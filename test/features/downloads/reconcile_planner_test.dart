import 'package:comic_laz/features/downloads/application/reconcile_planner.dart';
import 'package:comic_laz/features/downloads/data/archive_transport.dart';
import 'package:comic_laz/features/downloads/domain/archive_task_id.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:flutter_test/flutter_test.dart';

const _tag = 'tagA';

ArchiveTaskId _task(
  int volumeId, {
  int filesVersion = 10,
  String tag = _tag,
  String nonce = 'n1',
}) => ArchiveTaskId(
  volumeId: volumeId,
  filesVersion: filesVersion,
  sessionTag: tag,
  nonce: nonce,
);

TransferSnapshot _snap(ArchiveTaskId task, TransferState state) =>
    TransferSnapshot(taskId: task.toString(), state: state);

VolumeDownload _row(VolumeDownloadStatus status, {int filesVersion = 10}) =>
    VolumeDownload(
      volumeId: 1,
      bookId: 1,
      filesVersion: filesVersion,
      status: status,
    );

void main() {
  group('mergeEarlyCompleted', () {
    test('照合の前に届いた完了は、一覧の状態が古くても完了として扱う（書き上がった ZIP を孤児にしない。F6）', () {
      final running = _task(1);
      final merged = mergeEarlyCompleted(
        [_snap(running, TransferState.running)],
        {running.toString()},
      );
      expect(merged.single.state, TransferState.completed);
    });

    test('一覧に載っていない完了も足す（記録が先に消えていても確定できるように）', () {
      final listed = _task(1);
      final missing = _task(2);
      final merged = mergeEarlyCompleted(
        [_snap(listed, TransferState.enqueued)],
        {missing.toString()},
      );
      expect(merged.map((s) => (s.taskId, s.state)), [
        (listed.toString(), TransferState.enqueued),
        (missing.toString(), TransferState.completed),
      ]);
    });

    test('渡した集合は書き換えない（呼び出し側が片付ける）', () {
      final early = {_task(1).toString()};
      mergeEarlyCompleted([_snap(_task(1), TransferState.running)], early);
      expect(early, hasLength(1));
    });
  });

  group('groupForReconcile', () {
    test('前のセッションの転送と壊れた ID は取り込まず、捨てる側へ分ける（#15）', () {
      final mine = _task(1);
      final other = _task(2, tag: 'tagB');
      final groups = groupForReconcile([
        _snap(mine, TransferState.running),
        _snap(other, TransferState.completed),
        const TransferSnapshot(taskId: 'garbage', state: TransferState.paused),
      ], _tag);
      expect(groups.byVolume.keys, [1]);
      expect(groups.foreign.map((e) => e.$2), [other, null]);
    });

    test('タグが決まっていない（破棄の途中）なら、すべて他人のものとして扱う', () {
      final groups = groupForReconcile([
        _snap(_task(1), TransferState.running),
      ], null);
      expect(groups.byVolume, isEmpty);
      expect(groups.foreign, hasLength(1));
    });

    test('同じ巻の転送はまとめる（後で 1 つだけ選ぶ）', () {
      final groups = groupForReconcile([
        _snap(_task(1, nonce: 'a'), TransferState.running),
        _snap(_task(2), TransferState.running),
        _snap(_task(1, nonce: 'b'), TransferState.paused),
      ], _tag);
      expect(groups.byVolume[1], hasLength(2));
      expect(groups.byVolume[2], hasLength(1));
    });
  });

  group('pickReconcileCandidate', () {
    (ArchiveTaskId, TransferSnapshot) entry(
      ArchiveTaskId task,
      TransferState state,
    ) => (task, _snap(task, state));

    test('世代違いが残っていたら新しい世代を選ぶ（古い世代は捨てる）', () {
      final old = entry(_task(1, filesVersion: 5), TransferState.completed);
      final fresh = entry(_task(1, filesVersion: 9), TransferState.paused);
      final (:chosen, :duplicates) = pickReconcileCandidate([old, fresh], null);
      expect(chosen.$1, fresh.$1);
      expect(duplicates.map((e) => e.$1), [old.$1]);
    });

    test('同じ世代なら「今の転送」を優先する（追っている転送を捨てない）', () {
      final current = entry(_task(1, nonce: 'cur'), TransferState.paused);
      final other = entry(_task(1, nonce: 'oth'), TransferState.completed);
      final picked = pickReconcileCandidate([other, current], current.$1);
      expect(picked.chosen.$1, current.$1);
    });

    test('同じ世代の二重投入は、書き上がったもの → 走っているもの → 待機 → 一時停止 → 失敗の順に 1 つ選ぶ', () {
      final failed = entry(_task(1, nonce: 'f'), TransferState.failed);
      final paused = entry(_task(1, nonce: 'p'), TransferState.paused);
      final waiting = entry(_task(1, nonce: 'w'), TransferState.enqueued);
      final running = entry(_task(1, nonce: 'r'), TransferState.running);
      final done = entry(_task(1, nonce: 'd'), TransferState.completed);

      expect(
        pickReconcileCandidate([
          failed,
          paused,
          waiting,
          running,
          done,
        ], null).chosen.$1,
        done.$1,
      );
      expect(
        pickReconcileCandidate([
          failed,
          paused,
          waiting,
          running,
        ], null).chosen.$1,
        running.$1,
      );
      expect(
        pickReconcileCandidate([failed, paused, waiting], null).chosen.$1,
        waiting.$1,
      );
      expect(
        pickReconcileCandidate([failed, paused], null).chosen.$1,
        paused.$1,
      );
    });

    test('渡した一覧の順番は変えない', () {
      final a = entry(_task(1, filesVersion: 1), TransferState.running);
      final b = entry(_task(1, filesVersion: 2), TransferState.running);
      final list = [a, b];
      pickReconcileCandidate(list, null);
      expect(list, [a, b]);
    });
  });

  group('reconcileActionFor', () {
    test('台帳に無い巻の転送は止めて捨てる（削除した巻を復活させない）', () {
      expect(
        reconcileActionFor(_task(1), TransferState.completed, null),
        ReconcileAction.discard,
      );
    });

    test('待機 / 取得中の巻は、OS の転送の状態に合わせて見守る / 確定 / 再開 / 失敗の解釈に回す', () {
      for (final status in [
        VolumeDownloadStatus.queued,
        VolumeDownloadStatus.downloading,
      ]) {
        final row = _row(status);
        expect(
          {
            for (final state in TransferState.values)
              state: reconcileActionFor(_task(1), state, row),
          },
          {
            TransferState.enqueued: ReconcileAction.watch,
            TransferState.running: ReconcileAction.watch,
            TransferState.waitingToRetry: ReconcileAction.watch,
            TransferState.completed: ReconcileAction.install,
            TransferState.paused: ReconcileAction.resume,
            TransferState.failed: ReconcileAction.retryFailure,
            // 通知の Cancel ボタン。ユーザーが止めたので中断にする。
            TransferState.canceled: ReconcileAction.canceledByUser,
            // プロセスごと消えた。照合の最後に新しいトークンで積み直す。
            TransferState.notFound: ReconcileAction.discard,
          },
          reason: '$status',
        );
      }
    });

    test('ユーザーが止めた巻は、続きから再開できるよう一時停止の転送だけ残す', () {
      for (final status in [
        VolumeDownloadStatus.paused,
        VolumeDownloadStatus.failed,
      ]) {
        final row = _row(status);
        for (final state in TransferState.values) {
          expect(
            reconcileActionFor(_task(1), state, row),
            state == TransferState.paused
                ? ReconcileAction.keepPaused
                : ReconcileAction.discard,
            reason: '$status / $state',
          );
        }
      }
    });

    test('中断した「更新あり」の取り直しは、再開データを残し、書き上がっていれば確定する（数百 MB を落とし直させない）', () {
      final row = _row(VolumeDownloadStatus.completed, filesVersion: 5);
      final refetch = _task(1, filesVersion: 9);
      expect(
        reconcileActionFor(refetch, TransferState.paused, row),
        ReconcileAction.keepPaused,
      );
      expect(
        reconcileActionFor(refetch, TransferState.completed, row),
        ReconcileAction.install,
      );
      for (final state in [
        TransferState.running,
        TransferState.enqueued,
        TransferState.failed,
        TransferState.canceled,
      ]) {
        expect(
          reconcileActionFor(refetch, state, row),
          ReconcileAction.discard,
          reason: '$state',
        );
      }
    });

    test('完了済みの巻と同じ / 古い世代の転送は要らないので捨てる（確定済みの ZIP は触らない）', () {
      final row = _row(VolumeDownloadStatus.completed, filesVersion: 9);
      for (final version in [5, 9]) {
        for (final state in [TransferState.paused, TransferState.completed]) {
          expect(
            reconcileActionFor(_task(1, filesVersion: version), state, row),
            ReconcileAction.discard,
            reason: 'v$version / $state',
          );
        }
      }
    });
  });

  test('捨てる転送のうち、まだ動いているもの（一時停止を含む）にだけ取り消しを送る', () {
    expect(
      {
        for (final state in TransferState.values)
          state: isAliveForDiscard(state),
      },
      {
        TransferState.enqueued: true,
        TransferState.running: true,
        TransferState.waitingToRetry: true,
        TransferState.paused: true,
        TransferState.completed: false,
        TransferState.failed: false,
        TransferState.canceled: false,
        TransferState.notFound: false,
      },
    );
  });
}
