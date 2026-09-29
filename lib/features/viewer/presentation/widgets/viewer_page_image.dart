import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/cache/comic_image_loader.dart';
import '../../../../core/media/media_urls.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/comic_image.dart';
import 'viewer_chrome.dart';

part 'viewer_page_image.g.dart';

/// ページ画像の描画方法。テストでは差し替える。
typedef ViewerImageBuilder = Widget Function(
  BuildContext context,
  ComicImageRequest request,
  VoidCallback onRetry,
);

/// 既定は自前の一時キャッシュ（#8）経由の画像。
///
/// **読み込み完了まで画像を出さない**（途中まで描かれた JPEG を見せない）。
/// 取得元の解決順（ダウンロード済みローカル → キャッシュ → ネットワーク）は
/// `ComicImageLoader` に集約してある（#11）。ここは描画だけを受け持つ。
@Riverpod(keepAlive: true)
ViewerImageBuilder viewerImageBuilder(Ref ref) {
  return (context, request, onRetry) => ComicImage(
    request: request,
    fit: BoxFit.contain,
    loadingBuilder: (context) => const ViewerPageLoading(),
    errorBuilder: (context, _) => ViewerPageError(onRetry: onRetry),
  );
}

/// 1 ページ分の画像（ピンチズーム対応）。
class ViewerPageImage extends ConsumerStatefulWidget {
  const ViewerPageImage({
    required this.volumeId,
    required this.page,
    required this.filesVersion,
    required this.isCurrent,
    required this.onNext,
    required this.onPrevious,
    required this.onToggleMenu,
    this.maxScale = 3,
    super.key,
  });

  final int volumeId;
  final int page;

  /// ZIP の世代。差し替え後に古い画像を表示しないため URL / キーに必ず付ける。
  final int filesVersion;

  /// 表示中のページか（離れたら拡大を解除する）。
  final bool isCurrent;

  /// タップ操作（左 = 次 / 右 = 前 / 中央 = メニュー）。
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onToggleMenu;

  /// 最大拡大率（Web 版と同じ 3 倍）。
  final double maxScale;

  @override
  ConsumerState<ViewerPageImage> createState() => _ViewerPageImageState();
}

class _ViewerPageImageState extends ConsumerState<ViewerPageImage> {
  final _zoomController = TransformationController();

  /// 再読み込み用。値を変えて画像ウィジェットを作り直す。
  int _reloadToken = 0;

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ViewerPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ページを離れたら拡大を解除する。拡大したまま残すと、戻ってきたときに
    // タップ位置（左 / 中央 / 右）の判定が見た目とずれる。
    if (oldWidget.isCurrent && !widget.isCurrent) {
      _zoomController.value = Matrix4.identity();
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ComicImageRequest.page(
      ref.watch(mediaUrlsProvider),
      volumeId: widget.volumeId,
      page: widget.page,
      filesVersion: widget.filesVersion,
    );

    return InteractiveViewer(
      transformationController: _zoomController,
      maxScale: widget.maxScale,
      // 拡大していないときは PageView にスワイプを渡す。
      panEnabled: true,
      clipBehavior: Clip.none,
      // タップ受けは InteractiveViewer の内側に置く（外側だとピンチの認識器に
      // タップを取られ、内側のボタンも押せなくなる）。
      child: ViewerTapZones(
        onNext: widget.onNext,
        onPrevious: widget.onPrevious,
        onToggleMenu: widget.onToggleMenu,
        child: KeyedSubtree(
          key: ValueKey('${request.cacheKey}_$_reloadToken'),
          child: ref.watch(viewerImageBuilderProvider)(
            context,
            request,
            () => setState(() => _reloadToken++),
          ),
        ),
      ),
    );
  }
}

/// 読み込み中の表示（白画面を見せない）。
class ViewerPageLoading extends StatelessWidget {
  const ViewerPageLoading({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.viewerBackground,
    child: Center(child: CircularProgressIndicator()),
  );
}

/// 読み込み失敗（再読み込みできる）。
class ViewerPageError extends StatelessWidget {
  const ViewerPageError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.viewerBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'ページを読み込めませんでした',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// ページ画像の先読み処理。テストでは差し替える。
typedef PagePrecacher = Future<void> Function(
  BuildContext context,
  ComicImageRequest request,
);

/// 既定はデコードまで済ませる `precacheImage`。
///
/// 表示と同じ [ComicImageProvider] を使う（同じキャッシュを温める。
/// 先読みだけ別経路にすると二重ダウンロードになる）。
@Riverpod(keepAlive: true)
PagePrecacher pagePrecacher(Ref ref) {
  return (context, request) async {
    final loader = await ref.read(comicImageLoaderProvider.future);
    // キャッシュの準備を待つ間に画面を離れていることがある。
    if (!context.mounted) return;
    await precacheImage(
      ComicImageProvider(loader: loader, request: request),
      context,
    );
  };
}
