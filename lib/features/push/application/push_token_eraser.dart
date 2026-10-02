import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/session_data_purger.dart';
import '../data/push_messaging.dart';
import '../data/push_settings_store.dart';

part 'push_token_eraser.g.dart';

/// この端末の FCM トークンを捨てる（#14）。
///
/// ログアウト / 失効 / 通知 OFF のときに、サーバーの登録を消せたかどうかに
/// 関わらず端末側のトークンを無効にする。サーバーの DELETE は Bearer が要り、
/// 失効後や圏外では通らない。端末側で `deleteToken` しておけば、サーバーに
/// 残った行は次の送信で FCM が「未登録」と返し、サーバーが自分で掃除する
/// （`PushNotificationService::staleTokens`）。
///
/// `deleteToken` も通信が要るので、捨てる予約を DB に残してから消しにいき、
/// 消せなければ次の起動 / 次の登録の前に消し直す（[flush]）。
class PushTokenEraser {
  PushTokenEraser(
    this._messaging,
    this._store, {
    this.deleteTimeout = const Duration(seconds: 10),
  });

  final PushMessaging _messaging;
  final PushSettingsStore _store;

  /// `deleteToken` を待つ上限（圏外で FCM の SDK が粘っても次へ進む）。
  final Duration deleteTimeout;

  Future<bool>? _flushing;

  /// 捨てる予約のたびに進む番号。登録の途中でセッションが終わった / OFF に
  /// なったとき、古い登録の結果（控えの書き込み）を捨てるために使う。
  int get generation => _generation;
  int _generation = 0;

  /// 進行中の登録の結果を無効にする（予約はしない）。
  void invalidate() => _generation++;

  /// 捨てる予約をして、消しにいく（消し終わるのは待たない）。
  ///
  /// 予約を書けなければ投げる（`SessionDataPurger` として呼ばれたとき、
  /// 破棄の印を残して次の機会にやり直させるため）。
  Future<void> schedule() async {
    _generation++;
    // 予約を先に書く。控えを消した直後に落ちても、次の起動で消し直せるように。
    await _store.writeTokenDeletionPending(true);
    await _store.clearRegistration();
    unawaited(flush());
  }

  /// 予約が残っていれば消しにいく。予約が片付いたら `true`。
  ///
  /// 同時に呼ばれても 1 回にまとめる。
  Future<bool> flush() =>
      _flushing ??= _flush().whenComplete(() => _flushing = null);

  Future<bool> _flush() async {
    try {
      if (!await _store.readTokenDeletionPending()) return true;
      // Firebase が使えないビルドではトークンを作っていない（消すものが無い）。
      if (await _messaging.initialize()) {
        await _messaging.deleteToken().timeout(deleteTimeout);
      }
      await _store.writeTokenDeletionPending(false);
      return true;
    } on Object catch (error) {
      // 圏外など。予約は残り、次の起動 / 次の登録の前にもう一度消しにいく。
      debugPrint('[push] delete FCM token failed: $error');
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
PushTokenEraser pushTokenEraser(Ref ref) => PushTokenEraser(
  ref.watch(pushMessagingProvider),
  ref.watch(pushSettingsStoreProvider),
);

/// セッションの終わり（ログアウト / 失効 / ユーザーの切り替え）に、この端末の
/// FCM トークンを捨てる（#15 の破棄の枠組みに乗せる）。
///
/// 失効では Bearer が無効でサーバーの登録を消せないので、端末側で捨てて
/// 前のユーザーの通知が届き続けないようにする。明示的なログアウトでは
/// `AuthController.logout` がトークンを消す前にサーバーの登録を消してから
/// ここに来る（[PushTokenEraser.schedule] は 2 回呼ばれても害は無い）。
///
/// `purgesRefetchableOnly` は `false`。`safe_mode` の変更（同じユーザーの
/// まま）で走らせるとトークンを捨てて通知が止まり、意味が無い。
class PushRegistrationPurger implements SessionDataPurger {
  const PushRegistrationPurger(this._eraser);

  final PushTokenEraser _eraser;

  @override
  String get debugLabel => 'push registration';

  @override
  bool get purgesRefetchableOnly => false;

  /// 予約（DB）を書けなければ投げる。`deleteToken` の成否は待たない
  /// （圏外でログアウトを待たせない。消せなければ予約が次の起動でやり直す）。
  @override
  Future<void> purgeSessionData() => _eraser.schedule();
}

@Riverpod(keepAlive: true)
PushRegistrationPurger pushRegistrationPurger(Ref ref) =>
    PushRegistrationPurger(ref.watch(pushTokenEraserProvider));
