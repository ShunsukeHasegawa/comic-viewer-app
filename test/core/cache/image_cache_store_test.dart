import 'package:comic_laz/core/cache/cache_settings.dart';
import 'package:comic_laz/core/cache/image_cache_store.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/cache_fakes.dart';

void main() {
  group('使用量', () {
    test('ページとサムネイルを別枠で集計する（上限が別だから）', () async {
      final harness = CacheHarness.create();
      await harness.write('v1/100/1', bytes: 300);
      await harness.write('v1/100/2', bytes: 200);
      await harness.write(
        't/books/thumbnail/1/9',
        bytes: 50,
        kind: CachedImageKind.thumbnail,
      );

      final usage = await harness.store.usage();

      expect(usage.pageBytes, 500);
      expect(usage.pageCount, 2);
      expect(usage.thumbnailBytes, 50);
      expect(usage.thumbnailCount, 1);
      expect(usage.totalBytes, 550);
    });

    test('空のときは 0（行が無くても集計できる）', () async {
      final harness = CacheHarness.create();
      expect(await harness.store.usage(), CacheUsage.empty);
    });
  });

  group('読み書き', () {
    test('書いたものが同じ内容で読める', () async {
      final harness = CacheHarness.create();
      await harness.store.write(
        key: 'v1/100/1',
        kind: CachedImageKind.page,
        bytes: imageBytes(16, fill: 0x7f),
        contentType: 'image/jpeg',
      );

      final cached = await harness.store.read('v1/100/1');

      expect(cached?.bytes, imageBytes(16, fill: 0x7f));
      expect(cached?.contentType, 'image/jpeg');
    });

    test('無いキーは null', () async {
      final harness = CacheHarness.create();
      expect(await harness.store.read('v1/100/1'), isNull);
    });

    test('OS がファイルだけ消した場合はメタ情報も捨てる', () async {
      final harness = CacheHarness.create();
      await harness.write('v1/100/1', bytes: 100);
      // iOS / Android は Library/Caches を勝手に空にすることがある。
      harness.directories.imageCache.deleteSync(recursive: true);
      harness.directories.imageCache.createSync(recursive: true);

      expect(await harness.store.read('v1/100/1'), isNull);
      expect(
        (await harness.store.usage()).pageCount,
        0,
        reason: '残っていると使用量が実際より多く見える',
      );
    });
  });

  group('上限超過（LRU）', () {
    test('最後に使ったのが古い順に削除する', () async {
      final harness = CacheHarness.create();
      // 上限 300 バイトに対して 400 バイト書く。
      await harness.write('v1/100/1', bytes: 100);
      await harness.write(
        'v1/100/2',
        bytes: 100,
        after: const Duration(minutes: 1),
      );
      await harness.write(
        'v1/100/3',
        bytes: 100,
        after: const Duration(minutes: 1),
      );
      await harness.write(
        'v1/100/4',
        bytes: 100,
        after: const Duration(minutes: 1),
      );

      await harness.store.evictToLimit(CachedImageKind.page, 300);

      expect(await harness.keysByLastUsed(), [
        'v1/100/2',
        'v1/100/3',
        'v1/100/4',
      ]);
      expect(harness.hasFile('v1/100/1'), isFalse, reason: '実体も消えないと容量が空かない');
    });

    test('読み出したものは新しく扱う（LRU の基準は最後に使った時刻）', () async {
      final harness = CacheHarness.create();
      await harness.write('v1/100/1', bytes: 100);
      await harness.write(
        'v1/100/2',
        bytes: 100,
        after: const Duration(minutes: 1),
      );
      await harness.write(
        'v1/100/3',
        bytes: 100,
        after: const Duration(minutes: 1),
      );

      // 一番古い 1 を読み直す = まだ使っているので消したくない。
      harness.clock.advance(const Duration(minutes: 1));
      await harness.store.read('v1/100/1');

      await harness.store.evictToLimit(CachedImageKind.page, 200);

      expect(await harness.keysByLastUsed(), ['v1/100/3', 'v1/100/1']);
    });

    test('無制限のときは削除しない', () async {
      final harness = CacheHarness.create();
      await harness.settingsStore.write(
        const CacheSettings(
          pageLimit: CacheLimit.unlimited,
          thumbnailLimit: CacheLimit.unlimited,
          retention: CacheRetention.forever,
        ),
      );
      await harness.write('v1/100/1', bytes: 1000);

      await harness.store.evictIfNeeded();

      expect((await harness.store.usage()).pageCount, 1);
    });

    test('サムネイルの上限はページ画像を巻き込まない（別枠管理）', () async {
      final harness = CacheHarness.create();
      await harness.write('v1/100/1', bytes: 1000);
      await harness.write('t/a/1', bytes: 100, kind: CachedImageKind.thumbnail);
      await harness.write(
        't/b/1',
        bytes: 100,
        kind: CachedImageKind.thumbnail,
        after: const Duration(minutes: 1),
      );

      await harness.store.evictToLimit(CachedImageKind.thumbnail, 100);

      final usage = await harness.store.usage();
      expect(usage.pageCount, 1, reason: 'サムネイルの上限でページ画像を消してはいけない');
      expect(usage.thumbnailCount, 1);
    });
  });

  group('保持期間', () {
    test('最後に使ってから期間を過ぎたものを削除する', () async {
      final harness = CacheHarness.create();
      await harness.settingsStore.write(
        const CacheSettings(retention: CacheRetention.days7),
      );
      await harness.write('v1/100/1', bytes: 100);
      await harness.write(
        'v1/100/2',
        bytes: 100,
        after: const Duration(days: 6),
      );

      // 1 は 8 日前 / 2 は 2 日前になる。
      harness.clock.advance(const Duration(days: 2));
      await harness.store.evictIfNeeded();

      expect(await harness.keysByLastUsed(), ['v1/100/2']);
      expect(harness.hasFile('v1/100/1'), isFalse);
    });

    test('無期限なら古くても残す', () async {
      final harness = CacheHarness.create();
      await harness.settingsStore.write(
        const CacheSettings(retention: CacheRetention.forever),
      );
      await harness.write('v1/100/1', bytes: 100);

      harness.clock.advance(const Duration(days: 400));
      await harness.store.evictIfNeeded();

      expect(await harness.keysByLastUsed(), ['v1/100/1']);
    });
  });

  group('ZIP 差し替え（世代入れ替え）', () {
    test('古い世代だけ消し、新しい世代と他の巻は残す', () async {
      final harness = CacheHarness.create();
      await harness.write('v1/100/1', bytes: 100);
      await harness.write('v1/100/2', bytes: 100);
      await harness.write('v1/200/1', bytes: 100);
      await harness.write('v2/100/1', bytes: 100);

      await harness.store.evictOtherVersions(
        volumeId: 1,
        keepFilesVersion: 200,
      );

      expect(
        await harness.keysByLastUsed(),
        unorderedEquals(['v1/200/1', 'v2/100/1']),
      );
      expect(harness.hasFile('v1/100/1'), isFalse);
      expect(harness.hasFile('v1/200/1'), isTrue);
    });

    test('巻 ID が接頭辞として重なっても巻き込まない（v1 と v11）', () async {
      final harness = CacheHarness.create();
      await harness.write('v1/100/1', bytes: 100);
      await harness.write('v11/100/1', bytes: 100);

      await harness.store.evictOtherVersions(
        volumeId: 1,
        keepFilesVersion: 200,
      );

      expect(await harness.keysByLastUsed(), ['v11/100/1']);
    });
  });

  group('手動削除', () {
    test('種別を指定するとその種別だけ消える（サムネイルだけ削除）', () async {
      final harness = CacheHarness.create();
      await harness.write('v1/100/1', bytes: 100);
      await harness.write('t/a/1', bytes: 100, kind: CachedImageKind.thumbnail);

      await harness.store.clear(kind: CachedImageKind.thumbnail);

      final usage = await harness.store.usage();
      expect(usage.pageCount, 1);
      expect(usage.thumbnailCount, 0);
      expect(harness.hasFile('t/a/1'), isFalse);
    });

    test('種別を指定しないと全部消える（ファイルも残さない）', () async {
      final harness = CacheHarness.create();
      await harness.write('v1/100/1', bytes: 100);
      await harness.write('t/a/1', bytes: 100, kind: CachedImageKind.thumbnail);

      await harness.store.clear();

      expect(await harness.store.usage(), CacheUsage.empty);
      expect(harness.fileCount, 0);
    });
  });
}
