// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_settings_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pushSettingsStore)
final pushSettingsStoreProvider = PushSettingsStoreProvider._();

final class PushSettingsStoreProvider
    extends
        $FunctionalProvider<
          PushSettingsStore,
          PushSettingsStore,
          PushSettingsStore
        >
    with $Provider<PushSettingsStore> {
  PushSettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushSettingsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushSettingsStoreHash();

  @$internal
  @override
  $ProviderElement<PushSettingsStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PushSettingsStore create(Ref ref) {
    return pushSettingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushSettingsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushSettingsStore>(value),
    );
  }
}

String _$pushSettingsStoreHash() => r'705ef9249e911bb67c8014ae3c3db2650998bee4';
