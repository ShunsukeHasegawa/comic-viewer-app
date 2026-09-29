// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_metadata_purger.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(offlineMetadataPurger)
final offlineMetadataPurgerProvider = OfflineMetadataPurgerProvider._();

final class OfflineMetadataPurgerProvider
    extends
        $FunctionalProvider<
          SessionDataPurger,
          SessionDataPurger,
          SessionDataPurger
        >
    with $Provider<SessionDataPurger> {
  OfflineMetadataPurgerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineMetadataPurgerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineMetadataPurgerHash();

  @$internal
  @override
  $ProviderElement<SessionDataPurger> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionDataPurger create(Ref ref) {
    return offlineMetadataPurger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionDataPurger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionDataPurger>(value),
    );
  }
}

String _$offlineMetadataPurgerHash() =>
    r'933307f661facd76060afcf61fa0854bd76e3079';
