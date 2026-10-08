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
/// 前のセッションの破棄（[SessionPurgeScope.session]）の印が残っていれば、
/// 起動時とログイン時にセッションを始める**前に**やり直す。
///
/// **やり直しが失敗してもログイン / 復元は止めない**（#15 のレビュー指摘）。
/// これは個人用（利用者 1 人）のアプリとしての判断で、厳密なユーザー間の分離より
/// 使えることを優先した。止める（fail closed）と、毎回失敗する purger が 1 つ
/// あるだけ（例: 転送の記録の `reset` が投げ続ける）で二度とログインできなくなる。
/// 端末を使うのは同じ人なので、消し残るのはほぼ自分のデータで、締め出される
/// 損の方が大きい。止めない代わりに:
///   - 印は捨てる（残すと次の起動のやり直しが新しいセッションのデータまで消す）。
///   - ログイン時は [SessionCleanupNotice] で画面に知らせる（黙って通さない）。
///     起動時は同じユーザーのトークンで再開するだけなのでログに残す。

@ProviderFor(AuthController)
final authControllerProvider = AuthControllerProvider._();

/// ログイン状態の管理。
///
/// 端末内のコミックデータはログイン中のユーザーのものなので、
/// ログアウト / トークン失効では必ず [SessionDataPurger] を通して破棄する（#15）。
///
/// 前のセッションの破棄（[SessionPurgeScope.session]）の印が残っていれば、
/// 起動時とログイン時にセッションを始める**前に**やり直す。
///
/// **やり直しが失敗してもログイン / 復元は止めない**（#15 のレビュー指摘）。
/// これは個人用（利用者 1 人）のアプリとしての判断で、厳密なユーザー間の分離より
/// 使えることを優先した。止める（fail closed）と、毎回失敗する purger が 1 つ
/// あるだけ（例: 転送の記録の `reset` が投げ続ける）で二度とログインできなくなる。
/// 端末を使うのは同じ人なので、消し残るのはほぼ自分のデータで、締め出される
/// 損の方が大きい。止めない代わりに:
///   - 印は捨てる（残すと次の起動のやり直しが新しいセッションのデータまで消す）。
///   - ログイン時は [SessionCleanupNotice] で画面に知らせる（黙って通さない）。
///     起動時は同じユーザーのトークンで再開するだけなのでログに残す。
final class AuthControllerProvider
    extends $NotifierProvider<AuthController, AuthState> {
  /// ログイン状態の管理。
  ///
  /// 端末内のコミックデータはログイン中のユーザーのものなので、
  /// ログアウト / トークン失効では必ず [SessionDataPurger] を通して破棄する（#15）。
  ///
  /// 前のセッションの破棄（[SessionPurgeScope.session]）の印が残っていれば、
  /// 起動時とログイン時にセッションを始める**前に**やり直す。
  ///
  /// **やり直しが失敗してもログイン / 復元は止めない**（#15 のレビュー指摘）。
  /// これは個人用（利用者 1 人）のアプリとしての判断で、厳密なユーザー間の分離より
  /// 使えることを優先した。止める（fail closed）と、毎回失敗する purger が 1 つ
  /// あるだけ（例: 転送の記録の `reset` が投げ続ける）で二度とログインできなくなる。
  /// 端末を使うのは同じ人なので、消し残るのはほぼ自分のデータで、締め出される
  /// 損の方が大きい。止めない代わりに:
  ///   - 印は捨てる（残すと次の起動のやり直しが新しいセッションのデータまで消す）。
  ///   - ログイン時は [SessionCleanupNotice] で画面に知らせる（黙って通さない）。
  ///     起動時は同じユーザーのトークンで再開するだけなのでログに残す。
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

String _$authControllerHash() => r'205c3ea1ff68e51a9e08a4da49c4dde82f455a7d';

/// ログイン状態の管理。
///
/// 端末内のコミックデータはログイン中のユーザーのものなので、
/// ログアウト / トークン失効では必ず [SessionDataPurger] を通して破棄する（#15）。
///
/// 前のセッションの破棄（[SessionPurgeScope.session]）の印が残っていれば、
/// 起動時とログイン時にセッションを始める**前に**やり直す。
///
/// **やり直しが失敗してもログイン / 復元は止めない**（#15 のレビュー指摘）。
/// これは個人用（利用者 1 人）のアプリとしての判断で、厳密なユーザー間の分離より
/// 使えることを優先した。止める（fail closed）と、毎回失敗する purger が 1 つ
/// あるだけ（例: 転送の記録の `reset` が投げ続ける）で二度とログインできなくなる。
/// 端末を使うのは同じ人なので、消し残るのはほぼ自分のデータで、締め出される
/// 損の方が大きい。止めない代わりに:
///   - 印は捨てる（残すと次の起動のやり直しが新しいセッションのデータまで消す）。
///   - ログイン時は [SessionCleanupNotice] で画面に知らせる（黙って通さない）。
///     起動時は同じユーザーのトークンで再開するだけなのでログに残す。

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
