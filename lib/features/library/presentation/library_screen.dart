import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../../../domain/models/book.dart';
import '../application/library_controller.dart';
import '../domain/library_filter.dart';
import 'widgets/book_tiles.dart';
import 'widgets/continue_reading_carousel.dart';
import 'widgets/library_filter_bar.dart';

/// ライブラリ（書籍一覧）画面。
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(libraryControllerProvider);
    final data = async.value;

    // 一覧を表示したままの再取得が失敗した場合（エラー表示に切り替わらない）は
    // 黙って古い内容を見せ続けないよう、その場で知らせる。
    ref.listen(libraryControllerProvider, (previous, next) {
      if (!next.hasError || !next.hasValue || next.isLoading) return;
      if (previous?.error == next.error) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(content: Text('更新できませんでした: ${apiErrorMessage(next.error!)}')),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const _SearchField(),
        titleSpacing: 8,
        actions: const [_SortMenuButton(), _ViewModeButton()],
      ),
      body: RefreshIndicator(
        onRefresh: ref.read(libraryControllerProvider.notifier).refresh,
        child: switch ((data, async.error)) {
          // 手元に何も無い状態での失敗だけエラー表示にする。
          (null, final error?) => ErrorView(
            error: error,
            onRetry: ref.read(libraryControllerProvider.notifier).refresh,
          ),
          (null, null) => const Center(child: CircularProgressIndicator()),
          (final data?, _) => _LibraryBody(data: data),
        },
      ),
    );
  }
}

class _LibraryBody extends ConsumerWidget {
  const _LibraryBody({required this.data});

  final LibraryData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(visibleBooksProvider);
    final filter = ref.watch(libraryFilterControllerProvider);
    final viewMode = ref.watch(libraryViewModeControllerProvider);

    return CustomScrollView(
      // 件数が少なくてもプルリフレッシュできるようにする。
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (data.isStale) const SliverToBoxAdapter(child: _OfflineBanner()),
        if (filter.query.isEmpty && !filter.hasActiveFilters)
          SliverToBoxAdapter(
            child: ContinueReadingCarousel(items: data.reading),
          ),
        SliverToBoxAdapter(
          child: LibraryFilterBar(categories: data.categories, tags: data.tags),
        ),
        SliverToBoxAdapter(child: _ResultCount(count: books.length)),
        if (books.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyView(
              message: data.books.isEmpty
                  ? '表示できる書籍がありません。'
                  : '条件に一致する書籍がありません。',
              actionLabel: filter.hasActiveFilters ? '絞り込みを解除' : null,
              onAction: filter.hasActiveFilters
                  ? ref
                        .read(libraryFilterControllerProvider.notifier)
                        .clearFilters
                  : null,
            ),
          )
        else if (viewMode == LibraryViewMode.grid)
          _BookGrid(books: books, data: data)
        else
          _BookList(books: books, data: data),
      ],
    );
  }
}

class _BookGrid extends StatelessWidget {
  const _BookGrid({required this.books, required this.data});

  final List<Book> books;
  final LibraryData data;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // 表紙 + タイトル 2 行 + 巻数
          childAspectRatio: 0.52,
        ),
        delegate: SliverChildBuilderDelegate(childCount: books.length, (
          context,
          index,
        ) {
          final book = books[index];
          return BookGridTile(
            book: book,
            isFavorite: data.favoriteIds.contains(book.id),
            isUnread: data.unreadIds.contains(book.id),
          );
        }),
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  const _BookList({required this.books, required this.data});

  final List<Book> books;
  final LibraryData data;

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: books.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final book = books[index];
        return BookListTile(
          book: book,
          isFavorite: data.favoriteIds.contains(book.id),
          isUnread: data.unreadIds.contains(book.id),
        );
      },
    );
  }
}

/// 検索欄。索引はメモリ上なので入力ごとに絞り込んでよい。
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(libraryFilterControllerProvider).query;
    // 「絞り込みを解除」などで外から変わった場合に追従する。
    if (_controller.text != query) {
      _controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'タイトル・著者で検索',
        border: InputBorder.none,
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                tooltip: '検索をクリア',
                onPressed: () => ref
                    .read(libraryFilterControllerProvider.notifier)
                    .setQuery(''),
              ),
      ),
      onChanged: ref.read(libraryFilterControllerProvider.notifier).setQuery,
    );
  }
}

class _SortMenuButton extends ConsumerWidget {
  const _SortMenuButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(libraryFilterControllerProvider).sort;
    return PopupMenuButton<LibrarySort>(
      icon: const Icon(Icons.sort),
      tooltip: '並び替え',
      initialValue: sort,
      onSelected: ref.read(libraryFilterControllerProvider.notifier).setSort,
      itemBuilder: (context) => [
        for (final value in LibrarySort.values)
          PopupMenuItem(value: value, child: Text(value.label)),
      ],
    );
  }
}

class _ViewModeButton extends ConsumerWidget {
  const _ViewModeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(libraryViewModeControllerProvider);
    final isGrid = mode == LibraryViewMode.grid;
    return IconButton(
      icon: Icon(isGrid ? Icons.view_list_outlined : Icons.grid_view_outlined),
      tooltip: isGrid ? 'リスト表示' : 'グリッド表示',
      onPressed: ref.read(libraryViewModeControllerProvider.notifier).toggle,
    );
  }
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Text(
        '$count 件',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// サーバーに確認できず手元の内容を表示していることを伝える。
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'オフラインです。前回取得した一覧を表示しています。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
