// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authStore)
final authStoreProvider = AuthStoreProvider._();

final class AuthStoreProvider
    extends $FunctionalProvider<AuthStore, AuthStore, AuthStore>
    with $Provider<AuthStore> {
  AuthStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStoreHash();

  @$internal
  @override
  $ProviderElement<AuthStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthStore create(Ref ref) {
    return authStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthStore>(value),
    );
  }
}

String _$authStoreHash() => r'0a060e1568090cd52ed36d77cf5f286e0b94a963';
