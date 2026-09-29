import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/domain/models/read_volume.dart';
import 'package:comic_laz/domain/models/reading_book.dart';
import 'package:comic_laz/features/library/domain/library_snapshot.dart';
import 'package:comic_laz/features/offline/data/offline_catalog.dart';
import 'package:comic_laz/features/offline/data/offline_metadata_purger.dart';

import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';

import '../../support/offline_fakes.dart';

BookDetail _detail({int id = 12}) => BookDetail(
  id: id,
  title: '進撃の巨人',
  volumes: const [
    BookVolume(
      id: 340,
      volume: 1,
      thumbnail: '/books/thumbnail/340?m=7',
      filesVersion: 111,
      archiveBytes: 1000,
    ),
    BookVolume(id: 341, volume: 2, thumbnail: '/books/thumbnail/341?m=8'),
  ],
);

ReadVolume _volume({int id = 340}) => ReadVolume(
  id: id,
  volume: 1,
  files: const [0, 1, 2],
  filesVersion: 111,
  nextVolumeId: 341,
  nextVolumeThumbnail: '/books/thumbnail/341?m=8',
  book: const Book(id: 12, title: '進撃の巨人'),
);

void main() {
  group('一覧の永続化', () {
    test('保存した一覧と ETag はアプリを作り直しても読める（圏外起動）', () async {
      final first = createOfflineCatalog();
      await first.catalog.writeLibrary(
        LibrarySnapshot(
          books: [
            testBook(id: 1, title: 'A'),
            testBook(id: 2, title: 'B'),
          ],
          etag: '"v1"',
          fetchedAt: DateTime.utc(2026, 9, 20, 10),
          userStatus: const UserStatus(unreads: [1], favorites: [2]),
        ),
      );

      // 同じ DB を使う別インスタンス（= 再起動後）から読む。
      final second = createOfflineCatalog(cache: first.cache);
      final snapshot = await second.catalog.readLibrary();

      expect(snapshot?.books.map((book) => book.id), [1, 2]);
      expect(snapshot?.etag, '"v1"', reason: '次回 304 を狙うため ETag も残す');
      // drift は epoch 秒で持つので、戻りは端末のタイムゾーン。指す瞬間で比べる。
      expect(
        snapshot?.fetchedAt.isAtSameMomentAs(DateTime.utc(2026, 9, 20, 10)),
        isTrue,
      );
      expect(snapshot?.userStatus?.favorites, [2]);
    });

    test('壊れた JSON は「無い」として扱い、行を捨てる（起動を妨げない）', () async {
      final fixture = createOfflineCatalog();
      await fixture.cache.database
          .into(fixture.cache.database.offlineMetadataEntries)
          .insertOnConflictUpdate(
            OfflineMetadataRow(
              key: OfflineCatalog.libraryKey,
              payload: '{壊れている',
              fetchedAt: DateTime.utc(2026),
            ),
          );

      expect(await fixture.catalog.readLibrary(), isNull);
      expect(await fixture.store.read(OfflineCatalog.libraryKey), isNull);
    });
  });

  group('カテゴリ / タグ', () {
    test('保存して読み直せる（圏外でも絞り込みチップを出せる）', () async {
      final fixture = createOfflineCatalog();

      await fixture.catalog.writeCategories(const [
        Taxonomy(id: 1, name: '少年'),
      ]);
      await fixture.catalog.writeTags(const [Taxonomy(id: 9, name: 'アクション')]);

      expect((await fixture.catalog.readCategories())?.single.name, '少年');
      expect((await fixture.catalog.readTags())?.single.name, 'アクション');
    });

    test('保存していなければ null（既定値と区別する）', () async {
      final fixture = createOfflineCatalog();
      expect(await fixture.catalog.readCategories(), isNull);
    });
  });

  group('詳細 / 巻情報', () {
    test('詳細を保存すると巻のサムネイルに保護印が付く', () async {
      final fixture = createOfflineCatalog();
      // キーの組み立ては MediaUrls だけに任せる（テストでも組み立て直さない）。
      final urls = fixture.urls;

      await fixture.catalog.writeBookDetail(_detail());

      expect(
        await fixture.cache.store.pinnedKeys(),
        containsAll([
          urls.thumbnailCacheKey('/books/thumbnail/340?m=7'),
          urls.thumbnailCacheKey('/books/thumbnail/341?m=8'),
        ]),
      );
    });

    test('巻情報を保存すると次巻サムネイルも保護される（巻末オーバーレイ）', () async {
      final fixture = createOfflineCatalog();

      await fixture.catalog.writeVolume(_volume());

      final restored = await fixture.catalog.readVolume(340);
      expect(restored?.files, [0, 1, 2]);
      expect(restored?.filesVersion, 111);
      expect(restored?.nextVolumeId, 341);
      expect(await fixture.cache.store.pinnedKeys(), hasLength(1));
    });
  });

  group('掃除', () {
    test('ダウンロードが無くなったタイトル / 巻の控えと保護印を捨てる', () async {
      final fixture = createOfflineCatalog();
      await fixture.catalog.writeBookDetail(_detail());
      await fixture.catalog.writeVolume(_volume());
      await fixture.catalog.writeLibrary(
        LibrarySnapshot(
          books: [testBook(id: 12)],
          fetchedAt: DateTime.utc(2026),
        ),
      );

      await fixture.catalog.retain(bookIds: const {}, volumeIds: const {});

      expect(await fixture.catalog.readBookDetail(12), isNull);
      expect(await fixture.catalog.readVolume(340), isNull);
      expect(await fixture.cache.store.pinnedKeys(), isEmpty);
      expect(
        await fixture.catalog.readLibrary(),
        isNotNull,
        reason: '一覧は残す（圏外起動で真っ白にしない）',
      );
    });

    test('ダウンロードが残っているものは消さない', () async {
      final fixture = createOfflineCatalog();
      await fixture.catalog.writeBookDetail(_detail());
      await fixture.catalog.writeVolume(_volume());

      await fixture.catalog.retain(bookIds: {12}, volumeIds: {340});

      expect(await fixture.catalog.readBookDetail(12), isNotNull);
      expect(await fixture.catalog.readVolume(340), isNotNull);
      expect(await fixture.cache.store.pinnedKeys(), isNotEmpty);
    });
  });

  group('セーフモード / ユーザー切り替え', () {
    // セーフモードはサーバー側が正なので `is_unsafe` の巻は端末に無い。
    // ただし前のユーザー / 前の設定で取った一覧・詳細は端末に残るので、
    // 破棄しないとオフラインでそのまま見えてしまう。
    test('破棄するとオフラインの控えは 1 つも残らない', () async {
      final fixture = createOfflineCatalog();
      await fixture.catalog.writeLibrary(
        LibrarySnapshot(
          books: [testBook(id: 12, title: 'R18 のタイトル')],
          fetchedAt: DateTime.utc(2026),
        ),
      );
      await fixture.catalog.writeBookDetail(_detail());
      await fixture.catalog.writeVolume(_volume());

      await OfflineMetadataPurger(fixture.catalog).purgeSessionData();

      expect(await fixture.catalog.readLibrary(), isNull);
      expect(await fixture.catalog.readBookDetail(12), isNull);
      expect(await fixture.catalog.readVolume(340), isNull);
      expect(await fixture.cache.store.pinnedKeys(), isEmpty);
    });
  });

  group('保護印と LRU', () {
    test('保護した画像は上限超過でも消えない（ダウンロード済みタイトルの表紙）', () async {
      final fixture = createOfflineCatalog();
      final cache = fixture.cache;
      await fixture.catalog.writeBookDetail(_detail());
      final pinned = (await cache.store.pinnedKeys()).first;

      // 保護対象を一番古く使ったものにしておく（本来なら最初に消える）。
      await cache.record(pinned, bytes: 100, kind: CachedImageKind.thumbnail);
      await cache.record(
        'other',
        bytes: 100,
        kind: CachedImageKind.thumbnail,
        after: const Duration(minutes: 1),
      );

      await cache.store.evictToLimit(CachedImageKind.thumbnail, 100);

      expect(await cache.keysByLastUsed(), [pinned]);
    });
  });
}
