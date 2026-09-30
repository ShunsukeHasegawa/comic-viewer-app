// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'safe_mode_revalidation_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(safeModeRevalidationStore)
final safeModeRevalidationStoreProvider = SafeModeRevalidationStoreProvider._();

final class SafeModeRevalidationStoreProvider
    extends
        $FunctionalProvider<
          SafeModeRevalidationStore,
          SafeModeRevalidationStore,
          SafeModeRevalidationStore
        >
    with $Provider<SafeModeRevalidationStore> {
  SafeModeRevalidationStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'safeModeRevalidationStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$safeModeRevalidationStoreHash();

  @$internal
  @override
  $ProviderElement<SafeModeRevalidationStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SafeModeRevalidationStore create(Ref ref) {
    return safeModeRevalidationStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SafeModeRevalidationStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SafeModeRevalidationStore>(value),
    );
  }
}

String _$safeModeRevalidationStoreHash() =>
    r'4824738e40c34f1da4d6688290c25f04cdb88db3';

@ProviderFor(safeModeRevalidationPurger)
final safeModeRevalidationPurgerProvider =
    SafeModeRevalidationPurgerProvider._();

final class SafeModeRevalidationPurgerProvider
    extends
        $FunctionalProvider<
          SessionDataPurger,
          SessionDataPurger,
          SessionDataPurger
        >
    with $Provider<SessionDataPurger> {
  SafeModeRevalidationPurgerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'safeModeRevalidationPurgerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$safeModeRevalidationPurgerHash();

  @$internal
  @override
  $ProviderElement<SessionDataPurger> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionDataPurger create(Ref ref) {
    return safeModeRevalidationPurger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionDataPurger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionDataPurger>(value),
    );
  }
}

String _$safeModeRevalidationPurgerHash() =>
    r'ca8a486be02e0c15a233156de8429ad042199219';
