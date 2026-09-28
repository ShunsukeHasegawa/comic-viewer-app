import 'package:comic_laz/features/viewer/application/page_prefetcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<int> precached;
  late PagePrefetcher prefetcher;

  setUp(() {
    precached = [];
    prefetcher = PagePrefetcher(precache: (page) async => precached.add(page));
  });

  test('現在ページ + 後 3 / 前 1 を先読みする', () {
    prefetcher.update(currentPage: 5, pageCount: 20);

    expect(precached, [5, 6, 7, 8, 4], reason: '読む順（次を優先）');
  });

  test('先頭 / 末尾では範囲外を要求しない', () {
    prefetcher.update(currentPage: 1, pageCount: 3);
    expect(precached, [1, 2, 3]);

    precached.clear();
    prefetcher.reset();
    prefetcher.update(currentPage: 3, pageCount: 3);
    expect(precached, [3, 2]);
  });

  test('同じページを二重に取得しない', () {
    prefetcher.update(currentPage: 5, pageCount: 20);
    precached.clear();

    prefetcher.update(currentPage: 6, pageCount: 20);

    expect(precached, [9], reason: '既に持っている 5-8 は取り直さない');
  });

  test('窓から外れたページは忘れる（戻ったら取り直す）', () {
    prefetcher.update(currentPage: 1, pageCount: 20);
    expect(prefetcher.requestedPages, {1, 2, 3, 4});

    prefetcher.update(currentPage: 10, pageCount: 20);
    expect(prefetcher.requestedPages, {9, 10, 11, 12, 13});

    precached.clear();
    prefetcher.update(currentPage: 1, pageCount: 20);
    expect(precached, [1, 2, 3, 4]);
  });

  test('巻末オーバーレイでは最終ページを基準にする', () {
    // pageCount + 1（オーバーレイ）でも実ページだけを先読みする
    prefetcher.update(currentPage: 6, pageCount: 5);

    expect(precached, [5, 4]);
  });

  test('ページが 0 枚なら何もしない', () {
    prefetcher.update(currentPage: 1, pageCount: 0);

    expect(precached, isEmpty);
    expect(prefetcher.requestedPages, isEmpty);
  });

  test('先読みの失敗は無視する（表示側が再取得する）', () async {
    final failing = PagePrefetcher(
      precache: (page) async => throw StateError('boom'),
    );

    failing.update(currentPage: 1, pageCount: 3);
    await pumpEventQueue();

    expect(failing.requestedPages, {1, 2, 3});
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
}
