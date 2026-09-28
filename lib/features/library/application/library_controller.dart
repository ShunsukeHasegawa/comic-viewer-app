import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/api/taxonomy_api.dart';
import '../../../data/api/user_api.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/reading_book.dart';
import '../data/library_repository.dart';
import '../domain/book_search_index.dart';
import '../domain/library_filter.dart';

part 'library_controller.freezed.dart';
part 'library_controller.g.dart';

/// ライブラリ画面が表示に使うデータ一式。
@freezed
abstract class LibraryData with _$LibraryData {
  const factory LibraryData({
    required List<Book> books,
    required Set<int> favoriteIds,
    required Set<int> unreadIds,
    required List<ReadingBook> reading,
    required List<Taxonomy> categories,
    required List<Taxonomy> tags,
    required BookSearchIndex searchIndex,
    required DateTime fetchedAt,

    /// サーバーに確認できず手元の内容を表示している（圏外など）。
    @Default(false) bool isStale,
  }) = _LibraryData;
}

/// 自動リトライを無効にする。
///
/// Riverpod は失敗した provider を指数バックオフで再実行するが、自宅サーバー
/// （HDD）を叩き続けたくないので、再試行はユーザー操作（プルリフレッシュ /
/// 「再試行」ボタン）に限る。
Duration? noAutoRetry(int retryCount, Object error) => null;

/// ライブラリ一覧の読み込み。
@Riverpod(retry: noAutoRetry)
class LibraryController extends _$LibraryController {
  @override
  Future<LibraryData> build() {
    return _load();
  }

  /// プルリフレッシュ。`If-None-Match` を送らず必ず取り直す。
  Future<void> refresh() async {
    // RefreshIndicator 側が進行表示を出すので loading 状態にはしない
    // （表示中の一覧を消さない）。
    final next = await AsyncValue.guard(() => _load(forceRefresh: true));
    // 401 → ログイン画面へ戻る途中で破棄されていることがある。
    if (!ref.mounted) return;
    state = next;
  }

  Future<LibraryData> _load({bool forceRefresh = false}) async {
    // await を挟んだ後に ref を触らないよう、依存はここで解決しておく
    // （読み込み中に画面が破棄されても例外にしない）。
    final repository = ref.read(libraryRepositoryProvider);
    final userApi = ref.read(userApiProvider);
    final taxonomyApi = ref.read(taxonomyApiProvider);
    final previous = state.value;

    final result = await repository.loadBooks(forceRefresh: forceRefresh);

    // 「続きを読む」と絞り込み用のカテゴリ / タグは取れなくても一覧は出す。
    // 取れなかった場合は**前回の内容を残す**（チップが消えて絞り込みを
    // 解除できなくなるのを防ぐ）。
    final reading = await _tolerate(
      userApi.fetchReading,
      previous?.reading ?? const <ReadingBook>[],
    );
    final categories = await _tolerate(
      taxonomyApi.fetchCategories,
      previous?.categories ?? const <Taxonomy>[],
    );
    final tags = await _tolerate(
      taxonomyApi.fetchTags,
      previous?.tags ?? const <Taxonomy>[],
    );

    return LibraryData(
      books: result.books,
      favoriteIds: result.userStatus.favorites.toSet(),
      unreadIds: result.userStatus.unreads.toSet(),
      reading: reading,
      categories: categories,
      tags: tags,
      searchIndex: BookSearchIndex.build(result.books),
      fetchedAt: result.fetchedAt,
      isStale: result.isStale,
    );
  }

  /// お気に入りの切り替えを一覧側へ反映する（再取得しない）。
  void setFavorite({required int bookId, required bool isFavorite}) {
    final current = state.value;
    if (current == null) return;
    final favorites = current.favoriteIds.toSet();
    if (isFavorite) {
      favorites.add(bookId);
    } else {
      favorites.remove(bookId);
    }
    state = AsyncValue.data(current.copyWith(favoriteIds: favorites));
    // オフライン用のキャッシュにも反映する（次に開いたときに消えないように）。
    ref
        .read(libraryRepositoryProvider)
        .updateCachedFavorite(bookId: bookId, isFavorite: isFavorite);
  }

  /// 補助的な取得。通信・サーバー起因の失敗は既定値で代替する。
  Future<T> _tolerate<T>(Future<T> Function() task, T fallback) async {
    try {
      return await task();
    } on UnauthorizedException {
      // セッション失効は隠さない（インターセプタがログイン画面へ戻す）。
      rethrow;
    } on ApiException {
      return fallback;
    }
  }
}

/// 絞り込み / 並び替えの状態。
@riverpod
class LibraryFilterController extends _$LibraryFilterController {
  @override
  LibraryFilter build() => const LibraryFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setSort(LibrarySort sort) => state = state.copyWith(sort: sort);

  void toggleCategory(int id) =>
      state = state.copyWith(categoryIds: _toggled(state.categoryIds, id));

  void toggleTag(int id) =>
      state = state.copyWith(tagIds: _toggled(state.tagIds, id));

  void toggleFavorites() =>
      state = state.copyWith(onlyFavorites: !state.onlyFavorites);

  void toggleUnread() => state = state.copyWith(onlyUnread: !state.onlyUnread);

  void toggleComplete() =>
      state = state.copyWith(onlyComplete: !state.onlyComplete);

  /// 検索語以外の絞り込みを解除する。
  void clearFilters() =>
      state = LibraryFilter(query: state.query, sort: state.sort);

  static Set<int> _toggled(Set<int> current, int id) => current.contains(id)
      ? (current.toSet()..remove(id))
      : (current.toSet()..add(id));
}

/// 表示形式（グリッド / リスト）。
@riverpod
class LibraryViewModeController extends _$LibraryViewModeController {
  @override
  LibraryViewMode build() => LibraryViewMode.grid;

  void toggle() => state = state.toggled;
}

/// 検索・絞り込み・並び替えを適用した一覧。
@riverpod
List<Book> visibleBooks(Ref ref) {
  final data = ref.watch(libraryControllerProvider).value;
  if (data == null) return const [];

  final filter = ref.watch(libraryFilterControllerProvider);
  return applyLibraryFilter(
    candidates: data.searchIndex.search(filter.query),
    filter: filter,
    favoriteIds: data.favoriteIds,
    unreadIds: data.unreadIds,
  );
}
