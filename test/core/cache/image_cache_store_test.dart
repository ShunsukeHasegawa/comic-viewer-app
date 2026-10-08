import 'dart:io';

import 'package:comic_laz/core/cache/cache_settings.dart';
import 'package:comic_laz/core/cache/image_cache_store.dart';
import 'package:comic_laz/core/storage/app_database.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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

    // グリッドの再描画などで同じ画像が何度も読まれるたびに UPDATE を打たない。
    test('直近に使った画像を読み直しても最後に使った時刻を書き直さない', () async {
      final harness = CacheHarness.create();
      await harness.write('v1/100/1', bytes: 100);
      final writtenAt = await _lastUsedAt(harness, 'v1/100/1');

      harness.clock.advance(
        ImageCacheStore.lastUsedRefreshInterval - const Duration(seconds: 1),
      );
      await harness.store.read('v1/100/1');

      expect(await _lastUsedAt(harness, 'v1/100/1'), writtenAt);
    });

    test('間隔を過ぎてから読んだら最後に使った時刻を進める（LRU の基準）', () async {
      final harness = CacheHarness.create();
      await harness.write('v1/100/1', bytes: 100);

      harness.clock.advance(ImageCacheStore.lastUsedRefreshInterval);
      await harness.store.read('v1/100/1');

      final lastUsedAt = await _lastUsedAt(harness, 'v1/100/1');
      expect(lastUsedAt.isAtSameMomentAs(harness.clock.now()), isTrue);
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

    // 掃除は書き込みのたびに走るので、行は少しずつ読む。区切りをまたいでも
    // 上限まで消し切り、新しい方を残すことを確かめる。
    test('読み出しの区切り（200 件）を超える超過でも上限まで古い順に消し切る', () async {
      final harness = CacheHarness.create();
      await harness.recordMany(500, bytes: 10, prefix: 'v1/old/');
      await harness.record(
        'v1/new/1',
        bytes: 10,
        after: const Duration(minutes: 1),
      );

      await harness.store.evictToLimit(CachedImageKind.page, 1000);

      final usage = await harness.store.usage();
      expect(usage.pageBytes, 1000);
      expect(usage.pageCount, 100);
      expect(
        await harness.keysByLastUsed(),
        contains('v1/new/1'),
        reason: '最後に使ったものは最後まで残す',
      );
    });

    test('上限を超えていなければ何も消さない', () async {
      final harness = CacheHarness.create();
      await harness.record('v1/100/1', bytes: 100);
      await harness.record('v1/100/2', bytes: 100);

      await harness.store.evictToLimit(CachedImageKind.page, 200);

      expect((await harness.store.usage()).pageCount, 2);
    });

    // 保護印つきは消せないが、数えないと上限を超えて使い続けてしまう。
    test('保護印つきは消さずに合計へ数え、その分だけ普通の画像を追い出す', () async {
      final harness = CacheHarness.create();
      await harness.record('v1/100/1', bytes: 100);
      await harness.record(
        'v1/100/2',
        bytes: 100,
        after: const Duration(minutes: 1),
      );
      await harness.record(
        'v1/100/3',
        bytes: 100,
        after: const Duration(minutes: 1),
      );
      await harness.store.pin(bookId: 1, keys: ['v1/100/1']);

      await harness.store.evictToLimit(CachedImageKind.page, 200);

      expect(await harness.keysByLastUsed(), ['v1/100/1', 'v1/100/3']);
    });

    test('保護印つきだけで上限を超えていても止まる（消せるものが無い）', () async {
      final harness = CacheHarness.create();
      await harness.record('v1/100/1', bytes: 300);
      await harness.store.pin(bookId: 1, keys: ['v1/100/1']);

      await harness.store.evictToLimit(CachedImageKind.page, 100);

      expect(await harness.keysByLastUsed(), ['v1/100/1']);
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

  // ダウンロード済みタイトルのサムネイルは、オフラインで一覧 / 詳細を出すために
  // 必須なので LRU も保持期間も適用しない（#11）。
  group('保護印', () {
    test('保持期間を過ぎても保護した画像は消さない', () async {
      final harness = CacheHarness.create();
      await harness.settingsStore.write(
        const CacheSettings(retention: CacheRetention.days7),
      );
      await harness.write(
        't/books/thumbnail/340/7',
        bytes: 100,
        kind: CachedImageKind.thumbnail,
      );
      await harness.write(
        't/books/thumbnail/999/1',
        bytes: 100,
        kind: CachedImageKind.thumbnail,
      );
      await harness.store.pin(bookId: 12, keys: ['t/books/thumbnail/340/7']);

      harness.clock.advance(const Duration(days: 8));
      await harness.store.evictIfNeeded();

      expect(await harness.keysByLastUsed(), ['t/books/thumbnail/340/7']);
      expect(harness.hasFile('t/books/thumbnail/340/7'), isTrue);
    });

    test('ダウンロードが無くなったタイトルの印は外れる', () async {
      final harness = CacheHarness.create();
      await harness.store.pin(bookId: 12, keys: ['t/a/1']);
      await harness.store.pin(bookId: 34, keys: ['t/b/1']);

      await harness.store.retainPins({34});

      expect(await harness.store.pinnedKeys(), {'t/b/1'});
    });

    test('ユーザーが「キャッシュを削除」を選んだときは保護印つきでも消す', () async {
      final harness = CacheHarness.create();
      await harness.write('t/a/1', bytes: 100, kind: CachedImageKind.thumbnail);
      await harness.store.pin(bookId: 12, keys: ['t/a/1']);

      await harness.store.clear();

      expect(await harness.store.usage(), CacheUsage.empty);
      expect(await harness.store.pinnedKeys(), {
        't/a/1',
      }, reason: '印は残す（オンラインで取り直した分から再び守られる）');
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

    // 期限切れが大量にあると全件の行オブジェクトを同時に持つため、端末の
    // メモリを圧迫する。区切りをまたいでも保護対象を残して消し切る。
    test('期限切れが200件を超えても区切って消し切り、保護した画像は残す', () async {
      final harness = CacheHarness.create();
      await harness.settingsStore.write(
        const CacheSettings(retention: CacheRetention.days7),
      );
      await harness.recordMany(450, bytes: 10, prefix: 'v1/expired/');
      await harness.record(
        't/expired/pinned',
        bytes: 10,
        kind: CachedImageKind.thumbnail,
      );
      await harness.store.pin(bookId: 12, keys: ['t/expired/pinned']);

      harness.clock.advance(const Duration(days: 8));
      await harness.store.evictIfNeeded();

      expect(await harness.keysByLastUsed(), ['t/expired/pinned']);
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

    // 1 文で消すと SQLite の変数上限（32766）に当たり、削除が丸ごと失敗して
    // 「消したのに使用量が減らない」状態になる（ログアウト時の破棄も同じ経路）。
    test('変数上限を超える件数でもメタ情報を消し切る', () async {
      final harness = CacheHarness.create();
      await harness.recordMany(33000, bytes: 10);

      await harness.store.clear();

      expect(await harness.store.usage(), CacheUsage.empty);
    });

    // 書き込みは「実体 → 行」の順なので、途中で落ちると実体だけが残る。
    // 孤児は使用量にも出ないため、ここで回収しないと永久に容量を食う。
    test('行を持たない実体（孤児）も回収する', () async {
      final harness = CacheHarness.create();
      File(p.join(harness.directories.imageCache.path, 'orphan'))
          .writeAsBytesSync(imageBytes(64));

      await harness.store.clear();

      expect(harness.fileCount, 0);
    });

    // 書き込みは「実体 → 行」の順なので、その間に掃除が割り込むと、これから
    // 行を入れる実体を孤児と見て消し、行だけが残る（次の読み出しまでミスになる）。
    test('書き込み中（行を入れる前）の実体は孤児として消さない', () async {
      final harness = CacheHarness.create();
      final store = harness.storeLike(GatedWriteCacheStore.new);

      final writing = store.write(
        key: 'v1/100/1',
        kind: CachedImageKind.page,
        bytes: imageBytes(16),
      );
      await store.written.future;
      await store.sweepOrphanFiles();
      store.gate.complete();
      await writing;

      expect(harness.hasFile('v1/100/1'), isTrue);
      expect((await store.read('v1/100/1'))?.bytes, imageBytes(16));
    });

    test('キャッシュのディレクトリごと消えていても孤児の掃除は失敗しない', () async {
      final harness = CacheHarness.create();
      harness.directories.imageCache.deleteSync(recursive: true);

      await harness.store.sweepOrphanFiles();
    });

    // 行を読む前に「書き込み中」だったものが、行を読んだ後・ループが届く前に
    // 書き終えると、行も書き込み中の印も見えず孤児と誤って消してしまう。
    test('掃除の途中で書き込みが終わった実体も消さない', () async {
      final harness = CacheHarness.create();
      final store = harness.storeLike(SweepInterleavingCacheStore.new);

      final writing = store.write(
        key: 'v1/100/1',
        kind: CachedImageKind.page,
        bytes: imageBytes(16),
      );
      store.pendingWrite = writing;
      await store.written.future;
      await store.sweepOrphanFiles();
      await writing;

      expect(harness.hasFile('v1/100/1'), isTrue);
      expect((await store.read('v1/100/1'))?.bytes, imageBytes(16));
    });

    // 握ると削除（ログアウト時の破棄）が成功扱いになり、やり直しの印が
    // 消えて二度と回収されない（#15。purger は失敗を投げる約束）。
    test('ディレクトリを列挙できないときは投げる（無いだけなら投げない）', () async {
      final harness = CacheHarness.create();
      final directory = harness.directories.imageCache;
      directory.deleteSync(recursive: true);
      // 同じ場所にファイルを置くと「ある（が列挙できない）」状態になる。
      File(directory.path).writeAsBytesSync(imageBytes(1));

      await expectLater(
        harness.store.clear(),
        throwsA(
          isA<FileSystemException>().having(
            (error) => error is PathNotFoundException,
            'PathNotFoundException か',
            isFalse,
          ),
        ),
      );
    });

    test('行がある実体は孤児として消さない（種別を指定した削除）', () async {
      final harness = CacheHarness.create();
      await harness.write('v1/100/1', bytes: 100);
      await harness.write('t/a/1', bytes: 100, kind: CachedImageKind.thumbnail);

      await harness.store.clear(kind: CachedImageKind.thumbnail);

      expect(harness.hasFile('v1/100/1'), isTrue);
    });
  });

  group('ログアウト時の破棄（世代）', () {
    // ログアウト前に始まったダウンロードが破棄の後に完了すると、前のユーザーの
    // 画像がディスクに戻り、別のユーザーがそれを見てしまう（#8 / #15）。
    test('破棄より前に始まった取得の書き戻しは捨てる', () async {
      final harness = CacheHarness.create();
      final generation = harness.store.generation;

      await harness.store.clear();
      await harness.store.write(
        key: 'v1/100/1',
        kind: CachedImageKind.page,
        bytes: imageBytes(16),
        generation: generation,
      );

      expect(await harness.store.usage(), CacheUsage.empty);
      expect(harness.fileCount, 0, reason: '実体を残すと次のユーザーがキャッシュヒットする');
    });

    test('破棄の後に始まった取得は普通に保存する', () async {
      final harness = CacheHarness.create();
      await harness.store.clear();

      await harness.store.write(
        key: 'v1/100/1',
        kind: CachedImageKind.page,
        bytes: imageBytes(16),
        generation: harness.store.generation,
      );

      expect((await harness.store.usage()).pageCount, 1);
    });
  });

  group('読み出しの失敗', () {
    // 掃除 / 手動削除が行を読んだ直後に実体を消すことがある。ここで投げると
    // ネットワークから取り直せる画像まで「読み込めませんでした」になる。
    test('実体が無い場合はキャッシュミスにする（メタ情報も捨てる）', () async {
      final harness = CacheHarness.create();
      await harness.write('v1/100/1', bytes: 100);
      final broken = harness.storeLike(BrokenFileCacheStore.new);

      expect(await broken.read('v1/100/1'), isNull);
      expect(
        (await harness.store.usage()).pageCount,
        0,
        reason: '無い実体のメタ情報を残すと使用量が実際より多く見える',
      );
    });

    // ロック / EMFILE / 権限などは一時的なことがある。実体はまだあるので、
    // ここで消すとダウンロード済みタイトルの表紙（保護印つき）まで失いうる。
    test('実体はあるが読めない場合はミスにするだけで消さない', () async {
      final harness = CacheHarness.create();
      await harness.write('v1/100/1', bytes: 100);
      final broken = BrokenFileCacheStore(
        database: harness.database,
        directories: harness.directories,
        settingsStore: harness.settingsStore,
        now: harness.clock.now,
        error: const FileSystemException('ファイルが使用中'),
      );

      expect(await broken.read('v1/100/1'), isNull);
      expect((await harness.store.usage()).pageCount, 1);
      expect(harness.hasFile('v1/100/1'), isTrue);
      expect(
        await harness.store.read('v1/100/1'),
        isNotNull,
        reason: '次に読めればそのまま使える',
      );
    });
  });

  group('掃除の直列化', () {
    // 掃除は全件走査なので、呼ばれた回数だけ積むと画像の読み出しが後ろで待たされる。
    // かといって 1 本にまとめきると、上限を下げた直後の掃除が古い設定で終わる。
    test('待っている掃除は 1 本にまとめる（設定は毎回読み直す）', () async {
      final harness = CacheHarness.create();
      final settings = _CountingSettingsStore(harness.database);
      final store = ImageCacheStore(
        database: harness.database,
        directories: harness.directories,
        settingsStore: settings,
        now: harness.clock.now,
      );

      await Future.wait([for (var i = 0; i < 5; i++) store.evictIfNeeded()]);

      expect(settings.reads, 2, reason: '走っている 1 本 + 後ろに並べた 1 本だけ走る');
    });
  });
}

/// [key] の最後に使った時刻（DB に入っている値）。
Future<DateTime> _lastUsedAt(CacheHarness harness, String key) async {
  final row = await (harness.database.select(
    harness.database.cachedImages,
  )..where((table) => table.key.equals(key))).getSingle();
  return row.lastUsedAt;
}

/// 掃除が何回走ったかを数える設定ストア（掃除 1 回につき 1 回読む）。
class _CountingSettingsStore extends CacheSettingsStore {
  _CountingSettingsStore(super.database);

  int reads = 0;

  @override
  Future<CacheSettings> read() {
    reads++;
    return super.read();
  }
}
