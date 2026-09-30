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
///
/// **セッション全体の破棄（[SessionPurgeScope.session]）が済んでいない間は
/// ログイン済みにしない**（#15 のレビュー指摘）。進捗の行には持ち主が無いので、
/// 前のユーザーの未送信の進捗が新しいユーザーのトークンでサーバーへ送られ
/// （取り消せない）、前のユーザーの巻も新しいユーザーに見えてしまうため。
/// これにより「ログイン中なのに破棄の印が残っている」状態も生まれず、起動の
/// たびのやり直しがログイン中のユーザーの進捗やダウンロードを消すこともない。

@ProviderFor(AuthController)
final authControllerProvider = AuthControllerProvider._();

/// ログイン状態の管理。
///
/// 端末内のコミックデータはログイン中のユーザーのものなので、
/// ログアウト / トークン失効では必ず [SessionDataPurger] を通して破棄する（#15）。
///
/// **セッション全体の破棄（[SessionPurgeScope.session]）が済んでいない間は
/// ログイン済みにしない**（#15 のレビュー指摘）。進捗の行には持ち主が無いので、
/// 前のユーザーの未送信の進捗が新しいユーザーのトークンでサーバーへ送られ
/// （取り消せない）、前のユーザーの巻も新しいユーザーに見えてしまうため。
/// これにより「ログイン中なのに破棄の印が残っている」状態も生まれず、起動の
/// たびのやり直しがログイン中のユーザーの進捗やダウンロードを消すこともない。
final class AuthControllerProvider
    extends $NotifierProvider<AuthController, AuthState> {
  /// ログイン状態の管理。
  ///
  /// 端末内のコミックデータはログイン中のユーザーのものなので、
  /// ログアウト / トークン失効では必ず [SessionDataPurger] を通して破棄する（#15）。
  ///
  /// **セッション全体の破棄（[SessionPurgeScope.session]）が済んでいない間は
  /// ログイン済みにしない**（#15 のレビュー指摘）。進捗の行には持ち主が無いので、
  /// 前のユーザーの未送信の進捗が新しいユーザーのトークンでサーバーへ送られ
  /// （取り消せない）、前のユーザーの巻も新しいユーザーに見えてしまうため。
  /// これにより「ログイン中なのに破棄の印が残っている」状態も生まれず、起動の
  /// たびのやり直しがログイン中のユーザーの進捗やダウンロードを消すこともない。
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

String _$authControllerHash() => r'45d6ad6786bac4177b85ba2d7eea7d4845919ab2';

/// ログイン状態の管理。
///
/// 端末内のコミックデータはログイン中のユーザーのものなので、
/// ログアウト / トークン失効では必ず [SessionDataPurger] を通して破棄する（#15）。
///
/// **セッション全体の破棄（[SessionPurgeScope.session]）が済んでいない間は
/// ログイン済みにしない**（#15 のレビュー指摘）。進捗の行には持ち主が無いので、
/// 前のユーザーの未送信の進捗が新しいユーザーのトークンでサーバーへ送られ
/// （取り消せない）、前のユーザーの巻も新しいユーザーに見えてしまうため。
/// これにより「ログイン中なのに破棄の印が残っている」状態も生まれず、起動の
/// たびのやり直しがログイン中のユーザーの進捗やダウンロードを消すこともない。

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
