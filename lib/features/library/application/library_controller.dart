import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/device/connectivity_monitor.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/api/taxonomy_api.dart';
import '../../../data/api/user_api.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/reading_book.dart';
import '../../downloads/application/downloaded_lookup.dart';
import '../../offline/application/offline_metadata_gateway.dart';
import '../../progress/data/progress_store.dart';
import '../../progress/domain/reading_progress.dart';
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
  /// 進行中の読み込み。
  ///
  /// ネットワーク復帰の合図は**購読した瞬間にも流れる**（`connectivity_plus` の
  /// `onConnectivityChanged` は購読時に現在の接続状態を 1 件流す）。初回ロードの
  /// 最中に 2 本目を走らせると、`/api/books` などを ETag 無しで二重に叩いてしまい
  /// （どちらもキャッシュ書き込み前に読むので `If-None-Match` を送れない）、
  /// 後から終わった方が古い結果で上書きしかねない（#11 のレビュー指摘）。
  Future<LibraryData>? _loading;

  @override
  Future<LibraryData> build() {
    // ネットワーク復帰で自動的に最新化する（#12 の監視を使い回す）。
    // 一覧を表示している間だけ購読する（autoDispose）。
    final subscription = ref
        .read(connectivityMonitorProvider)
        .onRestored
        .listen((_) => unawaited(refreshIfStale()));
    ref.onDispose(subscription.cancel);
    return _track(_load());
  }

  /// プルリフレッシュ。`If-None-Match` を送らず必ず取り直す。
  Future<void> refresh() async {
    // RefreshIndicator 側が進行表示を出すので loading 状態にはしない
    // （表示中の一覧を消さない）。
    final next = await AsyncValue.guard(
      () => _track(_load(forceRefresh: true)),
    );
    // 401 → ログイン画面へ戻る途中で破棄されていることがある。
    if (!ref.mounted) return;
    state = next;
  }

  /// 圏外の内容を表示しているときだけ取り直す（ネットワーク復帰時）。
  ///
  /// `If-None-Match` は送る（変わっていなければ 304 で済み、自宅サーバーに
  /// 一覧の JSON を作り直させない）。最新を表示しているなら何もしない。
  Future<void> refreshIfStale() async {
    if (!ref.mounted) return;
    // 進行中のロードがあるなら、その結果を見てから決める（まだ結果が無い状態を
    // 「圏外」と同じに扱わない）。復帰の合図より前に始まったロードが圏外の内容で
    // 終わった場合は、このあとの判定で改めて取り直しに行く。
    var pending = _loading;
    while (pending != null) {
      try {
        await pending;
      } on Object {
        // 失敗の扱いは走らせた側（`build` / `refresh`）が済ませている。
      }
      if (!ref.mounted) return;
      pending = _loading;
    }

    final current = state.value;
    if (current != null && !current.isStale) return;
    final next = await AsyncValue.guard(() => _track(_load()));
    if (!ref.mounted) return;
    state = next;
  }

  /// 進行中の読み込みとして覚えておく（[refreshIfStale] が二重に走らせないため）。
  Future<LibraryData> _track(Future<LibraryData> task) {
    _loading = task;
    unawaited(_forget(task));
    return task;
  }

  Future<void> _forget(Future<LibraryData> task) async {
    try {
      await task;
    } on Object {
      // 結果は呼び出し側が state に入れる。ここでは終わったことだけを見る。
    }
    // 後から始まったロードを消さない（Notifier は再構築でも使い回される）。
    if (identical(_loading, task)) _loading = null;
  }

  Future<LibraryData> _load({bool forceRefresh = false}) async {
    // await を挟んだ後に ref を触らないよう、依存はここで解決しておく
    // （読み込み中に画面が破棄されても例外にしない）。
    final repository = ref.read(libraryRepositoryProvider);
    final userApi = ref.read(userApiProvider);
    final taxonomyApi = ref.read(taxonomyApiProvider);
    final progressStore = ref.read(progressStoreProvider);
    final offline = ref.read(offlineMetadataGatewayProvider);
    final previous = state.value;

    final result = await repository.loadBooks(forceRefresh: forceRefresh);

    // 「続きを読む」と絞り込み用のカテゴリ / タグは取れなくても一覧は出す。
    // 取れなかった場合は**前回の内容を残す**（チップが消えて絞り込みを
    // 解除できなくなるのを防ぐ）。カテゴリ / タグは端末にも控えてあるので、
    // 再起動直後の圏外でも絞り込みチップを出せる（#11）。
    // 3 つは互いに独立しているので同時に始める（順に待つと往復の分だけ
    // 一覧の表示が遅れる。#28）。失敗時の代替は取得ごとに今まで通り。
    final readingTask = _tolerate(
      userApi.fetchReading,
      previous?.reading ?? const <ReadingBook>[],
    );
    final categoriesTask = _taxonomy(
      fetch: taxonomyApi.fetchCategories,
      read: offline.readCategories,
      write: offline.saveCategories,
      previous: previous?.categories,
    );
    final tagsTask = _taxonomy(
      fetch: taxonomyApi.fetchTags,
      read: offline.readTags,
      write: offline.saveTags,
      previous: previous?.tags,
    );
    // 全部の終わりを待ってから投げる（セッション失効などで 1 つが投げても、
    // 残りの失敗を未処理のエラーにしない）。
    await Future.wait([readingTask, categoriesTask, tagsTask]);
    final reading = await readingTask;
    final categories = await categoriesTask;
    final tags = await tagsTask;

    // ダウンロードが消えたタイトル / 巻の控えを片付ける。一覧の読み込みは
    // 起動時と明示的な更新で必ず通るので、掃除の契機としてここに置く。
    // 失敗しても一覧は出す（次の読み込みでやり直す）。
    try {
      await offline.prune();
    } on Object {
      // 何もしない。
    }

    // オフラインで読み進めた巻は、サーバーの値のままだと読む前のページを指す。
    // 未送信のローカル進捗があればそれを優先する（#12）。
    final local = await _localProgress(progressStore);

    return LibraryData(
      books: result.books,
      favoriteIds: result.userStatus.favorites.toSet(),
      unreadIds: result.userStatus.unreads.toSet(),
      reading: applyLocalProgress(reading, local),
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
    // 表示は済んでいるので待たない。失敗しても表示は正しい（次の取得で直る）。
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .updateCachedFavorite(bookId: bookId, isFavorite: isFavorite)
          .catchError((Object _) {}),
    );
  }

  /// カテゴリ / タグを取得する。取れなければ「前回の内容 → 端末の控え」の順で代替。
  Future<List<Taxonomy>> _taxonomy({
    required Future<List<Taxonomy>> Function() fetch,
    required Future<List<Taxonomy>?> Function() read,
    required Future<void> Function(List<Taxonomy>) write,
    required List<Taxonomy>? previous,
  }) async {
    try {
      final items = await fetch();
      // 控えの書き込みに失敗しても絞り込みは出せる（次の取得で書き直される）。
      try {
        await write(items);
      } on Object {
        // 何もしない。
      }
      return items;
    } on UnauthorizedException {
      rethrow;
    } on ApiException {
      if (previous != null && previous.isNotEmpty) return previous;
      try {
        return await read() ?? const [];
      } on Object {
        return const [];
      }
    }
  }

  /// 端末に貯めた進捗。読めなくても一覧は出す（表示の補正にしか使わない）。
  Future<Map<int, ReadingProgress>> _localProgress(ProgressStore store) async {
    try {
      return await store.loadAll();
    } on Object {
      return const {};
    }
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

  /// ダウンロード済みのみ表示を切り替える（#11）。
  ///
  /// [isOffline] は「いま既定で ON になっているか」を決めるため必要。
  /// 未指定（`null`）のままだと、圏外で ON に見えているものをもう一度押しても
  /// ON のままになってしまう。
  void toggleDownloaded({required bool isOffline}) => state = state.copyWith(
    onlyDownloaded: !state.onlyDownloadedWhen(isOffline: isOffline),
  );

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
  // サーバーに確認できていない = オフライン。OS の接続状態ではなく実際の通信
  // 結果で判断する（接続があっても自宅サーバーに届かないことがある）。
  final isOffline = data.isStale;

  // ダウンロード状態を見るのは絞り込みに使うときだけ。常に watch すると、
  // 取得中の進捗が更新されるたびに一覧全体の絞り込みと並び替えが走る。
  final downloadedIds = filter.onlyDownloadedWhen(isOffline: isOffline)
      ? ref.watch(downloadedBookIdsProvider)
      : const <int>{};

  return applyLibraryFilter(
    candidates: data.searchIndex.search(filter.query),
    filter: filter,
    favoriteIds: data.favoriteIds,
    unreadIds: data.unreadIds,
    downloadedIds: downloadedIds,
    isOffline: isOffline,
  );
}
