// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thumbnail_image.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 画像リクエストに付ける認証ヘッダ。
///
/// 画像も `auth:sanctum` 配下なので Bearer が必要。`dio` のインターセプタは
/// 画像ウィジェットを通らないため、ここで解決して渡す。
///
/// ログイン / ログアウトで作り直す（`authControllerProvider` を watch する）。
/// 失効したトークンを使い続けると、以降すべてのサムネイルが 401 のままになる。

@ProviderFor(imageAuthHeaders)
final imageAuthHeadersProvider = ImageAuthHeadersProvider._();

/// 画像リクエストに付ける認証ヘッダ。
///
/// 画像も `auth:sanctum` 配下なので Bearer が必要。`dio` のインターセプタは
/// 画像ウィジェットを通らないため、ここで解決して渡す。
///
/// ログイン / ログアウトで作り直す（`authControllerProvider` を watch する）。
/// 失効したトークンを使い続けると、以降すべてのサムネイルが 401 のままになる。

final class ImageAuthHeadersProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $FutureProvider<Map<String, String>> {
  /// 画像リクエストに付ける認証ヘッダ。
  ///
  /// 画像も `auth:sanctum` 配下なので Bearer が必要。`dio` のインターセプタは
  /// 画像ウィジェットを通らないため、ここで解決して渡す。
  ///
  /// ログイン / ログアウトで作り直す（`authControllerProvider` を watch する）。
  /// 失効したトークンを使い続けると、以降すべてのサムネイルが 401 のままになる。
  ImageAuthHeadersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imageAuthHeadersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imageAuthHeadersHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, String>> create(Ref ref) {
    return imageAuthHeaders(ref);
  }
}

String _$imageAuthHeadersHash() => r'ebd647a6d934fdc009723be2690566fc0c23ba5a';

/// 既定はディスクキャッシュつきのネットワーク画像。
///
/// キャッシュの容量制御（#8）を入れる際は、ここを自前のキャッシュストアに
/// 差し替えて一元管理する（二重キャッシュを作らない）。

@ProviderFor(thumbnailBuilder)
final thumbnailBuilderProvider = ThumbnailBuilderProvider._();

/// 既定はディスクキャッシュつきのネットワーク画像。
///
/// キャッシュの容量制御（#8）を入れる際は、ここを自前のキャッシュストアに
/// 差し替えて一元管理する（二重キャッシュを作らない）。

final class ThumbnailBuilderProvider
    extends
        $FunctionalProvider<
          ThumbnailBuilder,
          ThumbnailBuilder,
          ThumbnailBuilder
        >
    with $Provider<ThumbnailBuilder> {
  /// 既定はディスクキャッシュつきのネットワーク画像。
  ///
  /// キャッシュの容量制御（#8）を入れる際は、ここを自前のキャッシュストアに
  /// 差し替えて一元管理する（二重キャッシュを作らない）。
  ThumbnailBuilderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'thumbnailBuilderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$thumbnailBuilderHash();

  @$internal
  @override
  $ProviderElement<ThumbnailBuilder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThumbnailBuilder create(Ref ref) {
    return thumbnailBuilder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThumbnailBuilder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThumbnailBuilder>(value),
    );
  }
}

String _$thumbnailBuilderHash() => r'909f26855dfb9391ef65d3f63932b23c0011f2a4';

@ProviderFor(thumbnailCachePurger)
final thumbnailCachePurgerProvider = ThumbnailCachePurgerProvider._();

final class ThumbnailCachePurgerProvider
    extends
        $FunctionalProvider<
          SessionDataPurger,
          SessionDataPurger,
          SessionDataPurger
        >
    with $Provider<SessionDataPurger> {
  ThumbnailCachePurgerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'thumbnailCachePurgerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$thumbnailCachePurgerHash();

  @$internal
  @override
  $ProviderElement<SessionDataPurger> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionDataPurger create(Ref ref) {
    return thumbnailCachePurger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionDataPurger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionDataPurger>(value),
    );
  }
}

String _$thumbnailCachePurgerHash() =>
    r'9cf4b90ba99747463e8c7471de9d5860f8a1ee72';
