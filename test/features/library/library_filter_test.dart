import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/features/library/domain/library_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';

void main() {
  final books = [
    testBook(
      id: 1,
      title: '古い作品',
      kana: 'ふるいさくひん',
      volumeAddedAt: DateTime.utc(2026, 1, 1),
      categories: [1],
      tags: [10],
      isComplete: true,
    ),
    testBook(
      id: 2,
      title: '新しい作品',
      kana: 'あたらしいさくひん',
      volumeAddedAt: DateTime.utc(2026, 9, 1),
      categories: [2],
      tags: [11],
    ),
    testBook(id: 3, title: '日付なし', kana: 'ひづけなし', categories: [1, 2]),
  ];

  List<int> apply(
    LibraryFilter filter, {
    Set<int> favoriteIds = const {},
    Set<int> unreadIds = const {},
  }) => applyLibraryFilter(
    candidates: books,
    filter: filter,
    favoriteIds: favoriteIds,
    unreadIds: unreadIds,
  ).map((b) => b.id).toList();

  group('並び替え', () {
    test('更新日は新しい順、日付なしは末尾', () {
      expect(apply(const LibraryFilter()), [2, 1, 3]);
    });

    test('五十音は kana 昇順', () {
      // あたらしいさくひん < ひづけなし < ふるいさくひん
      expect(apply(const LibraryFilter(sort: LibrarySort.kana)), [2, 3, 1]);
    });

    test('kana が無ければタイトルで比較する', () {
      final sorted = applyLibraryFilter(
        candidates: [
          testBook(id: 1, title: 'ん'),
          testBook(id: 2, title: 'あ'),
        ],
        filter: const LibraryFilter(sort: LibrarySort.kana),
        favoriteIds: const {},
        unreadIds: const {},
      );

      expect(sorted.map((b) => b.id), [2, 1]);
    });
  });

  group('絞り込み', () {
    test('お気に入り', () {
      expect(
        apply(const LibraryFilter(onlyFavorites: true), favoriteIds: {2}),
        [2],
      );
    });

    test('未読', () {
      expect(apply(const LibraryFilter(onlyUnread: true), unreadIds: {1, 3}), [
        1,
        3,
      ]);
    });

    test('完結', () {
      expect(apply(const LibraryFilter(onlyComplete: true)), [1]);
    });

    test('カテゴリは OR', () {
      expect(apply(const LibraryFilter(categoryIds: {1})), [1, 3]);
      expect(apply(const LibraryFilter(categoryIds: {1, 2})), [2, 1, 3]);
    });

    test('タグは OR', () {
      expect(apply(const LibraryFilter(tagIds: {11})), [2]);
    });

    test('条件は AND で重なる', () {
      expect(apply(const LibraryFilter(categoryIds: {1}, onlyComplete: true)), [
        1,
      ]);
    });

    test('ダウンロード済みのみ', () {
      final result = applyLibraryFilter(
        candidates: books,
        filter: const LibraryFilter(onlyDownloaded: true),
        favoriteIds: const {},
        unreadIds: const {},
        downloadedIds: const {3},
      );

      expect(result.map((b) => b.id), [3]);
    });

    // 圏外では読めるものだけを出す（#11）。ユーザーが触っていない状態
    // （未指定）のときだけ既定を当てる。
    test('未指定ならオフラインのときだけダウンロード済みに絞る', () {
      List<Book> visible({required bool isOffline}) => applyLibraryFilter(
        candidates: books,
        filter: const LibraryFilter(),
        favoriteIds: const {},
        unreadIds: const {},
        downloadedIds: const {3},
        isOffline: isOffline,
      );

      expect(visible(isOffline: true).map((b) => b.id), [3]);
      expect(visible(isOffline: false), hasLength(books.length));
    });

    test('明示的に OFF にしたらオフラインでも全部出す', () {
      final result = applyLibraryFilter(
        candidates: books,
        filter: const LibraryFilter(onlyDownloaded: false),
        favoriteIds: const {},
        unreadIds: const {},
        downloadedIds: const {3},
        isOffline: true,
      );

      expect(result, hasLength(books.length));
    });

    test('オフラインの既定 ON は「絞り込み中」に数えない（解除の表示）', () {
      expect(const LibraryFilter().hasActiveFilters, isFalse);
      expect(
        const LibraryFilter(onlyDownloaded: true).hasActiveFilters,
        isTrue,
      );
    });
  });

  group('五十音の正規化', () {
    test('カタカナの読みもひらがなと同じ位置に並ぶ', () {
      final sorted = applyLibraryFilter(
        candidates: [
          testBook(id: 1, title: 'ワンピース', kana: 'ワンピース'),
          testBook(id: 2, title: 'あいうえお', kana: 'あいうえお'),
          testBook(id: 3, title: 'なにぬねの', kana: 'なにぬねの'),
        ],
        filter: const LibraryFilter(sort: LibrarySort.kana),
        favoriteIds: const {},
        unreadIds: const {},
      );

      expect(sorted.map((b) => b.id), [
        2,
        3,
        1,
      ], reason: 'あ < な < わ（コード順だとカタカナが最後に固まる）');
    });
  });

  group('hasActiveFilters', () {
    test('検索語だけなら false（絞り込みではない）', () {
      expect(const LibraryFilter(query: '巨人').hasActiveFilters, isFalse);
    });

    test('チップが選ばれていれば true', () {
      expect(const LibraryFilter(onlyUnread: true).hasActiveFilters, isTrue);
      expect(const LibraryFilter(categoryIds: {1}).hasActiveFilters, isTrue);
      expect(const LibraryFilter(tagIds: {1}).hasActiveFilters, isTrue);
    });
  });
}
