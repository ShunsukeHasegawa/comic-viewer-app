// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_image_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(memoryImageCacheClearer)
final memoryImageCacheClearerProvider = MemoryImageCacheClearerProvider._();

final class MemoryImageCacheClearerProvider
    extends
        $FunctionalProvider<
          MemoryImageCacheClearer,
          MemoryImageCacheClearer,
          MemoryImageCacheClearer
        >
    with $Provider<MemoryImageCacheClearer> {
  MemoryImageCacheClearerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryImageCacheClearerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryImageCacheClearerHash();

  @$internal
  @override
  $ProviderElement<MemoryImageCacheClearer> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MemoryImageCacheClearer create(Ref ref) {
    return memoryImageCacheClearer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryImageCacheClearer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryImageCacheClearer>(value),
    );
  }
}

String _$memoryImageCacheClearerHash() =>
    r'234b848061324d9b7a8bc5b8dafa0382d48008f1';
