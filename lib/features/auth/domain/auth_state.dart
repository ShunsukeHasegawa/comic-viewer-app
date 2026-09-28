import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/models/user.dart';

part 'auth_state.freezed.dart';

/// ログイン状態が終了した理由。
enum SessionEndReason {
  /// 明示的なログアウト。
  signedOut,

  /// トークンが失効した（401）。
  expired,
}

/// 認証状態。
@freezed
sealed class AuthState with _$AuthState {
  /// 起動直後。保存済みトークンの検証中。
  const factory AuthState.restoring() = AuthRestoring;

  /// 未ログイン。
  const factory AuthState.unauthenticated({SessionEndReason? reason}) =
      AuthUnauthenticated;

  /// ログイン済み。
  const factory AuthState.authenticated(User user) = AuthAuthenticated;
}
