// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_cache_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(imageCacheStore)
final imageCacheStoreProvider = ImageCacheStoreProvider._();

final class ImageCacheStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<ImageCacheStore>,
          ImageCacheStore,
          FutureOr<ImageCacheStore>
        >
    with $FutureModifier<ImageCacheStore>, $FutureProvider<ImageCacheStore> {
  ImageCacheStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imageCacheStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imageCacheStoreHash();

  @$internal
  @override
  $FutureProviderElement<ImageCacheStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ImageCacheStore> create(Ref ref) {
    return imageCacheStore(ref);
  }
}

String _$imageCacheStoreHash() => r'b633bd2b6d3d45efe4aa3ad8c310f41ffeabc266';

@ProviderFor(staleCacheEvictor)
final staleCacheEvictorProvider = StaleCacheEvictorProvider._();

final class StaleCacheEvictorProvider
    extends
        $FunctionalProvider<
          StaleCacheEvictor,
          StaleCacheEvictor,
          StaleCacheEvictor
        >
    with $Provider<StaleCacheEvictor> {
  StaleCacheEvictorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'staleCacheEvictorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$staleCacheEvictorHash();

  @$internal
  @override
  $ProviderElement<StaleCacheEvictor> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StaleCacheEvictor create(Ref ref) {
    return staleCacheEvictor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StaleCacheEvictor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StaleCacheEvictor>(value),
    );
  }
}

String _$staleCacheEvictorHash() => r'bd2e4808afbb397d2c39e299b6f9d77eb1ffa0aa';
