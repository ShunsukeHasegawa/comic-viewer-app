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
    super.key,
  });

  final ComicImageRequest request;

  /// キャッシュの準備中 / ダウンロード中 / デコード中の表示。
  final WidgetBuilder loadingBuilder;

  final Widget Function(BuildContext context, Object error) errorBuilder;

  final BoxFit fit;

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
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
            frame == null && !wasSynchronouslyLoaded
            ? loadingBuilder(context)
            : child,
        errorBuilder: (context, error, _) => errorBuilder(context, error),
      ),
    };
  }
}
