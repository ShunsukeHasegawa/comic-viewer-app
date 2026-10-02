import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/features/push/domain/push_message.dart';
import 'package:comic_laz/features/push/presentation/push_notification_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/push_fakes.dart';
import '../../support/test_scope.dart';

void main() {
  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    required FakePushMessaging messaging,
    FakeDeviceTokenApi? api,
    FakeForegroundNotifier? notifier,
    InMemoryNotificationPermissionLog? permissionLog,
  }) async {
    final authApi = MockAuthApi()..stubCurrentUser();
    final container = createContainer(
      authStore: FakeAuthStore(token: 'valid', user: testUser),
      authApi: authApi,
      pushMessaging: messaging,
      deviceTokenApi: api,
      foregroundNotifier: notifier,
      notificationPermissionLog: permissionLog,
    );
    addTearDown(container.dispose);
    // 起動時の復元と登録は pumpAndSettle の中で進む（testWidgets の中では
    // settleAuth の pumpEventQueue が進まないため使わない）。
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: PushNotificationSettings()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  SwitchListTile switchTile(WidgetTester tester) =>
      tester.widget(find.byKey(PushNotificationSettings.switchKey));

  ListTile testTile(WidgetTester tester) =>
      tester.widget(find.byKey(PushNotificationSettings.testButtonKey));

  testWidgets('Firebase の無いビルドでは使えないことを出し、操作させない', (tester) async {
    await pumpSettings(tester, messaging: FakePushMessaging());

    expect(find.textContaining('このビルドではプッシュ通知を使えません'), findsOneWidget);
    expect(switchTile(tester).onChanged, isNull);
    expect(switchTile(tester).value, isFalse);
    expect(testTile(tester).enabled, isFalse);
  });

  testWidgets('登録できたら ON で表示し、テスト通知を送れる', (tester) async {
    final api = FakeDeviceTokenApi();
    await pumpSettings(
      tester,
      messaging: FakePushMessaging(available: true),
      api: api,
    );

    expect(switchTile(tester).value, isTrue);
    expect(find.textContaining('新しい巻が出たら通知します'), findsOneWidget);

    await tester.tap(find.byKey(PushNotificationSettings.testButtonKey));
    await tester.pumpAndSettle();

    expect(api.testCalls, 1);
    expect(find.textContaining('テスト通知を送りました'), findsOneWidget);
  });

  testWidgets('テスト通知を頼めなかったら理由を SnackBar で出す（黙って何も起きないようにしない）', (tester) async {
    final api = FakeDeviceTokenApi()..testError = const NetworkException();
    await pumpSettings(
      tester,
      messaging: FakePushMessaging(available: true),
      api: api,
    );

    await tester.tap(find.byKey(PushNotificationSettings.testButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text('テスト通知の送信に失敗しました: ${const NetworkException().message}'),
      findsOneWidget,
    );
  });

  testWidgets('通知が許可されていなければその旨と OS の設定を開く導線を出す', (tester) async {
    final notifier = FakeForegroundNotifier();
    await pumpSettings(
      tester,
      messaging: FakePushMessaging(
        available: true,
        permission: PushPermission.denied,
        permissionAfterRequest: PushPermission.denied,
      ),
      notifier: notifier,
    );

    expect(find.textContaining('通知が許可されていません'), findsOneWidget);
    expect(testTile(tester).enabled, isFalse);

    await tester.tap(find.byKey(PushNotificationSettings.openSettingsKey));
    await tester.pumpAndSettle();

    expect(notifier.openSettingsCalls, 1);
  });

  testWidgets('スイッチで OFF にするとサーバーの登録を消す', (tester) async {
    final api = FakeDeviceTokenApi();
    await pumpSettings(
      tester,
      messaging: FakePushMessaging(available: true),
      api: api,
    );

    await tester.tap(find.byKey(PushNotificationSettings.switchKey));
    await tester.pumpAndSettle();

    expect(api.unregistered, ['fcm-token-1']);
    expect(switchTile(tester).value, isFalse);
    expect(find.text('お気に入りの新刊を通知しません'), findsOneWidget);
  });

  testWidgets('ON にして登録に失敗したら SnackBar で知らせる', (tester) async {
    final api = FakeDeviceTokenApi();
    await pumpSettings(
      tester,
      messaging: FakePushMessaging(available: true),
      api: api,
    );
    await tester.tap(find.byKey(PushNotificationSettings.switchKey));
    await tester.pumpAndSettle();
    api.registerError = const NetworkException();

    await tester.tap(find.byKey(PushNotificationSettings.switchKey));
    await tester.pumpAndSettle();

    expect(
      find.text('新刊通知の登録に失敗しました: ${const NetworkException().message}'),
      findsOneWidget,
    );
    // SnackBar が消えた後も「登録しています…」と事実と違う表示を続けない。
    expect(find.text('登録しています…'), findsNothing);
    expect(
      find.textContaining('登録できませんでした: ${const NetworkException().message}'),
      findsOneWidget,
    );
  });

  testWidgets('OFF にしても止めきれなかったら、OFF のまま警告を出す（「通知しません」と言い切らない）', (
    tester,
  ) async {
    final api = FakeDeviceTokenApi();
    final messaging = FakePushMessaging(available: true);
    await pumpSettings(tester, messaging: messaging, api: api);
    api.unregisterError = const NetworkException();
    messaging.deleteTokenError = const NetworkException();

    await tester.tap(find.byKey(PushNotificationSettings.switchKey));
    await tester.pumpAndSettle();

    expect(switchTile(tester).value, isFalse);
    expect(find.textContaining('新刊通知の解除に失敗しました'), findsOneWidget);
    expect(find.text('お気に入りの新刊を通知しません'), findsNothing);
    final subtitle = tester.widget<Text>(
      find.descendant(
        of: find.byKey(PushNotificationSettings.switchKey),
        matching: find.textContaining('まだ止められていません'),
      ),
    );
    // 警告の色で出す。
    expect(subtitle.style?.color, isNotNull);
  });
}
