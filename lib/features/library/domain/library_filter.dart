import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/models/book.dart';
import 'book_search_index.dart';

part 'library_filter.freezed.dart';

/// 並び替え方法。
enum LibrarySort {
  /// 更新日（新しい巻が追加された順）。
  updated,

  /// 五十音（`kana`）。
  kana;

  String get label => switch (this) {
    LibrarySort.updated => '更新日',
    LibrarySort.kana => '五十音',
  };
}

/// 一覧の表示形式。
enum LibraryViewMode {
  grid,
  list;

  LibraryViewMode get toggled => this == LibraryViewMode.grid
      ? LibraryViewMode.list
      : LibraryViewMode.grid;
}

/// 絞り込み条件（Web 版のチップ相当）。
@freezed
abstract class LibraryFilter with _$LibraryFilter {
  const factory LibraryFilter({
    @Default('') String query,
    @Default({}) Set<int> categoryIds,
    @Default({}) Set<int> tagIds,
    @Default(false) bool onlyFavorites,
    @Default(false) bool onlyUnread,
    @Default(false) bool onlyComplete,

    /// ダウンロード済みのみ表示。
    ///
    /// `null` は**未指定**で、オフライン（サーバーに確認できない）なら ON として
    /// 扱う（#11）。「既定 ON」を状態として書き込まないのは、圏外で開いたあとに
    /// オンラインへ戻ったときに、ユーザーが触っていない絞り込みが残って
    /// 「本が減った」ように見えるのを避けるため。
    bool? onlyDownloaded,
    @Default(LibrarySort.updated) LibrarySort sort,
  }) = _LibraryFilter;

  const LibraryFilter._();

  /// ダウンロード済みのみ表示するか（未指定はオフラインのときだけ ON）。
  bool onlyDownloadedWhen({required bool isOffline}) =>
      onlyDownloaded ?? isOffline;

  /// 何らかの絞り込みが有効か（「絞り込みを解除」の表示判定に使う）。
  ///
  /// オフラインの既定 ON は「ユーザーが掛けた絞り込み」ではないので数えない。
  bool get hasActiveFilters =>
      categoryIds.isNotEmpty ||
      tagIds.isNotEmpty ||
      onlyFavorites ||
      onlyUnread ||
      onlyComplete ||
      (onlyDownloaded ?? false);
}

/// 絞り込みと並び替えを一覧へ適用する。
///
/// 検索（部分一致）は [candidates] を作る側で済ませておく。
List<Book> applyLibraryFilter({
  required List<Book> candidates,
  required LibraryFilter filter,
  required Set<int> favoriteIds,
  required Set<int> unreadIds,
  Set<int> downloadedIds = const {},
  bool isOffline = false,
}) {
  final onlyDownloaded = filter.onlyDownloadedWhen(isOffline: isOffline);
  final filtered = [
    for (final book in candidates)
      if (_matches(
        book: book,
        filter: filter,
        favoriteIds: favoriteIds,
        unreadIds: unreadIds,
        downloadedIds: downloadedIds,
        onlyDownloaded: onlyDownloaded,
      ))
        book,
  ];

  filtered.sort(_comparatorFor(filter.sort));
  return filtered;
}

bool _matches({
  required Book book,
  required LibraryFilter filter,
  required Set<int> favoriteIds,
  required Set<int> unreadIds,
  required Set<int> downloadedIds,
  required bool onlyDownloaded,
}) {
  if (filter.onlyFavorites && !favoriteIds.contains(book.id)) return false;
  if (filter.onlyUnread && !unreadIds.contains(book.id)) return false;
  if (filter.onlyComplete && !book.isComplete) return false;
  if (onlyDownloaded && !downloadedIds.contains(book.id)) return false;
  // カテゴリ / タグは「いずれかに一致」（Web 版と同じ OR）。
  if (filter.categoryIds.isNotEmpty &&
      !book.categories.any(filter.categoryIds.contains)) {
    return false;
  }
  if (filter.tagIds.isNotEmpty && !book.tags.any(filter.tagIds.contains)) {
    return false;
  }
  return true;
}

int Function(Book, Book) _comparatorFor(LibrarySort sort) => switch (sort) {
  // 新しい順。日付が無い書籍は末尾へ。
  LibrarySort.updated => (a, b) {
    final left = a.volumeAddedAt;
    final right = b.volumeAddedAt;
    if (left == null && right == null) return _compareKana(a, b);
    if (left == null) return 1;
    if (right == null) return -1;
    final byDate = right.compareTo(left);
    return byDate != 0 ? byDate : _compareKana(a, b);
  },
  LibrarySort.kana => _compareKana,
};

/// かなで比較する。`kana` が無ければタイトルで代替。
///
/// サーバーの `kana` はカタカナで入っていることがあるため、検索と同じ正規化
/// （カタカナ → ひらがな）をしてから比べる。生のコード順で比べると、
/// カタカナの読みが常にひらがなの後ろに並んでしまう。
int _compareKana(Book a, Book b) {
  final byKana = _sortKeyOf(a).compareTo(_sortKeyOf(b));
  return byKana != 0 ? byKana : a.id.compareTo(b.id);
}

String _sortKeyOf(Book book) => BookSearchIndex.normalize(
  (book.kana?.isNotEmpty ?? false) ? book.kana! : book.title,
);
