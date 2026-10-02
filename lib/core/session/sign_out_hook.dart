import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/push/application/push_notifications_controller.dart';

part 'sign_out_hook.g.dart';

/// 明示的なログアウトで、**認証トークンを失効させる前に**サーバーへ伝えること。
///
/// 端末内のデータの破棄（`SessionDataPurger`）はトークンを消した後に走るので、
/// Bearer が要る後始末（プッシュ通知の登録の解除 #14 など）はここに置く。
/// 失効（401）では呼ばれない（もう Bearer が通らない）。端末側だけで済む
/// 片付けは `SessionDataPurger` に置く。
abstract interface class SignOutHook {
  /// 何をするかの説明（ログ用）。
  String get debugLabel;

  /// 失敗してもログアウトは止めない（投げても `AuthController` が握る）。
  /// 長く待たせない（`AuthController.signOutHookTimeout` で打ち切られる）。
  Future<void> beforeSignOut();
}

/// 関数 1 つで済む [SignOutHook]。
class CallbackSignOutHook implements SignOutHook {
  const CallbackSignOutHook(this.debugLabel, this._callback);

  @override
  final String debugLabel;

  final Future<void> Function() _callback;

  @override
  Future<void> beforeSignOut() => _callback();
}

/// 登録済みのフック。ログアウトのたびに上から順に呼ぶ。
@Riverpod(keepAlive: true)
List<SignOutHook> signOutHooks(Ref ref) => [
  // プッシュ通知の登録の解除（#14）。DELETE に Bearer が要る。
  CallbackSignOutHook(
    'push registration',
    () =>
        ref.read(pushNotificationsProvider.notifier).unregisterBeforeSignOut(),
  ),
];
