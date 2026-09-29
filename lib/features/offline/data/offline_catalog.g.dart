// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_catalog.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(offlineCatalog)
final offlineCatalogProvider = OfflineCatalogProvider._();

final class OfflineCatalogProvider
    extends $FunctionalProvider<OfflineCatalog, OfflineCatalog, OfflineCatalog>
    with $Provider<OfflineCatalog> {
  OfflineCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineCatalogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineCatalogHash();

  @$internal
  @override
  $ProviderElement<OfflineCatalog> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OfflineCatalog create(Ref ref) {
    return offlineCatalog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfflineCatalog value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfflineCatalog>(value),
    );
  }
}

String _$offlineCatalogHash() => r'ff682083de8933cf33499d9563bda611076be261';
