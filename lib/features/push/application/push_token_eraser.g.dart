// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_token_eraser.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pushTokenEraser)
final pushTokenEraserProvider = PushTokenEraserProvider._();

final class PushTokenEraserProvider
    extends
        $FunctionalProvider<PushTokenEraser, PushTokenEraser, PushTokenEraser>
    with $Provider<PushTokenEraser> {
  PushTokenEraserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushTokenEraserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushTokenEraserHash();

  @$internal
  @override
  $ProviderElement<PushTokenEraser> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushTokenEraser create(Ref ref) {
    return pushTokenEraser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushTokenEraser value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushTokenEraser>(value),
    );
  }
}

String _$pushTokenEraserHash() => r'5e2d3f8da413cd2b1887f8797406949309b9a0d7';

@ProviderFor(pushRegistrationPurger)
final pushRegistrationPurgerProvider = PushRegistrationPurgerProvider._();

final class PushRegistrationPurgerProvider
    extends
        $FunctionalProvider<
          PushRegistrationPurger,
          PushRegistrationPurger,
          PushRegistrationPurger
        >
    with $Provider<PushRegistrationPurger> {
  PushRegistrationPurgerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushRegistrationPurgerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushRegistrationPurgerHash();

  @$internal
  @override
  $ProviderElement<PushRegistrationPurger> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PushRegistrationPurger create(Ref ref) {
    return pushRegistrationPurger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushRegistrationPurger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushRegistrationPurger>(value),
    );
  }
}

String _$pushRegistrationPurgerHash() =>
    r'21eb096a07403623002e0a91806a42fdd3be655d';
