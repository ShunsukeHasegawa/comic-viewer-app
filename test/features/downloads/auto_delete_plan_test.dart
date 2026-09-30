import 'package:comic_laz/features/downloads/domain/auto_delete_plan.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/progress/domain/reading_progress.dart';
import 'package:flutter_test/flutter_test.dart';

const _gb = 1 << 30;
final _now = DateTime.utc(2026, 9, 30, 12);

VolumeDownload _completed(int volumeId, {int bytes = 100}) => VolumeDownload(
  volumeId: volumeId,
  bookId: 1,
  filesVersion: 5,
  status: VolumeDownloadStatus.completed,
  pageCount: 10,
  receivedBytes: bytes,
  totalBytes: bytes,
);

ReadingProgress _progress(
  int volumeId, {
  required int page,
  required int daysAgo,
}) => ReadingProgress(
  volumeId: volumeId,
  currentPage: page,
  maxPage: 10,
  readAt: _now.subtract(Duration(days: daysAgo)),
);

const _finished30 = AutoDeleteSettings(finished: FinishedRetention.days30);

void main() {
  test('既定（すべてオフ）では何も消さない', () {
    final plan = planAutoDelete(
      const AutoDeleteSettings(),
      AutoDeleteInputs(
        ledger: {1: _completed(1)},
        progress: {1: _progress(1, page: 10, daysAgo: 365)},
        freeBytes: 0,
        now: _now,
      ),
    );

    expect(plan.all, isEmpty);
  });

  test('この端末で読み終えた巻は、最後に読んでから N 日で消し、N 日未満は残す', () {
    final plan = planAutoDelete(
      _finished30,
      AutoDeleteInputs(
        ledger: {1: _completed(1), 2: _completed(2), 3: _completed(3)},
        progress: {
          1: _progress(1, page: 10, daysAgo: 30),
          2: _progress(2, page: 10, daysAgo: 29),
          // 読みかけは期間が過ぎても読了ポリシーでは消さない。
          3: _progress(3, page: 5, daysAgo: 90),
        },
        now: _now,
      ),
    );

    expect(plan.finished, [1]);
    expect(plan.lowSpace, isEmpty);
  });

  test('読み返し中（手元は途中・サーバーは読了）の巻は最後に開いた日から数える（読んでいる最中に消さない）', () {
    final plan = planAutoDelete(
      _finished30,
      AutoDeleteInputs(
        ledger: {1: _completed(1), 2: _completed(2)},
        progress: {
          1: _progress(1, page: 3, daysAgo: 1),
          2: _progress(2, page: 3, daysAgo: 31),
        },
        finishedOnServer: {1, 2},
        now: _now,
      ),
    );

    expect(plan.finished, [2]);
  });

  test('他端末で読了した巻は初めて気づいた日を記録するだけで、その回は消さない', () {
    final first = planAutoDelete(
      _finished30,
      AutoDeleteInputs(
        ledger: {1: _completed(1)},
        finishedOnServer: {1},
        now: _now,
      ),
    );

    expect(first.finished, isEmpty, reason: '読み返すために落とした直後に消さない');
    expect(first.finishedSeen, {1: _now});

    // 気づいてから N 日経てば消す。
    final later = _now.add(const Duration(days: 30));
    final second = planAutoDelete(
      _finished30,
      AutoDeleteInputs(
        ledger: {1: _completed(1)},
        finishedOnServer: {1},
        finishedSeen: first.finishedSeen,
        now: later,
      ),
    );

    expect(second.finished, [1]);
    expect(second.finishedSeen, {1: _now}, reason: '気づいた時刻は上書きしない');
  });

  test('台帳に無い巻の記録は刈り込む（ログアウト後に前のユーザーの記録を持ち越さない）', () {
    final plan = planAutoDelete(
      _finished30,
      AutoDeleteInputs(
        ledger: {1: _completed(1)},
        finishedSeen: {1: _now, 99: _now},
        finishedOnServer: {1},
        now: _now,
      ),
    );

    expect(plan.finishedSeen.keys, [1]);
  });

  test('ビューアで開いている巻は消さない', () {
    final plan = planAutoDelete(
      const AutoDeleteSettings(
        finished: FinishedRetention.days7,
        lowSpace: LowSpaceThreshold.gb5,
      ),
      AutoDeleteInputs(
        ledger: {1: _completed(1)},
        progress: {1: _progress(1, page: 10, daysAgo: 90)},
        openVolumeIds: {1},
        freeBytes: 0,
        now: _now,
      ),
    );

    expect(plan.all, isEmpty);
  });

  test('取得中・待機・中断・失敗の巻は消さない（取り直し中の旧世代も含む）', () {
    final ledger = {
      for (final (id, status) in [
        (1, VolumeDownloadStatus.downloading),
        (2, VolumeDownloadStatus.queued),
        (3, VolumeDownloadStatus.paused),
        (4, VolumeDownloadStatus.failed),
      ])
        // 旧世代の ZIP がある（filesVersion / pageCount あり）取り直し中の行。
        id: _completed(id).copyWith(status: status),
    };
    final plan = planAutoDelete(
      const AutoDeleteSettings(
        finished: FinishedRetention.days7,
        lowSpace: LowSpaceThreshold.gb5,
      ),
      AutoDeleteInputs(
        ledger: ledger,
        progress: {
          for (final id in ledger.keys)
            id: _progress(id, page: 10, daysAgo: 90),
        },
        freeBytes: 0,
        now: _now,
      ),
    );

    expect(plan.all, isEmpty);
  });

  test('空き容量がしきい値を下回ったら、読了 → 読みかけの順に古いものから、回復する分だけ消す', () {
    final plan = planAutoDelete(
      const AutoDeleteSettings(lowSpace: LowSpaceThreshold.gb2),
      AutoDeleteInputs(
        ledger: {
          for (final id in [1, 2, 3, 4, 5]) id: _completed(id, bytes: _gb ~/ 2),
        },
        progress: {
          1: _progress(1, page: 5, daysAgo: 100), // 読みかけ・最も古い
          2: _progress(2, page: 10, daysAgo: 1), // 読了・新しい
          3: _progress(3, page: 10, daysAgo: 10), // 読了・古い
          4: _progress(4, page: 5, daysAgo: 50), // 読みかけ
          5: _progress(5, page: 5, daysAgo: 2), // 読みかけ・新しい
        },
        freeBytes: _gb ~/ 2,
        now: _now,
      ),
    );

    // 0.5 GB → 2 GB に戻すには 1.5 GB（3 巻）で足りる。
    expect(plan.lowSpace, [3, 2, 1]);
    expect(
      plan.bytesOf({
        for (final id in [1, 2, 3]) id: _completed(id, bytes: _gb ~/ 2),
      }),
      3 * (_gb ~/ 2),
    );
  });

  test('一度も開いていない巻は空き容量が足りなくても消さない（これから読むために落とした巻）', () {
    final plan = planAutoDelete(
      const AutoDeleteSettings(lowSpace: LowSpaceThreshold.gb5),
      AutoDeleteInputs(
        ledger: {1: _completed(1), 2: _completed(2)},
        progress: {2: _progress(2, page: 3, daysAgo: 1)},
        freeBytes: 0,
        now: _now,
      ),
    );

    expect(plan.lowSpace, [2]);
  });

  test('空き容量が分からないときは空き容量のポリシーを動かさない', () {
    final plan = planAutoDelete(
      const AutoDeleteSettings(lowSpace: LowSpaceThreshold.gb5),
      AutoDeleteInputs(
        ledger: {1: _completed(1)},
        progress: {1: _progress(1, page: 10, daysAgo: 100)},
        now: _now,
      ),
    );

    expect(plan.all, isEmpty);
  });

  test('空き容量が足りていれば空き容量のポリシーでは消さない', () {
    final plan = planAutoDelete(
      const AutoDeleteSettings(lowSpace: LowSpaceThreshold.gb1),
      AutoDeleteInputs(
        ledger: {1: _completed(1)},
        progress: {1: _progress(1, page: 10, daysAgo: 100)},
        freeBytes: _gb,
        now: _now,
      ),
    );

    expect(plan.all, isEmpty);
  });

  test('読了ポリシーで消える巻は空き容量の計算で二重に数えない', () {
    final plan = planAutoDelete(
      const AutoDeleteSettings(
        finished: FinishedRetention.days30,
        lowSpace: LowSpaceThreshold.gb2,
      ),
      AutoDeleteInputs(
        ledger: {
          1: _completed(1, bytes: _gb),
          2: _completed(2, bytes: _gb),
          3: _completed(3, bytes: _gb),
        },
        progress: {
          1: _progress(1, page: 10, daysAgo: 60), // 読了ポリシーで消える
          2: _progress(2, page: 10, daysAgo: 5),
          3: _progress(3, page: 5, daysAgo: 5),
        },
        freeBytes: 0,
        now: _now,
      ),
    );

    expect(plan.finished, [1]);
    // 1 巻目で 1 GB 空くので、残り 1 GB 分（1 巻）だけ消す。
    expect(plan.lowSpace, [2]);
    expect(plan.all, [1, 2]);
  });

  group('落とし直した巻（前回のダウンロードの記録が残っている）', () {
    VolumeDownload completedAt(int volumeId, {required int daysAgo}) =>
        _completed(volumeId)
            .copyWith(completedAt: _now.subtract(Duration(days: daysAgo)));

    test('この端末で昔読み終えた巻を落とし直しても、落とした日から数える（開く前に消さない）', () {
      // 60 日前に読了 → 消した → 読み返すために昨日落とし直した。進捗の行は
      // 送信後も残る（#12）ので、readAt は 60 日前のまま。
      final plan = planAutoDelete(
        const AutoDeleteSettings(finished: FinishedRetention.days7),
        AutoDeleteInputs(
          ledger: {1: completedAt(1, daysAgo: 1)},
          progress: {1: _progress(1, page: 10, daysAgo: 60)},
          now: _now,
        ),
      );

      expect(plan.finished, isEmpty);

      // 落としてから期間が過ぎれば、開かなくても読了ポリシーで消える。
      final later = planAutoDelete(
        const AutoDeleteSettings(finished: FinishedRetention.days7),
        AutoDeleteInputs(
          ledger: {1: completedAt(1, daysAgo: 7)},
          progress: {1: _progress(1, page: 10, daysAgo: 60)},
          now: _now,
        ),
      );
      expect(later.finished, [1]);
    });

    test('今の世代を確定する前に気づいた記録（削除・ログアウトを跨いだもの）は捨てて気づき直す', () {
      final stale = _now.subtract(const Duration(days: 60));
      final plan = planAutoDelete(
        const AutoDeleteSettings(finished: FinishedRetention.days7),
        AutoDeleteInputs(
          ledger: {1: completedAt(1, daysAgo: 1)},
          finishedOnServer: {1},
          finishedSeen: {1: stale},
          now: _now,
        ),
      );

      expect(plan.finished, isEmpty, reason: '落とし直した巻を古い記録で消さない');
      expect(plan.finishedSeen, {1: _now});
    });

    test('待機・中断のまま長く待った巻は、待っている間は気づいた時刻を付けず、完了した回には消さない', () {
      final queued = _completed(1).copyWith(
        status: VolumeDownloadStatus.queued,
        filesVersion: 0,
        pageCount: 0,
      );
      final waiting = planAutoDelete(
        const AutoDeleteSettings(finished: FinishedRetention.days7),
        AutoDeleteInputs(
          ledger: {1: queued},
          finishedOnServer: {1},
          now: _now.subtract(const Duration(days: 10)),
        ),
      );
      expect(waiting.finishedSeen, isEmpty);

      final done = planAutoDelete(
        const AutoDeleteSettings(finished: FinishedRetention.days7),
        AutoDeleteInputs(
          ledger: {1: completedAt(1, daysAgo: 0)},
          finishedOnServer: {1},
          finishedSeen: waiting.finishedSeen,
          now: _now,
        ),
      );
      expect(done.finished, isEmpty);
      expect(done.finishedSeen, {1: _now});
    });
  });

  test('他端末でだけ読了した巻は、空き容量が足りなくてもこの端末で開くまで消さない（読み返すために落とした巻）', () {
    const settings = AutoDeleteSettings(lowSpace: LowSpaceThreshold.gb2);
    final ledger = {1: _completed(1, bytes: _gb), 2: _completed(2, bytes: _gb)};
    final first = planAutoDelete(
      settings,
      AutoDeleteInputs(
        ledger: ledger,
        progress: {2: _progress(2, page: 3, daysAgo: 1)},
        finishedOnServer: {1},
        freeBytes: 0,
        now: _now,
      ),
    );
    expect(first.lowSpace, [2], reason: '読みかけの巻を先に消し、未開封の巻は残す');

    // 気づいた後の回（時刻が記録された後）でも、開くまでは候補にしない。
    final second = planAutoDelete(
      settings,
      AutoDeleteInputs(
        ledger: {1: ledger[1]!},
        finishedOnServer: {1},
        finishedSeen: first.finishedSeen,
        freeBytes: 0,
        now: _now.add(const Duration(days: 30)),
      ),
    );
    expect(second.lowSpace, isEmpty);
  });

  test('昔この端末で読んだ巻を落とし直したものは、開き直すまで空き容量のポリシーで消さない', () {
    final plan = planAutoDelete(
      const AutoDeleteSettings(lowSpace: LowSpaceThreshold.gb5),
      AutoDeleteInputs(
        ledger: {
          1: _completed(1)
              .copyWith(completedAt: _now.subtract(const Duration(days: 1))),
        },
        progress: {1: _progress(1, page: 10, daysAgo: 60)},
        freeBytes: 0,
        now: _now,
      ),
    );

    expect(plan.lowSpace, isEmpty);
  });
}
