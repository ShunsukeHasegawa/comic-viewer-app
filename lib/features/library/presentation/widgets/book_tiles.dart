import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/thumbnail_image.dart';
import '../../../../domain/models/book.dart';

/// 巻数の表示。完結していない作品を「全 N 巻」と書かない。
String volumeLabel(Book book) {
  final volume = book.latestVolume;
  if (volume == null) return '';
  return book.isComplete ? '全 $volume 巻' : '$volume 巻まで';
}

/// 表紙の縦横比（一般的なコミックの表紙）。
const bookCoverAspectRatio = 0.7;

/// グリッド表示の 1 冊。
class BookGridTile extends StatelessWidget {
  const BookGridTile({
    required this.book,
    required this.isFavorite,
    required this.isUnread,
    super.key,
  });

  final Book book;
  final bool isFavorite;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push(AppRoutes.bookDetail(book.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ThumbnailImage(apiUrl: book.thumbnail),
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: BookBadges(
                    book: book,
                    isFavorite: isFavorite,
                    isUnread: isUnread,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.title,
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (book.latestVolume != null)
            Text(
              volumeLabel(book),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// リスト表示の 1 冊。
class BookListTile extends StatelessWidget {
  const BookListTile({
    required this.book,
    required this.isFavorite,
    required this.isUnread,
    super.key,
  });

  final Book book;
  final bool isFavorite;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: () => context.push(AppRoutes.bookDetail(book.id)),
      leading: SizedBox(
        width: 44,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: ThumbnailImage(
            apiUrl: book.thumbnail,
            aspectRatio: bookCoverAspectRatio,
          ),
        ),
      ),
      title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (book.author.isNotEmpty) book.author.join(' / '),
          if (book.latestVolume != null) volumeLabel(book),
        ].join('・'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: BookBadges(
        book: book,
        isFavorite: isFavorite,
        isUnread: isUnread,
      ),
    );
  }
}

/// 完結 / 未読 / お気に入りのしるし。
class BookBadges extends StatelessWidget {
  const BookBadges({
    required this.book,
    required this.isFavorite,
    required this.isUnread,
    super.key,
  });

  final Book book;
  final bool isFavorite;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 4,
      children: [
        if (isUnread)
          _Badge(label: '未読', color: scheme.primary, onColor: scheme.onPrimary),
        if (book.isComplete)
          _Badge(
            label: '完結',
            color: scheme.secondaryContainer,
            onColor: scheme.onSecondaryContainer,
          ),
        if (isFavorite)
          Icon(
            Icons.favorite,
            size: 16,
            color: scheme.error,
            semanticLabel: 'お気に入り',
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.onColor,
  });

  final String label;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: onColor),
        ),
      ),
    );
  }
}
