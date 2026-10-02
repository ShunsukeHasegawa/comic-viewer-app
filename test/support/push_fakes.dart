import 'dart:async';

import 'package:comic_laz/core/device/notification_permission_log.dart';
import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/data/api/device_token_api.dart';
import 'package:comic_laz/features/push/data/foreground_notifier.dart';
import 'package:comic_laz/features/push/data/push_messaging.dart';
import 'package:comic_laz/features/push/data/push_settings_store.dart';
import 'package:comic_laz/features/push/domain/push_message.dart';

/// Firebase（プラットフォームチャネル）に触らない [PushMessaging]。
///
/// 既定は「使えない」（設定ファイルの無いビルドと同じ）。アプリ全体を出す
/// テストで、ログイン / ログアウトのたびに登録の処理が走らないようにする。
class FakePushMessaging implements PushMessaging {
  FakePushMessaging({
    this.available = false,
    this.permission = PushPermission.granted,
    this.permissionAfterRequest = PushPermission.granted,
    this.token = 'fcm-token-1',
    this.initialMessage,
    List<String>? log,
  }) : log = log ?? [];

  bool available;
  PushPermission permission;

  /// [requestPermission] の後の許可（ダイアログでの選択）。
  PushPermission permissionAfterRequest;

  /// [getToken] が返すトークン。[deleteToken] で次の値（`fcm-token-2` …）になる。
  String? token;

  PushMessage? initialMessage;

  /// 呼び出し順の記録（`AuthStore` / API の記録と混ぜて前後を確かめる）。
  final List<String> log;

  int initializeCalls = 0;
  int requestPermissionCalls = 0;
  int getTokenCalls = 0;
  int deleteTokenCalls = 0;

  /// [deleteToken] で投げる例外（圏外の再現）。
  Object? deleteTokenError;

  int _nextTokenNumber = 2;

  final _tokenRefresh = StreamController<String>.broadcast();
  final _messages = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();

  /// FCM がトークンを作り直した（`onTokenRefresh`）。
  void refreshToken(String next) {
    token = next;
    _tokenRefresh.add(next);
  }

  /// 前面にいる間に届いた。
  void receive(PushMessage message) => _messages.add(message);

  /// 背面で OS が出した通知を押して戻ってきた。
  void openFromBackground(PushMessage message) => _opened.add(message);

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    return available;
  }

  @override
  Future<PushPermission> permissionStatus() async => permission;

  @override
  Future<PushPermission> requestPermission() async {
    requestPermissionCalls++;
    log.add('request permission');
    permission = permissionAfterRequest;
    return permission;
  }

  @override
  Future<String?> getToken() async {
    getTokenCalls++;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => _tokenRefresh.stream;

  @override
  Future<void> deleteToken() async {
    deleteTokenCalls++;
    log.add('delete fcm token');
    if (deleteTokenError case final error?) throw error;
    token = 'fcm-token-${_nextTokenNumber++}';
  }

  @override
  Stream<PushMessage> get onMessage => _messages.stream;

  @override
  Stream<PushMessage> get onMessageOpenedApp => _opened.stream;

  @override
  Future<PushMessage?> getInitialMessage() async => initialMessage;
}

/// プラットフォームチャネルに触らない [ForegroundNotifier]。
class FakeForegroundNotifier implements ForegroundNotifier {
  FakeForegroundNotifier({this.launchData});

  /// 前面で出した通知を押して起動した、を再現する data。
  Map<String, String>? launchData;

  final shown = <PushMessage>[];
  int openSettingsCalls = 0;

  void Function(Map<String, String> data)? _onTap;

  /// 前面で出した通知を押した。
  void tap(Map<String, String> data) => _onTap!(data);

  @override
  Future<void> initialize({
    required void Function(Map<String, String> data) onTap,
  }) async => _onTap = onTap;

  @override
  Future<void> show(PushMessage message) async => shown.add(message);

  @override
  Future<Map<String, String>?> takeLaunchData() async => launchData;

  @override
  Future<void> openSystemSettings() async => openSettingsCalls++;
}

/// drift を使わない [PushSettingsStore]。
class InMemoryPushSettingsStore implements PushSettingsStore {
  InMemoryPushSettingsStore({
    this.enabled = true,
    this.registration,
    this.deletionPending = false,
  });

  bool enabled;
  PushRegistration? registration;
  bool deletionPending;

  /// [writeEnabled] で投げる例外（DB の障害）。
  Object? writeError;

  @override
  Future<bool> readEnabled() async => enabled;

  @override
  Future<void> writeEnabled(bool enabled) async {
    if (writeError case final error?) throw error;
    this.enabled = enabled;
  }

  @override
  Future<PushRegistration?> readRegistration() async => registration;

  @override
  Future<void> writeRegistration(PushRegistration registration) async =>
      this.registration = registration;

  @override
  Future<void> clearRegistration() async => registration = null;

  @override
  Future<bool> readTokenDeletionPending() async => deletionPending;

  @override
  Future<void> writeTokenDeletionPending(bool pending) async =>
      deletionPending = pending;
}

/// ネットワークを触らない [DeviceTokenApi]。
class FakeDeviceTokenApi implements DeviceTokenApi {
  FakeDeviceTokenApi({List<String>? log}) : log = log ?? [];

  /// 呼び出し順の記録（`register {token}` / `unregister {token}` / `test`）。
  final List<String> log;

  final registered = <({String token, String platform, String? deviceName})>[];
  final unregistered = <String>[];
  int testCalls = 0;

  /// 各操作で投げる例外（圏外 / サーバー障害の再現）。
  ApiException? registerError;
  ApiException? unregisterError;
  ApiException? testError;

  /// 設定すると、その応答まで [register] / [unregister] が返らない（遅い回線の再現）。
  /// 呼んだ時点で [log] には残る（サーバーへ送り出した = 届きうる）。
  Completer<void>? registerGate;
  Completer<void>? unregisterGate;

  @override
  Future<void> register({
    required String token,
    required String platform,
    String? deviceName,
  }) async {
    log.add('register $token');
    if (registerGate case final gate?) await gate.future;
    if (registerError case final error?) throw error;
    registered.add((token: token, platform: platform, deviceName: deviceName));
  }

  @override
  Future<void> unregister(String token) async {
    log.add('unregister $token');
    if (unregisterGate case final gate?) await gate.future;
    if (unregisterError case final error?) throw error;
    unregistered.add(token);
  }

  @override
  Future<void> sendTest() async {
    log.add('test');
    if (testError case final error?) throw error;
    testCalls++;
  }
}

/// drift を使わない [NotificationPermissionLog]。
class InMemoryNotificationPermissionLog implements NotificationPermissionLog {
  InMemoryNotificationPermissionLog({this.requested = false});

  bool requested;

  @override
  Future<bool> wasRequested() async => requested;

  @override
  Future<void> markRequested() async => requested = true;
}
