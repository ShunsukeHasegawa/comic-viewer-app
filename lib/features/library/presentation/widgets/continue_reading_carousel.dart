import 'package:flutter/material.dart';

import '../../../../core/router/open_volume.dart';
import '../../../../core/widgets/thumbnail_image.dart';
import '../../../../domain/models/reading_book.dart';

/// 「続きを読む」カルーセル（`GET /api/v2/user/reading`）。
class ContinueReadingCarousel extends StatelessWidget {
  const ContinueReadingCarousel({required this.items, super.key});

  final List<ReadingBook> items;

  static const height = 190.0;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('続きを読む', style: theme.textTheme.titleMedium),
        ),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _ReadingCard(item: items[index]),
          ),
        ),
      ],
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.item});

  final ReadingBook item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 104,
      child: InkWell(
        // 読みかけの巻をそのまま開く。閉じたらタイトル詳細へ戻す（#21）。
        onTap: () => pushVolumeViaTitle(
          context,
          bookId: item.bookId,
          volumeId: item.volumeId,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 高さは親（カルーセル）に合わせる。表紙の縦横比を固定すると
            // 文字の分だけはみ出すため Expanded で余りを使う。
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ThumbnailImage(apiUrl: item.thumbnail),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${item.volumeNumber} 巻 ${item.currentPage} / ${item.maxPage}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (item.progressPercent / 100).clamp(0, 1),
                minHeight: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
