import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/comic_image_loader.dart';

/// 一時キャッシュ経由でコミック画像を表示する。
///
/// - **読み込みが終わるまで画像を出さない**（途中まで描かれた JPEG を見せない）
/// - 失敗したら [errorBuilder]（呼び出し側で再読み込みの導線を出す）
class ComicImage extends ConsumerWidget {
  const ComicImage({
    required this.request,
    required this.loadingBuilder,
    required this.errorBuilder,
    this.fit = BoxFit.cover,
    this.fadeInDuration,
    this.onShown,
    super.key,
  });

  final ComicImageRequest request;

  /// キャッシュの準備中 / ダウンロード中 / デコード中の表示。
  final WidgetBuilder loadingBuilder;

  final Widget Function(BuildContext context, Object error) errorBuilder;

  final BoxFit fit;

  /// 指定すると、読み込めた画像をこの時間で溶かして出す（パッと切り替えない）。
  /// メモリ上のキャッシュから同期で出せたときは溶かさない。
  final Duration? fadeInDuration;

  /// 画像が見えきった（溶かし終えた）ときに呼ぶ。下に敷いたつなぎの層を
  /// 外す合図に使う。再構築のたびに呼ばれうるので、受け手が 1 度に絞る。
  final VoidCallback? onShown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loader = ref.watch(comicImageLoaderProvider);

    // DB / キャッシュディレクトリの用意が終わるまでは取得を始められない。
    return switch ((loader.value, loader.error)) {
      (null, final error?) => errorBuilder(context, error),
      (null, null) => loadingBuilder(context),
      (final loader?, _) => Image(
        image: ComicImageProvider(loader: loader, request: request),
        fit: fit,
        // 1 フレーム目が来るまでは「読み込み中」。
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) {
            _notifyShownAfterFrame();
            return child;
          }
          final duration = fadeInDuration;
          if (duration == null) {
            if (frame == null) return loadingBuilder(context);
            _notifyShownAfterFrame();
            return child;
          }
          // 子の数と並びを変えない（AnimatedOpacity の状態を引き継いで溶かす）。
          return Stack(
            fit: StackFit.passthrough,
            children: [
              if (frame == null)
                loadingBuilder(context)
              else
                const SizedBox.shrink(),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: duration,
                curve: Curves.easeOut,
                onEnd: frame == null ? null : onShown,
                child: child,
              ),
            ],
          );
        },
        errorBuilder: (context, error, _) => errorBuilder(context, error),
      ),
    };
  }

  /// 描画中（frameBuilder の中）に呼び手の状態を変えさせない。
  void _notifyShownAfterFrame() {
    final onShown = this.onShown;
    if (onShown == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => onShown());
  }
}
