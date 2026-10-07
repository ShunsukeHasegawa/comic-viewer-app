import 'package:comic_laz/features/downloads/application/download_progress_book.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:flutter_test/flutter_test.dart';

const _queued = VolumeDownload(
  volumeId: 1,
  bookId: 1,
  filesVersion: 0,
  status: VolumeDownloadStatus.queued,
  totalBytes: 1000,
);

void main() {
  group('applyProgress', () {
    test('進捗が届いた = 走っているので「取得中」にする', () {
      final next = applyProgress(_queued, 10, 2000);
      expect(next.status, VolumeDownloadStatus.downloading);
      expect(next.receivedBytes, 10);
      expect(next.totalBytes, 2000);
    });

    test('全体が分からない進捗では、マニフェストの大きさ（今の値）を消さない', () {
      expect(applyProgress(_queued, 10, null).totalBytes, 1000);
      expect(applyProgress(_queued, 10, 0).totalBytes, 1000);
      expect(applyProgress(_queued, 10, -1).totalBytes, 1000);
    });
  });

  group('ProgressPersistThrottle', () {
    test('1 巻で数千回の UPDATE にならないよう、間隔を超えたときだけ書く', () {
      final throttle = ProgressPersistThrottle();
      expect(
        throttle.shouldPersist(1, progressPersistIntervalBytes - 1),
        isFalse,
      );
      expect(throttle.shouldPersist(1, progressPersistIntervalBytes), isTrue);
      expect(
        throttle.shouldPersist(1, progressPersistIntervalBytes * 2 - 1),
        isFalse,
      );
      expect(
        throttle.shouldPersist(1, progressPersistIntervalBytes * 2),
        isTrue,
      );
    });

    test('先頭からの取り直し（巻き戻り）も同じ幅で拾い、古い進捗を表示に残さない', () {
      final throttle = ProgressPersistThrottle()
        ..shouldPersist(1, progressPersistIntervalBytes * 3);
      expect(throttle.shouldPersist(1, 0), isTrue);
    });

    test('restart / forget / clear の後は 0 から数え直す', () {
      final throttle = ProgressPersistThrottle()
        ..shouldPersist(1, progressPersistIntervalBytes * 3)
        ..restart(1);
      expect(
        throttle.shouldPersist(1, progressPersistIntervalBytes - 1),
        isFalse,
      );

      throttle
        ..shouldPersist(2, progressPersistIntervalBytes * 3)
        ..forget(2);
      expect(
        throttle.shouldPersist(2, progressPersistIntervalBytes - 1),
        isFalse,
      );

      throttle
        ..shouldPersist(3, progressPersistIntervalBytes * 3)
        ..clear();
      expect(
        throttle.shouldPersist(3, progressPersistIntervalBytes - 1),
        isFalse,
      );
    });

    test('巻ごとに数える', () {
      final throttle = ProgressPersistThrottle()
        ..shouldPersist(1, progressPersistIntervalBytes);
      expect(throttle.shouldPersist(2, progressPersistIntervalBytes), isTrue);
    });
  });

  group('SpaceReservations', () {
    test('まとめて積んだ巻の残りを合計し、後半が転送の途中で容量不足にならないようにする（F7）', () {
      final reservations = SpaceReservations()
        ..reserve(1, 100)
        ..reserve(2, 200)
        ..reserve(3, 400);
      expect(reservations.reservedByOthers(3, isActive: (_) => true), 300);
    });

    test('中断中の巻は再開されるか分からないので数えない（入るはずの巻を塞がない）', () {
      final reservations = SpaceReservations()
        ..reserve(1, 100)
        ..reserve(2, 200);
      expect(reservations.reservedByOthers(3, isActive: (id) => id == 2), 200);
    });

    test('進んだ分は外し、残りだけを押さえる（受信が全体を超えても負にしない）', () {
      final reservations = SpaceReservations()
        ..reserve(1, 1000)
        ..reserveRemaining(1, total: 1000, received: 400);
      expect(reservations.reservedByOthers(2, isActive: (_) => true), 600);
      reservations.reserveRemaining(1, total: 1000, received: 1200);
      expect(reservations.reservedByOthers(2, isActive: (_) => true), 0);
    });

    test('手放した巻（確定 / 取り消し / ログアウト）は数えない', () {
      final reservations = SpaceReservations()
        ..reserve(1, 100)
        ..reserve(2, 200)
        ..release(1);
      expect(reservations.reservedByOthers(3, isActive: (_) => true), 200);
      reservations.clear();
      expect(reservations.reservedByOthers(3, isActive: (_) => true), 0);
    });
  });
}
