// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thumbnail_image.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 既定は自前の一時キャッシュ（#8）経由の画像。
///
/// 認証ヘッダは `ComicImageLoader` が使う `Dio` のインターセプタが付ける
/// （API と同じオリジンのみ）。ウィジェット側でトークンを扱わない。

@ProviderFor(thumbnailBuilder)
final thumbnailBuilderProvider = ThumbnailBuilderProvider._();

/// 既定は自前の一時キャッシュ（#8）経由の画像。
///
/// 認証ヘッダは `ComicImageLoader` が使う `Dio` のインターセプタが付ける
/// （API と同じオリジンのみ）。ウィジェット側でトークンを扱わない。

final class ThumbnailBuilderProvider
    extends
        $FunctionalProvider<
          ThumbnailBuilder,
          ThumbnailBuilder,
          ThumbnailBuilder
        >
    with $Provider<ThumbnailBuilder> {
  /// 既定は自前の一時キャッシュ（#8）経由の画像。
  ///
  /// 認証ヘッダは `ComicImageLoader` が使う `Dio` のインターセプタが付ける
  /// （API と同じオリジンのみ）。ウィジェット側でトークンを扱わない。
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

String _$thumbnailBuilderHash() => r'34b18aec85a17e1cce506a4b88b89a01000925ea';
