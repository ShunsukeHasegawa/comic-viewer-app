// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_metadata_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(offlineMetadataStore)
final offlineMetadataStoreProvider = OfflineMetadataStoreProvider._();

final class OfflineMetadataStoreProvider
    extends
        $FunctionalProvider<
          OfflineMetadataStore,
          OfflineMetadataStore,
          OfflineMetadataStore
        >
    with $Provider<OfflineMetadataStore> {
  OfflineMetadataStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineMetadataStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineMetadataStoreHash();

  @$internal
  @override
  $ProviderElement<OfflineMetadataStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OfflineMetadataStore create(Ref ref) {
    return offlineMetadataStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfflineMetadataStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfflineMetadataStore>(value),
    );
  }
}

String _$offlineMetadataStoreHash() =>
    r'9ef6f07a530fd3d33ef901be5f1bdd9790a51304';
