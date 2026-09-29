import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/reading_book.dart';
import '../../application/library_controller.dart';

/// 絞り込みチップ（お気に入り / 未読 / 完結 / カテゴリ / タグ）。
class LibraryFilterBar extends ConsumerWidget {
  const LibraryFilterBar({
    required this.categories,
    required this.tags,
    this.isOffline = false,
    super.key,
  });

  final List<Taxonomy> categories;
  final List<Taxonomy> tags;

  /// サーバーに確認できていない（圏外）。ダウンロード済みの既定 ON を決める。
  final bool isOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(libraryFilterControllerProvider);
    final controller = ref.read(libraryFilterControllerProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        spacing: 8,
        children: [
          // オフラインでは既定で ON（読めるものだけを出す。#11）。
          FilterChip(
            label: const Text('ダウンロード済み'),
            avatar: const Icon(Icons.offline_pin_outlined, size: 18),
            selected: filter.onlyDownloadedWhen(isOffline: isOffline),
            onSelected: (_) =>
                controller.toggleDownloaded(isOffline: isOffline),
          ),
          FilterChip(
            label: const Text('お気に入り'),
            avatar: const Icon(Icons.favorite_outline, size: 18),
            selected: filter.onlyFavorites,
            onSelected: (_) => controller.toggleFavorites(),
          ),
          FilterChip(
            label: const Text('未読'),
            selected: filter.onlyUnread,
            onSelected: (_) => controller.toggleUnread(),
          ),
          FilterChip(
            label: const Text('完結'),
            selected: filter.onlyComplete,
            onSelected: (_) => controller.toggleComplete(),
          ),
          if (categories.isNotEmpty) const _ChipDivider(),
          for (final category in categories)
            FilterChip(
              label: Text(category.name),
              selected: filter.categoryIds.contains(category.id),
              onSelected: (_) => controller.toggleCategory(category.id),
            ),
          if (tags.isNotEmpty) ...[
            const _ChipDivider(),
            ActionChip(
              label: Text(
                filter.tagIds.isEmpty ? 'タグ' : 'タグ (${filter.tagIds.length})',
              ),
              avatar: const Icon(Icons.sell_outlined, size: 18),
              onPressed: () => _showTagPicker(context, tags),
            ),
          ],
          if (filter.hasActiveFilters)
            ActionChip(
              label: const Text('解除'),
              avatar: const Icon(Icons.close, size: 18),
              onPressed: controller.clearFilters,
            ),
        ],
      ),
    );
  }

  Future<void> _showTagPicker(BuildContext context, List<Taxonomy> tags) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _TagPickerSheet(tags: tags),
    );
  }
}

class _ChipDivider extends StatelessWidget {
  const _ChipDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 24,
    child: VerticalDivider(width: 8, thickness: 1),
  );
}

/// タグは数が多くなるのでボトムシートで選ぶ。
class _TagPickerSheet extends ConsumerWidget {
  const _TagPickerSheet({required this.tags});

  final List<Taxonomy> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(libraryFilterControllerProvider);
    final controller = ref.read(libraryFilterControllerProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('タグで絞り込む', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in tags)
                      FilterChip(
                        label: Text(tag.name),
                        selected: filter.tagIds.contains(tag.id),
                        onSelected: (_) => controller.toggleTag(tag.id),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
