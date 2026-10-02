import 'dart:async';

import 'package:comic_laz/features/viewer/application/page_prefetcher.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<int> precached;
  late PagePrefetcher prefetcher;

  setUp(() {
    precached = [];
    prefetcher = PagePrefetcher(precache: (page) async => precached.add(page));
  });

  test('現在ページ + 後 3 / 前 1 を先読みする', () async {
    prefetcher.update(currentPage: 5, pageCount: 20);
    await pumpEventQueue();

    expect(precached, [5, 6, 7, 8, 4], reason: '読む順（次を優先）');
  });

  test('先頭 / 末尾では範囲外を要求しない', () async {
    prefetcher.update(currentPage: 1, pageCount: 3);
    await pumpEventQueue();
    expect(precached, [1, 2, 3]);

    precached.clear();
    prefetcher.reset();
    prefetcher.update(currentPage: 3, pageCount: 3);
    await pumpEventQueue();
    expect(precached, [3, 2]);
  });

  test('同じページを二重に取得しない', () async {
    prefetcher.update(currentPage: 5, pageCount: 20);
    await pumpEventQueue();
    precached.clear();

    prefetcher.update(currentPage: 6, pageCount: 20);
    await pumpEventQueue();

    expect(precached, [9], reason: '既に持っている 5-8 は取り直さない');
  });

  test('窓から外れたページは忘れる（戻ったら取り直す）', () async {
    prefetcher.update(currentPage: 1, pageCount: 20);
    await pumpEventQueue();
    expect(prefetcher.requestedPages, {1, 2, 3, 4});

    prefetcher.update(currentPage: 10, pageCount: 20);
    await pumpEventQueue();
    expect(prefetcher.requestedPages, {9, 10, 11, 12, 13});

    precached.clear();
    prefetcher.update(currentPage: 1, pageCount: 20);
    await pumpEventQueue();
    expect(precached, [1, 2, 3, 4]);
  });

  test('巻末オーバーレイでは最終ページを基準にする', () async {
    // pageCount + 1（オーバーレイ）でも実ページだけを先読みする
    prefetcher.update(currentPage: 6, pageCount: 5);
    await pumpEventQueue();

    expect(precached, [5, 4]);
  });

  test('ページが 0 枚なら何もしない', () async {
    prefetcher.update(currentPage: 1, pageCount: 0);
    await pumpEventQueue();

    expect(precached, isEmpty);
    expect(prefetcher.requestedPages, isEmpty);
  });

  test('先読みの失敗は無視する（表示側が再取得する）', () async {
    final failing = PagePrefetcher(
      precache: (page) async => throw StateError('boom'),
    );

    failing.update(currentPage: 1, pageCount: 3);
    await pumpEventQueue();

    expect(failing.requestedPages, {
      1,
      2,
      3,
    }, reason: '表示中のページが失敗しても周辺の先読みは止めない');
  });

  test('同期的に投げる先読みでも窓の更新を止めない', () async {
    // `async` でない実装が直接投げても、画面のビルド後処理を壊さないこと。
    final throwing = PagePrefetcher(
      precache: (page) => throw StateError('boom'),
    );

    throwing.update(currentPage: 1, pageCount: 3);
    await pumpEventQueue();

    expect(throwing.requestedPages, {1, 2, 3});
  });

  test('窓の計算は読む順に並ぶ', () {
    expect(prefetcher.windowFor(currentPage: 10, pageCount: 100), [
      10,
      11,
      12,
      13,
      9,
    ]);
  });

  group('表示中のページを優先する（#18）', () {
    late Map<int, Completer<void>> pending;
    late PagePrefetcher slow;

    setUp(() {
      pending = {};
      slow = PagePrefetcher(
        precache: (page) {
          precached.add(page);
          return (pending[page] = Completer<void>()).future;
        },
      );
    });

    test('表示中のページを取り切るまで周辺は要求しない', () async {
      // 窓の 5 枚を同時に投げると、HDD のシークを周辺ページと奪い合って
      // 表示中のページが遅れる。
      slow.update(currentPage: 100, pageCount: 200);
      await pumpEventQueue();
      expect(precached, [100]);

      pending[100]!.complete();
      await pumpEventQueue();
      expect(precached, [100, 101, 102, 103, 99]);
    });

    test('表示中のページが失敗しても周辺は要求する', () async {
      slow.update(currentPage: 100, pageCount: 200);
      pending[100]!.completeError(StateError('boom'));
      await pumpEventQueue();

      expect(precached, [100, 101, 102, 103, 99]);
    });

    test('待っている間に飛んだら、古い窓の周辺は要求しない', () async {
      // 1 ページ目の読み込み中にシークバーで 100 ページへ飛んだ。
      slow.update(currentPage: 1, pageCount: 200);
      await pumpEventQueue();
      slow.update(currentPage: 100, pageCount: 200);
      await pumpEventQueue();
      expect(precached, [1, 100], reason: '飛び先は待たずにすぐ要求する');

      pending[1]!.complete();
      await pumpEventQueue();
      expect(precached, [1, 100], reason: '古い窓（2-4）は今さら要求しない');
      expect(slow.requestedPages, {100});

      pending[100]!.complete();
      await pumpEventQueue();
      expect(precached, [1, 100, 101, 102, 103, 99]);
    });

    test('同じ位置での呼び直しでは周辺の要求を捨てない', () async {
      // 画面は再描画（メニューの開閉など）のたびに update を呼ぶ。
      slow.update(currentPage: 10, pageCount: 200);
      slow.update(currentPage: 10, pageCount: 200);
      await pumpEventQueue();
      expect(precached, [10], reason: '同じページを二重に要求しない');

      pending[10]!.complete();
      await pumpEventQueue();
      expect(precached, [10, 11, 12, 13, 9]);
    });

    test('reset で待たせている周辺も捨てる（巻の移動など）', () async {
      slow.update(currentPage: 10, pageCount: 200);
      slow.reset();

      pending[10]!.complete();
      await pumpEventQueue();

      expect(precached, [10]);
      expect(slow.requestedPages, isEmpty);
    });
  });

  // 表示中のページが混んだ回線で遅いと、周辺の先読みまで止まり、次のページへ
  // 送った直後にまた待たされる。一定時間で見切って周辺を投げる。
  test('表示中のページが遅くても、一定時間で周辺の先読みを始める', () {
    fakeAsync((async) {
      final requested = <int>[];
      final slow = PagePrefetcher(
        precache: (page) {
          requested.add(page);
          // 表示中のページだけ返ってこない。
          return page == 5 ? Completer<void>().future : Future<void>.value();
        },
      );

      slow.update(currentPage: 5, pageCount: 20);
      async.flushMicrotasks();
      expect(requested, [5], reason: 'まずは表示中のページだけ');

      async.elapse(PagePrefetcher.visibleWait);
      async.flushMicrotasks();
      expect(requested, [5, 6, 7, 8, 4]);
    });
  });
}
