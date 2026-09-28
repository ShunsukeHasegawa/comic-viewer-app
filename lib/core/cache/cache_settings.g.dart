// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(cacheSettingsStore)
final cacheSettingsStoreProvider = CacheSettingsStoreProvider._();

final class CacheSettingsStoreProvider
    extends
        $FunctionalProvider<
          CacheSettingsStore,
          CacheSettingsStore,
          CacheSettingsStore
        >
    with $Provider<CacheSettingsStore> {
  CacheSettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cacheSettingsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cacheSettingsStoreHash();

  @$internal
  @override
  $ProviderElement<CacheSettingsStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CacheSettingsStore create(Ref ref) {
    return cacheSettingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CacheSettingsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CacheSettingsStore>(value),
    );
  }
}

String _$cacheSettingsStoreHash() =>
    r'a2ca80bfa1b676fa07c93eec4b0fb9d7e5ecdd1e';
