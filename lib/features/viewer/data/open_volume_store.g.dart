// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_volume_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(openVolumeStore)
final openVolumeStoreProvider = OpenVolumeStoreProvider._();

final class OpenVolumeStoreProvider
    extends
        $FunctionalProvider<OpenVolumeStore, OpenVolumeStore, OpenVolumeStore>
    with $Provider<OpenVolumeStore> {
  OpenVolumeStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openVolumeStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openVolumeStoreHash();

  @$internal
  @override
  $ProviderElement<OpenVolumeStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OpenVolumeStore create(Ref ref) {
    return openVolumeStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OpenVolumeStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OpenVolumeStore>(value),
    );
  }
}

String _$openVolumeStoreHash() => r'ddf7c35175a9428da12fdd24a19e72104cf4dc48';

@ProviderFor(openVolumePurger)
final openVolumePurgerProvider = OpenVolumePurgerProvider._();

final class OpenVolumePurgerProvider
    extends
        $FunctionalProvider<
          SessionDataPurger,
          SessionDataPurger,
          SessionDataPurger
        >
    with $Provider<SessionDataPurger> {
  OpenVolumePurgerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openVolumePurgerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openVolumePurgerHash();

  @$internal
  @override
  $ProviderElement<SessionDataPurger> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionDataPurger create(Ref ref) {
    return openVolumePurger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionDataPurger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionDataPurger>(value),
    );
  }
}

String _$openVolumePurgerHash() => r'bbddd707e234d0f3ee7a0eb300db4be1fd6522a5';
