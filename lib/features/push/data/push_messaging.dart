import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/push_message.dart';

part 'push_messaging.g.dart';

/// プッシュ通知の受信側（FCM）の窓口（#14）。
///
/// 本物は Firebase（プラットフォームチャネル）なので、テストでは
/// `FakePushMessaging` に差し替える。Firebase の設定ファイル
/// （`android/app/google-services.json`）はリポジトリに無く、置かれていない
/// ビルドでは [initialize] が `false` を返す（プッシュ通知だけ使えない状態で動く）。
abstract interface class PushMessaging {
  /// Firebase を初期化する。使えなければ `false`（投げない）。何度呼んでもよい。
  Future<bool> initialize();

  Future<PushPermission> permissionStatus();

  /// 通知の許可を求める（Android 13 以上はダイアログ。それより前は状態を返すだけ）。
  Future<PushPermission> requestPermission();

  /// この端末の FCM トークン（取れなければ `null`）。
  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  /// この端末の FCM トークンを無効にする（以降このトークン宛ては届かない）。
  /// 圏外では投げる。
  Future<void> deleteToken();

  /// アプリが前面にいる間に届いたもの（OS は表示しない）。
  Stream<PushMessage> get onMessage;

  /// 背面にいる間に OS が出した通知を押して戻ってきたもの。
  Stream<PushMessage> get onMessageOpenedApp;

  /// 終了中に OS が出した通知を押して起動したなら、その通知。
  Future<PushMessage?> getInitialMessage();
}

/// 背面 / 終了中に届いたメッセージの受け口（**登録していない**）。
///
/// いまのサーバーは notification だけを送り、表示は OS が行うので受け口は要らない。
/// `FirebaseMessaging.onBackgroundMessage` に登録すると、背面にいる間に届くたびに
/// firebase_messaging が全プラグイン付きの headless FlutterEngine を起こす。
/// そこに background_downloader も繋がり、メインのエンジンが外れていた（スワイプで
/// 閉じたが WorkManager の転送でプロセスが残っていた）と `BDPlugin.firstBackgroundChannel`
/// を奪う。以降、前の画面で積んだ巻の完了 / 進捗が受け手のいない isolate へ送られ、
/// 次のコールドスタートまでダウンロードが止まって見える。
///
/// data だけのメッセージを足すなら、この干渉を確かめてから登録する（ハンドラで
/// `FileDownloader` を起こす / 前面復帰で転送の状態を取り直すなど）。別の isolate で
/// 動くので、アプリの状態（Riverpod / DB）には触らない。
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Firebase の実装。
class FirebasePushMessaging implements PushMessaging {
  Future<bool>? _initialized;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<bool> initialize() => _initialized ??= _initialize();

  Future<bool> _initialize() async {
    try {
      // 設定ファイルが無いビルドではここで投げる（core/not-initialized など）。
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      // onBackgroundMessage は登録しない（firebaseMessagingBackgroundHandler を参照）。
      return true;
    } on Object catch (error) {
      debugPrint('[push] Firebase unavailable: $error');
      return false;
    }
  }

  @override
  Future<PushPermission> permissionStatus() async =>
      _permissionOf(await _messaging.getNotificationSettings());

  @override
  Future<PushPermission> requestPermission() async =>
      _permissionOf(await _messaging.requestPermission());

  static PushPermission _permissionOf(NotificationSettings settings) =>
      switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermission.granted,
        // Android 13 以上で 2 回断られた（以降はダイアログが出ない）。
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<PushMessage> get onMessage => FirebaseMessaging.onMessage.map(_toPush);

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(_toPush);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _toPush(message);
  }

  static PushMessage _toPush(RemoteMessage message) => PushMessage(
    title: message.notification?.title,
    body: message.notification?.body,
    data: stringifyPushData(message.data),
  );
}

@Riverpod(keepAlive: true)
PushMessaging pushMessaging(Ref ref) => FirebasePushMessaging();
