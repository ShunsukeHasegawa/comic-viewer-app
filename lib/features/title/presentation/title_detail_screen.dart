import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cache/comic_image_loader.dart';
import '../../../core/media/media_urls.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/thumbnail_image.dart';
import '../../../domain/models/book_detail.dart';
import '../../admin/presentation/open_admin_page.dart';
import '../../downloads/application/download_queue.dart';
import '../../downloads/application/downloaded_lookup.dart';
import '../application/book_detail_controller.dart';
import 'widgets/title_download_dialog.dart';
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

    return Scaffold(
      // 詳細が出せるときは AppBar を置かない。戻る / お気に入りはヒーローの上に
      // 重ね、スクロールとともに流す（Web 版スマホレイアウトと同じ）。固定の
      // AppBar にすると、下までスクロールしたとき背景の無い白い帯が残る。
      appBar: data == null
          ? AppBar(leading: const AppBackButton(), title: const Text('タイトル詳細'))
          : null,
      body: switch ((data, async.error)) {
        (null, final error?) => ErrorView(
          error: error,
          onRetry: controller.refresh,
        ),
        (null, null) => const Center(child: CircularProgressIndicator()),
        (final data?, _) => RefreshIndicator(
          onRefresh: () => _refresh(context, ref, bookId),
          child: _DetailBody(
            data: data,
            onToggleFavorite: () => _toggleFavorite(context, controller),
          ),
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
  const _DetailBody({required this.data, required this.onToggleFavorite});

  final BookDetailData data;
  final VoidCallback onToggleFavorite;

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
        SliverToBoxAdapter(
          child: _Hero(
            detail: detail,
            resume: resume,
            canOpenResume: resume != null && canOpen(resume),
            onToggleFavorite: onToggleFavorite,
          ),
        ),
        SliverToBoxAdapter(child: _Meta(detail: detail)),
        SliverToBoxAdapter(
          child: _VolumesHeader(detail: detail, isStale: data.isStale),
        ),
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

/// 画像をそのまま見せる高さ（この下から文字が始まる）。
const _heroImageHeight = 260.0;

/// タイトルの顔。背景に作品の絵を敷き、その上に文字と「読む」を重ねる。
///
/// Web 版スマホレイアウト（`components/title/TitleHero.vue`）に合わせた構成。
/// 背景は**1 巻の 1 ページ目**で、サムネイル（小さい）を引き伸ばすより絵が
/// 鮮明に出る。ダウンロード済みならこの画像もローカルから解決される（#11）。
class _Hero extends StatelessWidget {
  const _Hero({
    required this.detail,
    required this.resume,
    required this.canOpenResume,
    required this.onToggleFavorite,
  });

  final BookDetail detail;
  final BookVolume? resume;
  final bool canOpenResume;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = [?detail.publisher, ?detail.label].join(' · ');

    return Stack(
      children: [
        Positioned.fill(child: _HeroBackground(detail: detail)),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroChrome(
              bookId: detail.id,
              isFavorite: detail.isFavorite,
              onToggleFavorite: onToggleFavorite,
            ),
            const SizedBox(height: _heroImageHeight),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (detail.authors.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail.authors.join(' / '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _HeroChips(detail: detail),
                  if (detail.overview case final overview?
                      when overview.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _HeroOverview(overview: overview),
                  ],
                  const SizedBox(height: 14),
                  _ResumeButton(volume: resume, canOpen: canOpenResume),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 背景の絵。全面に暗いグラデーションを重ねて文字を読みやすくする。
///
/// 絵の大きさとグラデーションはヒーローの高さではなく、画面の幅と文字の
/// 開始位置から決める。ヒーローの高さに合わせると、あらすじを展開した
/// ときに絵が拡大されてしまう。
class _HeroBackground extends ConsumerWidget {
  const _HeroBackground({required this.detail});

  final BookDetail detail;

  /// 漫画のページ（縦長）を幅いっぱいに見せる縦横比。
  static const _imageAspect = 1.5;

  /// 文字の開始位置から暗くし終えるまでの距離。畳んだあらすじと「読む」が
  /// 収まる程度にする。
  static const _darkenDistance = 240.0;

  /// ページ画像が来るまで敷くサムネイルのぼかし。小さい絵を引き伸ばした
  /// 荒さが見えない程度にする。
  static const _placeholderBlurSigma = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layers = _backgroundLayers(ref.watch(mediaUrlsProvider), detail);
    // 画像が無い / 読み込み中でも文字は白なので、下地は必ず暗くしておく。
    if (layers == null) return const ColoredBox(color: Colors.black);

    final build = ref.watch(thumbnailBuilderProvider);
    final (:page, :thumbnail) = layers;
    final image = Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnail != null)
          if (page == null)
            build(context, thumbnail, BoxFit.cover, backdrop: true)
          else
            // ページ画像が来るまでのつなぎ。一覧で読み込み済みのことが多く、
            // 単色の板よりタイトルの雰囲気がすぐ伝わる。
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: _placeholderBlurSigma,
                sigmaY: _placeholderBlurSigma,
              ),
              child: build(context, thumbnail, BoxFit.cover, backdrop: true),
            ),
        if (page != null) build(context, page, BoxFit.cover, backdrop: true),
      ],
    );
    // 文字が始まる位置（`_HeroChrome` の高さ + 絵を見せる高さ）。
    final textTop =
        MediaQuery.paddingOf(context).top +
        8 +
        kMinInteractiveDimension +
        _heroImageHeight;
    final darkEnd = textTop + _darkenDistance;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final imageHeight = math.max(
          constraints.maxWidth * _imageAspect,
          darkEnd,
        );
        double stopAt(double y) =>
            height <= 0 ? 1.0 : (y / height).clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: imageHeight,
              // あらすじが長くヒーローが絵より伸びたときに、絵の下端が
              // 線にならないよう黒へ溶かす。
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.transparent],
                  stops: [0.85, 1],
                ).createShader(rect),
                child: image,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    Color(0x66000000),
                    Color(0x33000000),
                    Color(0xE6000000),
                  ],
                  stops: [0, stopAt(darkEnd * 0.35), stopAt(darkEnd)],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ],
        );
      },
    );
  }

  /// 背景に使う画像。1 巻の 1 ページ目と、それが来るまで敷く 1 巻のサムネイル。
  ///
  /// ページ URL には `files_version` が要るので、アーカイブが無い巻
  /// （`files_version` が `null`）ではサムネイルだけを背景にする。
  /// 敷くのは一覧（`/api/books` は最終巻）と同じ絵ではなく 1 巻のものにする。
  /// ページ 1 枚目と同じ絵なので、ぼかしが取れるように差し替わる。
  static ({ComicImageRequest? page, ComicImageRequest? thumbnail})?
  _backgroundLayers(MediaUrls urls, BookDetail detail) {
    if (detail.volumes.isEmpty) return null;
    final first = detail.volumes.first;
    final filesVersion = first.filesVersion;
    final thumbnail = ComicImageRequest.thumbnail(urls, first.thumbnail);
    final page = filesVersion == null
        ? null
        : ComicImageRequest.page(
            urls,
            volumeId: first.id,
            page: 1,
            filesVersion: filesVersion,
          );
    if (page == null && thumbnail == null) return null;
    return (page: page, thumbnail: thumbnail);
  }
}

/// 絵の上に浮かせる操作（戻る / お気に入り）。
class _HeroChrome extends ConsumerWidget {
  const _HeroChrome({
    required this.bookId,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final int bookId;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = IconButton.styleFrom(
      backgroundColor: Colors.black38,
      foregroundColor: Colors.white,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.paddingOf(context).top + 8,
        8,
        0,
      ),
      child: Row(
        children: [
          AppBackButton(style: style),
          const Spacer(),
          // Web 版のタイトル詳細の「編集」と同じ入口（#20）。
          if (watchIsAdmin(ref))
            IconButton(
              style: style,
              icon: const Icon(Icons.edit_outlined),
              tooltip: '管理画面で編集',
              onPressed: () => openAdminPage(context, ref, bookId: bookId),
            ),
          IconButton(
            style: style,
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_outline),
            tooltip: isFavorite ? 'お気に入りから外す' : 'お気に入りに追加',
            onPressed: onToggleFavorite,
          ),
        ],
      ),
    );
  }
}

/// 完結 / 巻数 / タグ。
class _HeroChips extends StatelessWidget {
  const _HeroChips({required this.detail});

  final BookDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget chip(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
    );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (detail.isComplete) chip('完結'),
        chip(
          detail.isComplete
              ? '全 ${detail.volumes.length} 巻'
              : '${detail.volumes.length} 巻まで',
        ),
        for (final tag in detail.tags) chip(tag),
      ],
    );
  }
}

/// あらすじ。長いものは畳んでおく（ヒーローが画面を埋め尽くさないように）。
class _HeroOverview extends StatefulWidget {
  const _HeroOverview({required this.overview});

  final String overview;

  @override
  State<_HeroOverview> createState() => _HeroOverviewState();
}

class _HeroOverviewState extends State<_HeroOverview> {
  static const _collapsedLines = 3;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: Colors.white70);
    return LayoutBuilder(
      builder: (context, constraints) {
        // 畳んだ行数に収まるなら畳む意味が無いので、「もっと見る」を出さない。
        final painter = TextPainter(
          text: TextSpan(text: widget.overview, style: style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        final text = Text(
          widget.overview,
          maxLines: _expanded ? null : _collapsedLines,
          overflow: _expanded ? null : TextOverflow.ellipsis,
          style: style,
        );
        if (!overflows) return text;

        return GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              const SizedBox(height: 2),
              Text(
                _expanded ? '閉じる' : 'もっと見る',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ResumeButton extends StatelessWidget {
  const _ResumeButton({required this.volume, required this.canOpen});

  /// 続きから読む巻。`null` は読める巻が無い（巻が登録されていない）。
  final BookVolume? volume;

  /// 開けるか（圏外で未ダウンロードの巻は開けない）。
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    final target = volume;
    final isResume = target?.isInProgress ?? false;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white24,
          disabledForegroundColor: Colors.white60,
        ),
        onPressed: target != null && canOpen
            ? () => context.push(AppRoutes.viewer(target.id))
            : null,
        icon: Icon(
          target != null && canOpen
              ? Icons.play_arrow
              : Icons.cloud_off_outlined,
        ),
        label: Text(switch ((target, canOpen, isResume)) {
          (null, _, _) => '読める巻がありません',
          (_, false, _) => 'オフラインでは読めません',
          (final target?, _, true) => '${target.volume} 巻の続きから読む',
          (final target?, _, false) => '${target.volume} 巻を読む',
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
    // 出版社 / レーベル / タグ / あらすじはヒーロー側に出している。
    final rows = <(String, String)>[
      if (detail.categories.isNotEmpty)
        ('カテゴリ', detail.categories.map((c) => c.name).join('、')),
      if (detail.totalArchiveBytes > 0)
        ('全巻の容量', formatBytes(detail.totalArchiveBytes)),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

class _VolumesHeader extends ConsumerWidget {
  const _VolumesHeader({required this.detail, required this.isStale});

  final BookDetail detail;

  /// 端末の控えを表示している（圏外）。一括ダウンロードは積んでも失敗する
  /// だけなので出さない。
  final bool isStale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final downloads = ref.watch(downloadQueueProvider).value ?? const {};
    final volumeIds = {for (final volume in detail.volumes) volume.id};
    final active = [
      for (final download in downloads.values)
        if (download.isActive && volumeIds.contains(download.volumeId))
          download.volumeId,
    ];
    final hasDownloadable = detail.volumes.any((v) => v.isDownloadable);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
      child: Row(
        children: [
          Expanded(child: Text('巻一覧', style: theme.textTheme.titleMedium)),
          // 積んだ巻は一覧の各行でも止められるが、まとめて積んだものを
          // 1 巻ずつ止めさせるのは酷なので、タイトル単位でも止められるようにする。
          if (active.isNotEmpty)
            TextButton.icon(
              onPressed: () => _pauseAll(context, ref, active),
              icon: const Icon(Icons.pause),
              label: Text('${active.length} 巻を中断'),
            ),
          if (!isStale && hasDownloadable)
            TextButton.icon(
              onPressed: () => _download(context, ref),
              icon: const Icon(Icons.download_for_offline_outlined),
              label: const Text('まとめてダウンロード'),
            ),
        ],
      ),
    );
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final queue = ref.read(downloadQueueProvider.notifier);
    final plan = await showTitleDownloadDialog(context, detail: detail);
    if (plan == null || !context.mounted) return;
    try {
      await queue.enqueueAll([
        for (final volume in plan.volumes)
          (volumeId: volume.id, bookId: detail.id),
      ]);
    } on Object catch (error) {
      if (!context.mounted) return;
      showActionFailure(context, error, what: 'ダウンロードの開始');
    }
  }

  Future<void> _pauseAll(
    BuildContext context,
    WidgetRef ref,
    List<int> volumeIds,
  ) async {
    final queue = ref.read(downloadQueueProvider.notifier);
    try {
      for (final volumeId in volumeIds) {
        await queue.pause(volumeId);
      }
    } on Object catch (error) {
      if (!context.mounted) return;
      showActionFailure(context, error, what: 'ダウンロードの中断');
    }
  }
}
