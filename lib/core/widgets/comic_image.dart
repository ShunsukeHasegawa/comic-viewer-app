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
          if (wasSynchronouslyLoaded) return child;
          final duration = fadeInDuration;
          if (duration == null) {
            return frame == null ? loadingBuilder(context) : child;
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
                child: child,
              ),
            ],
          );
        },
        errorBuilder: (context, error, _) => errorBuilder(context, error),
      ),
    };
  }
}
