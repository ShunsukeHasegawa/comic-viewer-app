import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/router/open_volume.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/thumbnail_image.dart';
import '../../../domain/models/reading_book.dart';
import '../../library/presentation/widgets/book_tiles.dart';
import '../application/history_controller.dart';

/// 読書履歴画面。
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);
    final data = async.value;

    return Scaffold(
      appBar: AppBar(title: const Text('履歴')),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context, ref),
        child: switch ((data, async.error)) {
          (null, final error?) => ErrorView(
            error: error,
            onRetry: controller.refresh,
          ),
          (null, null) => const Center(child: CircularProgressIndicator()),
          (final data?, _) => _HistoryList(
            state: data,
            onLoadMore: controller.loadMore,
          ),
        },
      ),
    );
  }
}

/// 再取得し、失敗したら（履歴は残るので）その場で知らせる。
Future<void> _refresh(BuildContext context, WidgetRef ref) async {
  await ref.read(historyControllerProvider.notifier).refresh();
  final error = ref.read(historyControllerProvider).error;
  if (error == null || !context.mounted) return;
  showRefreshFailure(context, error, what: '履歴');
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.state, required this.onLoadMore});

  final HistoryState state;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.entries.isEmpty) {
      return const CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyView(message: 'まだ読書履歴がありません。'),
          ),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // 末尾が近づいたら次のページを読む。
        // 失敗した直後は自動で叩き直さない（明示的な「再試行」に任せる。
        // 自宅サーバーへの連打を避けるため）。
        if (state.loadMoreError != null) return false;
        final metrics = notification.metrics;
        if (metrics.axis == Axis.vertical &&
            metrics.pixels >= metrics.maxScrollExtent - 320) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        // 末尾の 1 行は「読み込み中」か「もっと読み込む」。
        itemCount: state.entries.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= state.entries.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (state.loadMoreError case final error?) ...[
                    Text(
                      apiErrorMessage(error),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Center(
                    child: state.isLoadingMore
                        ? const CircularProgressIndicator()
                        // 画面に収まってスクロールが起きない場合でも次を読めるように、
                        // 明示的なボタンを置く。
                        : OutlinedButton(
                            onPressed: onLoadMore,
                            child: Text(
                              state.loadMoreError == null ? 'もっと読み込む' : '再試行',
                            ),
                          ),
                  ),
                ],
              ),
            );
          }
          return _HistoryTile(entry: state.entries[index]);
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      // 閉じたらタイトル詳細へ戻す（#21）。
      onTap: () =>
          pushVolumeViaTitle(context, bookId: entry.bookId, volumeId: entry.id),
      leading: SizedBox(
        width: 40,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: ThumbnailImage(
            apiUrl: entry.thumbnail,
            aspectRatio: bookCoverAspectRatio,
          ),
        ),
      ),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          '${entry.volume} 巻',
          if (entry.isFinished)
            '読了'
          else
            '${entry.currentPage} / ${entry.maxPage} ページ',
          if (entry.updatedAt case final updatedAt?) formatDateTime(updatedAt),
        ].join('・'),
        style: theme.textTheme.bodySmall,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.menu_book_outlined),
        tooltip: 'この巻の詳細',
        onPressed: () => context.push(AppRoutes.bookDetail(entry.bookId)),
      ),
    );
  }
}
