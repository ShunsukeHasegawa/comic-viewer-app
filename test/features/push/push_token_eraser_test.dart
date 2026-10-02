import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/features/push/application/push_token_eraser.dart';
import 'package:comic_laz/features/push/data/push_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/push_fakes.dart';

void main() {
  PushRegistration registration() => PushRegistration(
    userId: 1,
    token: 'fcm-token-1',
    registeredAt: DateTime.utc(2026, 10, 2),
  );

  test('予約を先に書き、控えを消してからトークンを捨てる（途中で落ちても次の起動で捨て直せる）', () async {
    final messaging = FakePushMessaging(available: true);
    final store = InMemoryPushSettingsStore(registration: registration());
    final eraser = PushTokenEraser(messaging, store);

    await eraser.schedule();
    // 予約と控えの片付けは schedule の中で済んでいる（消すのは待たない）。
    expect(store.registration, isNull);
    expect(store.deletionPending, isTrue);
    await pumpEventQueue();

    expect(messaging.deleteTokenCalls, 1);
    expect(store.deletionPending, isFalse);
  });

  test('捨てられなければ予約を残し、次の flush で捨て直す', () async {
    final messaging = FakePushMessaging(available: true)
      ..deleteTokenError = const NetworkException();
    final store = InMemoryPushSettingsStore();
    final eraser = PushTokenEraser(messaging, store);

    await eraser.schedule();
    await pumpEventQueue();
    expect(store.deletionPending, isTrue);

    messaging.deleteTokenError = null;
    expect(await eraser.flush(), isTrue);

    expect(messaging.deleteTokenCalls, 2);
    expect(store.deletionPending, isFalse);
  });

  test('予約が無ければ何もしない（起動のたびにトークンを作り直さない）', () async {
    final messaging = FakePushMessaging(available: true);
    final eraser = PushTokenEraser(messaging, InMemoryPushSettingsStore());

    expect(await eraser.flush(), isTrue);

    expect(messaging.deleteTokenCalls, 0);
  });

  test('Firebase の無いビルドではトークンが無いので、予約だけ下ろす', () async {
    final messaging = FakePushMessaging();
    final store = InMemoryPushSettingsStore(deletionPending: true);
    final eraser = PushTokenEraser(messaging, store);

    expect(await eraser.flush(), isTrue);

    expect(messaging.deleteTokenCalls, 0);
    expect(store.deletionPending, isFalse);
  });

  test('同時に呼ばれた flush は 1 回にまとめる', () async {
    final messaging = FakePushMessaging(available: true);
    final store = InMemoryPushSettingsStore(deletionPending: true);
    final eraser = PushTokenEraser(messaging, store);

    await Future.wait([eraser.flush(), eraser.flush()]);

    expect(messaging.deleteTokenCalls, 1);
  });

  test('予約のたびに世代が進む（進行中の登録の結果を捨てさせるため）', () async {
    final eraser = PushTokenEraser(
      FakePushMessaging(),
      InMemoryPushSettingsStore(),
    );
    final before = eraser.generation;

    eraser.invalidate();
    await eraser.schedule();

    expect(eraser.generation, before + 2);
  });
}
