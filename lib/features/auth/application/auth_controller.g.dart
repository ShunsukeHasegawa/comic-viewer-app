// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ログイン状態の管理。
///
/// 端末内のコミックデータはログイン中のユーザーのものなので、
/// ログアウト / トークン失効では必ず [SessionDataPurger] を通して破棄する（#15）。

@ProviderFor(AuthController)
final authControllerProvider = AuthControllerProvider._();

/// ログイン状態の管理。
///
/// 端末内のコミックデータはログイン中のユーザーのものなので、
/// ログアウト / トークン失効では必ず [SessionDataPurger] を通して破棄する（#15）。
final class AuthControllerProvider
    extends $NotifierProvider<AuthController, AuthState> {
  /// ログイン状態の管理。
  ///
  /// 端末内のコミックデータはログイン中のユーザーのものなので、
  /// ログアウト / トークン失効では必ず [SessionDataPurger] を通して破棄する（#15）。
  AuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authControllerHash();

  @$internal
  @override
  AuthController create() => AuthController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthState>(value),
    );
  }
}

String _$authControllerHash() => r'91353759a138c3f40f69c2b0c74a1c5e6c69bd98';

/// ログイン状態の管理。
///
/// 端末内のコミックデータはログイン中のユーザーのものなので、
/// ログアウト / トークン失効では必ず [SessionDataPurger] を通して破棄する（#15）。

abstract class _$AuthController extends $Notifier<AuthState> {
  AuthState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AuthState, AuthState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuthState, AuthState>,
              AuthState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
