import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/thumbnail_image.dart';
import '../../../domain/models/book_detail.dart';
import '../../downloads/application/downloaded_lookup.dart';
import '../../library/presentation/widgets/book_tiles.dart';
import '../application/book_detail_controller.dart';
import 'widgets/volume_tile.dart';

/// タイトル詳細 / 巻一覧画面。
class TitleDetailScreen extends ConsumerWidget {
  const TitleDetailScreen({required this.bookId, super.key});

  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookDetailControllerProvider(bookId));
    final controller = ref.read(bookDetailControllerProvider(bookId).notifier);
    final data = async.value;
    final detail = data?.detail;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(detail?.title ?? 'タイトル詳細'),
        actions: [
          if (detail != null)
            IconButton(
              icon: Icon(
                detail.isFavorite ? Icons.favorite : Icons.favorite_outline,
              ),
              tooltip: detail.isFavorite ? 'お気に入りから外す' : 'お気に入りに追加',
              onPressed: () => _toggleFavorite(context, controller),
            ),
        ],
      ),
      body: switch ((data, async.error)) {
        (null, final error?) => ErrorView(
          error: error,
          onRetry: controller.refresh,
        ),
        (null, null) => const Center(child: CircularProgressIndicator()),
        (final data?, _) => RefreshIndicator(
          onRefresh: () => _refresh(context, ref, bookId),
          child: _DetailBody(data: data),
        ),
      },
    );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    BookDetailController controller,
  ) async {
    try {
      await controller.toggleFavorite();
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('お気に入りを変更できませんでした: ${apiErrorMessage(error)}')),
      );
    }
  }
}

/// 再取得し、失敗したら（詳細は残るので）その場で知らせる。
Future<void> _refresh(BuildContext context, WidgetRef ref, int bookId) async {
  final provider = bookDetailControllerProvider(bookId);
  await ref.read(provider.notifier).refresh();
  final error = ref.read(provider).error;
  if (error == null || !context.mounted) return;
  showRefreshFailure(context, error, what: 'タイトル詳細');
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.data});

  final BookDetailData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = data.detail;
    final resume = resumeTargetOf(detail);
    // 圏外では端末にある巻しか開けない（#11）。
    final downloaded = ref.watch(downloadedVolumeIdsProvider);
    bool canOpen(BookVolume volume) =>
        !data.isStale || downloaded.contains(volume.id);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (data.isStale) const SliverToBoxAdapter(child: _OfflineNotice()),
        SliverToBoxAdapter(child: _Hero(detail: detail)),
        if (resume != null)
          SliverToBoxAdapter(
            child: _ResumeButton(
              detail: detail,
              volume: resume,
              canOpen: canOpen(resume),
            ),
          ),
        SliverToBoxAdapter(child: _Meta(detail: detail)),
        SliverToBoxAdapter(child: _VolumesHeader(detail: detail)),
        if (detail.volumes.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('登録されている巻がありません。')),
            ),
          )
        else
          SliverList.separated(
            itemCount: detail.volumes.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final volume = detail.volumes[index];
              return VolumeTile(
                bookId: detail.id,
                volume: volume,
                // 開けない巻はタップ自体を無効にする。押してからダイアログで
                // 断るより、読めないことが一覧で分かる方がよい。
                onOpen: canOpen(volume)
                    ? () => context.push(AppRoutes.viewer(volume.id))
                    : null,
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// 圏外で端末の控えを表示していることを伝える。
class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'オフラインです。ダウンロード済みの巻だけ読めます。',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.detail});

  final BookDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = detail.readingProgress;
    final cover = detail.volumes.isEmpty
        ? null
        : detail.volumes.first.thumbnail;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ThumbnailImage(
                apiUrl: cover,
                aspectRatio: bookCoverAspectRatio,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detail.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                if (detail.authors.isNotEmpty)
                  Text(
                    detail.authors.join(' / '),
                    style: theme.textTheme.bodyMedium,
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (detail.isComplete) const Chip(label: Text('完結')),
                    Chip(
                      label: Text(
                        detail.isComplete
                            ? '全 ${detail.volumes.length} 巻'
                            : '${detail.volumes.length} 巻まで',
                      ),
                    ),
                  ],
                ),
                if (progress != null && progress.totalVolumes > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '読了 ${progress.readVolumes} / ${progress.totalVolumes} 巻',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (progress.readVolumes / progress.totalVolumes)
                          .clamp(0, 1),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeButton extends StatelessWidget {
  const _ResumeButton({
    required this.detail,
    required this.volume,
    required this.canOpen,
  });

  final BookDetail detail;
  final BookVolume volume;

  /// 開けるか（圏外で未ダウンロードの巻は開けない）。
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    final isResume = volume.isInProgress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: FilledButton.icon(
        onPressed: canOpen
            ? () => context.push(AppRoutes.viewer(volume.id))
            : null,
        icon: Icon(canOpen ? Icons.play_arrow : Icons.cloud_off_outlined),
        label: Text(switch ((canOpen, isResume)) {
          (false, _) => 'オフラインでは読めません',
          (true, true) => '${volume.volume} 巻の続きから読む',
          (true, false) => '${volume.volume} 巻を読む',
        }),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.detail});

  final BookDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, String)>[
      if (detail.publisher case final publisher?) ('出版社', publisher),
      if (detail.label case final label?) ('レーベル', label),
      if (detail.categories.isNotEmpty)
        ('カテゴリ', detail.categories.map((c) => c.name).join('、')),
      if (detail.tags.isNotEmpty) ('タグ', detail.tags.join('、')),
      if (detail.totalArchiveBytes > 0)
        ('全巻の容量', formatBytes(detail.totalArchiveBytes)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.overview case final overview?
              when overview.isNotEmpty) ...[
            Text('あらすじ', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(overview, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
          ],
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(value, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VolumesHeader extends StatelessWidget {
  const _VolumesHeader({required this.detail});

  final BookDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloadable = detail.volumes.where((v) => v.isDownloadable).toList();
    // 件数と容量は同じ巻から数える（サーバーの total_archive_bytes が無い場合に
    // 「2 巻 (0 B)」のような食い違った表示にならないように）。
    final bytes = downloadable.fold<int>(
      0,
      (sum, volume) => sum + (volume.archiveBytes ?? 0),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
      child: Row(
        children: [
          Expanded(child: Text('巻一覧', style: theme.textTheme.titleMedium)),
          // タイトル単位の一括ダウンロードは #10（容量を見せてから実行する）。
          TextButton.icon(
            onPressed: null,
            icon: const Icon(Icons.download_for_offline_outlined),
            label: Text(
              downloadable.isEmpty
                  ? '一括ダウンロード不可'
                  : '全 ${downloadable.length} 巻 (${formatBytes(bytes)})',
            ),
          ),
        ],
      ),
    );
  }
}
