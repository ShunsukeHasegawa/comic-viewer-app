import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/api/user_api.dart';
import '../../../domain/models/reading_book.dart';
import '../../library/application/library_controller.dart';

part 'history_controller.freezed.dart';
part 'history_controller.g.dart';

/// 読書履歴（ページ送りで足していく）。
@freezed
abstract class HistoryState with _$HistoryState {
  const factory HistoryState({
    required List<HistoryEntry> entries,
    required int currentPage,
    required bool hasMore,

    /// 追加読み込み中。
    @Default(false) bool isLoadingMore,

    /// 追加読み込みが失敗したときのエラー（次の試行で消える）。
    Object? loadMoreError,
  }) = _HistoryState;
}

/// 読書履歴の読み込み（`GET /api/user-volume-status/history?page=`、1 ページ 10 件）。
@Riverpod(retry: noAutoRetry)
class HistoryController extends _$HistoryController {
  @override
  Future<HistoryState> build() {
    return _loadFirstPage();
  }

  Future<HistoryState> _loadFirstPage() async {
    final page = await ref.read(userApiProvider).fetchHistory();
    return HistoryState(
      entries: page.items,
      currentPage: page.currentPage,
      hasMore: page.hasMore,
    );
  }

  /// 先頭から読み直す。
  Future<void> refresh() async {
    final next = await AsyncValue.guard(_loadFirstPage);
    if (!ref.mounted) return;
    state = next;
  }

  /// 次のページを足す。失敗しても表示中の履歴は残す。
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    final api = ref.read(userApiProvider);
    state = AsyncValue.data(
      current.copyWith(isLoadingMore: true, loadMoreError: null),
    );
    try {
      final page = await api.fetchHistory(page: current.currentPage + 1);
      if (!ref.mounted) return;
      // 追加読み込み中にプルリフレッシュが完了していたら、その結果を
      // 古い内容で上書きしない（重複行や巻き戻りを防ぐ）。
      final latest = state.value;
      if (latest == null || latest.currentPage != current.currentPage) return;
      state = AsyncValue.data(
        latest.copyWith(
          entries: [...latest.entries, ...page.items],
          currentPage: page.currentPage,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } on Object catch (error) {
      if (!ref.mounted) return;
      final latest = state.value;
      if (latest == null || latest.currentPage != current.currentPage) return;
      // 表示中の履歴は残し、失敗は状態として持つ（例外は呼び出し側へ投げない。
      // ボタンの onPressed から未捕捉例外にしないため）。
      state = AsyncValue.data(
        latest.copyWith(isLoadingMore: false, loadMoreError: error),
      );
    }
  }
}
