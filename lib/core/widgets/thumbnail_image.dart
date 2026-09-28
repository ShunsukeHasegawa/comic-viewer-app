import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/auth_store.dart';
import '../config/app_config.dart';
import '../media/media_urls.dart';
import '../session/session_data_purger.dart';

part 'thumbnail_image.g.dart';

/// 画像リクエストに付ける認証ヘッダ。
///
/// 画像も `auth:sanctum` 配下なので Bearer が必要。`dio` のインターセプタは
/// 画像ウィジェットを通らないため、ここで解決して渡す。
///
/// ログイン / ログアウトで作り直す（`authControllerProvider` を watch する）。
/// 失効したトークンを使い続けると、以降すべてのサムネイルが 401 のままになる。
@Riverpod(keepAlive: true)
Future<Map<String, String>> imageAuthHeaders(Ref ref) async {
  ref.watch(authControllerProvider);
  final token = await ref.watch(authStoreProvider).readToken();
  if (token == null || token.isEmpty) return const {};
  return {'Authorization': 'Bearer $token'};
}

/// サムネイル画像の描画方法。テストでは差し替える。
typedef ThumbnailBuilder = Widget Function(
  BuildContext context,
  Uri url,
  Map<String, String> headers,
  BoxFit fit,
);

/// 既定はディスクキャッシュつきのネットワーク画像。
///
/// キャッシュの容量制御（#8）を入れる際は、ここを自前のキャッシュストアに
/// 差し替えて一元管理する（二重キャッシュを作らない）。
@Riverpod(keepAlive: true)
ThumbnailBuilder thumbnailBuilder(Ref ref) {
  return (context, url, headers, fit) => CachedNetworkImage(
    imageUrl: url.toString(),
    // #8 で自前キャッシュに移すときの突き合わせ用に、URL ではなく
    // 世代つきのキーで保存する。
    cacheKey: MediaUrls.thumbnailCacheKey(url.toString()),
    httpHeaders: headers,
    fit: fit,
    fadeInDuration: const Duration(milliseconds: 120),
    placeholder: (context, _) => const ThumbnailPlaceholder(),
    errorWidget: (context, _, _) => const ThumbnailPlaceholder(failed: true),
  );
}

/// ログアウト時にサムネイルのディスク / メモリキャッシュを破棄する（#15）。
///
/// #8 で自前のキャッシュストアに移したら、そちらの削除に置き換える。
class ThumbnailCachePurger implements SessionDataPurger {
  const ThumbnailCachePurger();

  @override
  String get debugLabel => 'thumbnail cache';

  @override
  Future<void> purgeSessionData() async {
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}

@Riverpod(keepAlive: true)
SessionDataPurger thumbnailCachePurger(Ref ref) => const ThumbnailCachePurger();

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
    final config = ref.watch(appConfigProvider);
    final url = ref.watch(mediaUrlsProvider).thumbnail(apiUrl);

    final Widget child;
    if (url == null) {
      child = const ThumbnailPlaceholder();
    } else {
      // API 以外の配信元（CDN など）にトークンを送らない。
      final needsAuth = config.isApiOrigin(url);
      final headers = needsAuth
          ? ref.watch(imageAuthHeadersProvider).value
          : const <String, String>{};
      child = headers == null
          // トークン解決中。ヘッダ無しで投げると 401 になるので待つ。
          ? const ThumbnailPlaceholder()
          : ref.watch(thumbnailBuilderProvider)(context, url, headers, fit);
    }

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
