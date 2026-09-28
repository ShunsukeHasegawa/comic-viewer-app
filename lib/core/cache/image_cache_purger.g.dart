// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_cache_purger.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(imageCachePurger)
final imageCachePurgerProvider = ImageCachePurgerProvider._();

final class ImageCachePurgerProvider
    extends
        $FunctionalProvider<
          SessionDataPurger,
          SessionDataPurger,
          SessionDataPurger
        >
    with $Provider<SessionDataPurger> {
  ImageCachePurgerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imageCachePurgerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imageCachePurgerHash();

  @$internal
  @override
  $ProviderElement<SessionDataPurger> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionDataPurger create(Ref ref) {
    return imageCachePurger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionDataPurger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionDataPurger>(value),
    );
  }
}

String _$imageCachePurgerHash() => r'c00b150ffb32d7e08f390b50760a49f639fded80';
