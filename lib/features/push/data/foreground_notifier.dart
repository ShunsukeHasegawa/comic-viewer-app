import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/push_message.dart';

part 'foreground_notifier.g.dart';

/// アプリが前面にいる間に届いたプッシュ通知を出す（#14）。
///
/// FCM は前面にいる間の notification メッセージを OS に表示させない
/// （`onMessage` に渡すだけ）ので、自前で出す。本物はプラットフォーム
/// チャネルなので、テストでは `FakeForegroundNotifier` に差し替える。
abstract interface class ForegroundNotifier {
  /// チャネルを作り、通知を押したときの受け口を登録する。
  /// [onTap] には表示時に持たせた data が渡る。
  Future<void> initialize({
    required void Function(Map<String, String> data) onTap,
  });

  Future<void> show(PushMessage message);

  /// 前面で出した通知を（アプリが終了した後に）押して起動したなら、その data。
  Future<Map<String, String>?> takeLaunchData();

  /// OS の「このアプリの通知」の設定画面を開く（断られた後に許可してもらう導線）。
  Future<void> openSystemSettings();
}

/// flutter_local_notifications の実装。
class LocalForegroundNotifier implements ForegroundNotifier {
  LocalForegroundNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// 新刊通知のチャネル。AndroidManifest の
  /// `com.google.firebase.messaging.default_notification_channel_id` と同じ値
  /// （背面で OS が出す FCM の通知も同じチャネルに入れ、設定画面で 1 つに見せる）。
  /// 巻のダウンロードの進捗通知（background_downloader のチャネル）とは分ける
  /// （片方だけ切れるように）。
  static const channelId = 'new_volumes';
  static const channelName = '新刊のお知らせ';
  static const channelDescription = 'お気に入りのタイトルに新しい巻が追加されたときの通知';

  /// res/drawable-*/ic_stat_notify.png（`tool/make_notification_icon.py` で生成）。
  static const smallIcon = 'ic_stat_notify';

  /// ブランドカラー（AndroidManifest の既定の通知色と同じ）。
  static const accentColor = Color(0xFF244C60);

  /// 通知の tag。ダウンロードの進捗通知（tag 無し）と ID が重なっても
  /// 上書きし合わないようにする（OS は tag と ID の組で通知を見分ける）。
  static const tag = 'new_volumes';

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize({
    required void Function(Map<String, String> data) onTap,
  }) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(smallIcon),
        // iOS は対象外（#14 は Android のみ）。初期化で許可を求めないことだけ決めておく
        // （許可は FCM 側で求める）。
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          onTap(decodePushPayload(response.payload)),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.high,
          ),
        );
  }

  @override
  Future<void> show(PushMessage message) => _plugin.show(
    // 1 通ごとに別の通知にする（同じ ID だと前の新刊通知を上書きして消す）。
    id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
    title: message.title,
    body: message.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: smallIcon,
        color: accentColor,
        tag: tag,
        // サーバーの本文は「更新タイトル一覧」の複数行。折りたたまずに読めるようにする。
        styleInformation: BigTextStyleInformation(message.body ?? ''),
      ),
    ),
    payload: encodePushPayload(message.data),
  );

  @override
  Future<Map<String, String>?> takeLaunchData() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return decodePushPayload(details.notificationResponse?.payload);
  }

  @override
  Future<void> openSystemSettings() async {
    try {
      await _plugin.openAppNotificationSettings();
    } on Object catch (error) {
      debugPrint('[push] open notification settings failed: $error');
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
ForegroundNotifier foregroundNotifications(Ref ref) =>
    LocalForegroundNotifier();
