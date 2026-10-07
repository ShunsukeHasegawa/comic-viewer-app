import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../cache/comic_image_loader.dart';
import '../media/media_urls.dart';
import 'comic_image.dart';

part 'thumbnail_image.g.dart';

/// サムネイル画像の描画方法。テストでは差し替える。
///
/// [backdrop] は背景用（タイトル詳細のヒーロー）。読み込み中 / 失敗時は
/// 何も描かずに下の層を見せ、読み込めたら溶かして出す。
typedef ThumbnailBuilder = Widget Function(
  BuildContext context,
  ComicImageRequest request,
  BoxFit fit, {
  bool backdrop,
});

/// 背景用の画像を溶かして出す時間。
const backdropFadeInDuration = Duration(milliseconds: 250);

/// 既定は自前の一時キャッシュ（#8）経由の画像。
///
/// 認証ヘッダは `ComicImageLoader` が使う `Dio` のインターセプタが付ける
/// （API と同じオリジンのみ）。ウィジェット側でトークンを扱わない。
@Riverpod(keepAlive: true)
ThumbnailBuilder thumbnailBuilder(Ref ref) {
  return (context, request, fit, {backdrop = false}) => backdrop
      ? ComicImage(
          request: request,
          fit: fit,
          fadeInDuration: backdropFadeInDuration,
          loadingBuilder: (context) => const SizedBox.shrink(),
          errorBuilder: (context, _) => const SizedBox.shrink(),
        )
      : ComicImage(
          request: request,
          fit: fit,
          loadingBuilder: (context) => const ThumbnailPlaceholder(),
          errorBuilder: (context, _) =>
              const ThumbnailPlaceholder(failed: true),
        );
}

/// 巻 / 書籍のサムネイル。
///
/// [apiUrl] は API が返した相対 URL（`?m=` 付き）。`null` はサムネイル無し。
class ThumbnailImage extends ConsumerWidget {
  const ThumbnailImage({
    required this.apiUrl,
    this.fit = BoxFit.cover,
    this.aspectRatio,
    super.key,
  });

  final String? apiUrl;
  final BoxFit fit;

  /// 指定すると縦横比を固定する（グリッドの崩れ防止）。
  final double? aspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // URL とキャッシュキーは必ず一緒に作る（世代がずれないようにする）。
    final request = ComicImageRequest.thumbnail(
      ref.watch(mediaUrlsProvider),
      apiUrl,
    );

    final child = request == null
        ? const ThumbnailPlaceholder()
        : ref.watch(thumbnailBuilderProvider)(context, request, fit);

    final ratio = aspectRatio;
    return ratio == null
        ? child
        : AspectRatio(aspectRatio: ratio, child: child);
  }
}

/// サムネイルが無い / 読み込み中 / 失敗したときの表示。
class ThumbnailPlaceholder extends StatelessWidget {
  const ThumbnailPlaceholder({this.failed = false, super.key});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Center(
        child: Icon(
          failed ? Icons.broken_image_outlined : Icons.menu_book_outlined,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
