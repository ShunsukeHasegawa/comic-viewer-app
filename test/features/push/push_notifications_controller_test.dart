import 'dart:async';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/router/app_routes.dart';
import 'package:comic_laz/core/session/session_data_purger.dart';
import 'package:comic_laz/domain/models/user.dart';
import 'package:comic_laz/features/auth/application/auth_controller.dart';
import 'package:comic_laz/features/auth/data/auth_api.dart';
import 'package:comic_laz/features/auth/domain/auth_state.dart';
import 'package:comic_laz/features/push/application/push_notifications_controller.dart';
import 'package:comic_laz/features/push/application/push_token_eraser.dart';
import 'package:comic_laz/features/push/data/push_settings_store.dart';
import 'package:comic_laz/features/push/domain/push_message.dart';
import 'package:comic_laz/features/push/domain/push_status.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/auth_fakes.dart';
import '../../support/progress_fakes.dart';
import '../../support/push_fakes.dart';
import '../../support/test_scope.dart';

/// プッシュ通知のテストの道具一式。
///
/// 呼び出し順を 1 本の [log] に集める（サーバーの解除・認証トークンの失効・
/// 端末内のトークンの削除の前後を確かめるため）。
class _Fixture {
  _Fixture({
    bool signedIn = true,
    bool available = true,
    PushPermission permission = PushPermission.granted,
    PushPermission permissionAfterRequest = PushPermission.granted,
    InMemoryPushSettingsStore? store,
  }) : store = store ?? InMemoryPushSettingsStore() {
    messaging = FakePushMessaging(
      available: available,
      permission: permission,
      permissionAfterRequest: permissionAfterRequest,
      log: log,
    );
    api = FakeDeviceTokenApi(log: log);
    authStore = FakeAuthStore(
      token: signedIn ? 'valid' : null,
      user: signedIn ? testUser : null,
      log: log,
    );
    eraser = PushTokenEraser(messaging, this.store);
    when(authApi.fetchCurrentUser).thenAnswer((_) async => testUser);
    when(authApi.deleteToken).thenAnswer((_) async => log.add('revoke auth'));
  }

  final log = <String>[];
  late final FakePushMessaging messaging;
  late final FakeDeviceTokenApi api;
  late final FakeAuthStore authStore;
  late final PushTokenEraser eraser;
  final InMemoryPushSettingsStore store;
  final notifier = FakeForegroundNotifier();
  final permissionLog = InMemoryNotificationPermissionLog();
  final resume = FakeAppResumeMonitor();
  final authApi = MockAuthApi();
  final opened = <String>[];
  DateTime now = DateTime.utc(2026, 10, 2, 9);

  /// 本番と同じく、セッションの終わりにトークンを捨てる破棄を登録したコンテナ。
  ProviderContainer build() {
    final container = createContainer(
      authStore: authStore,
      authApi: authApi,
      purgers: [PushRegistrationPurger(eraser)],
      appResumeMonitor: resume,
      pushMessaging: messaging,
      foregroundNotifier: notifier,
      pushSettingsStore: store,
      deviceTokenApi: api,
      notificationPermissionLog: permissionLog,
      overrides: [
        pushTokenEraserProvider.overrideWithValue(eraser),
        pushRouteOpenerProvider.overrideWithValue(opened.add),
        pushClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// アプリの起動（`ComicLazApp` が購読するのと同じく、すぐに作る）。
  Future<ProviderContainer> start() async {
    final container = build();
    container.read(pushNotificationsProvider);
    await settleAuth(container);
    await pumpEventQueue();
    return container;
  }

  List<String> get registeredTokens => [
    for (final entry in api.registered) entry.token,
  ];

  /// サーバーへ送り出した登録の数（失敗したものも数える）。
  int get registerAttempts =>
      log.where((entry) => entry.startsWith('register ')).length;

  /// ログインできるようにする（ログアウト後にログインし直すテスト用）。
  void allowLogin() {
    when(
      () => authApi.createToken(
        email: any(named: 'email'),
        password: any(named: 'password'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenAnswer(
      (_) async => const AuthTokenResult(token: 'new', user: testUser),
    );
  }
}

PushNotifications _controller(ProviderContainer container) =>
    container.read(pushNotificationsProvider.notifier);

PushStatus _status(ProviderContainer container) =>
    container.read(pushNotificationsProvider);

void main() {
  setUpAll(() {
    registerFallbackValue(const User(id: 0));
  });

  group('登録', () {
    test('起動時にログイン済みなら、この端末のトークンを android として登録する', () async {
      final fixture = _Fixture();

      final container = await fixture.start();

      expect(fixture.api.registered, [
        (token: 'fcm-token-1', platform: 'android', deviceName: 'Test Device'),
      ]);
      final saved = fixture.store.registration!;
      expect(saved.userId, testUser.id);
      expect(saved.token, 'fcm-token-1');
      expect(saved.registeredAt, fixture.now);
      expect(
        _status(container),
        const PushStatus(
          availability: PushAvailability.available,
          enabled: true,
          permission: PushPermission.granted,
          registered: true,
        ),
      );
    });

    test('未ログインでは登録せず、ログインしたら登録する', () async {
      final fixture = _Fixture(signedIn: false);
      when(
        () => fixture.authApi.createToken(
          email: any(named: 'email'),
          password: any(named: 'password'),
          deviceName: any(named: 'deviceName'),
        ),
      ).thenAnswer(
        (_) async => const AuthTokenResult(token: 'new', user: testUser),
      );
      final container = await fixture.start();
      expect(fixture.api.registered, isEmpty);

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'a@example.com', password: 'secret');
      await pumpEventQueue();

      expect(fixture.registeredTokens, ['fcm-token-1']);
    });

    test('24 時間以内の前面復帰では送り直さない（自宅サーバーを叩きすぎない）', () async {
      final fixture = _Fixture();
      await fixture.start();

      fixture.now = fixture.now.add(const Duration(hours: 23));
      fixture.resume.resume();
      await pumpEventQueue();
      fixture.resume.resume();
      await pumpEventQueue();

      expect(fixture.registeredTokens, ['fcm-token-1']);
    });

    test('24 時間を過ぎた前面復帰では送り直す（サーバーの last_used_at を保つ）', () async {
      final fixture = _Fixture();
      await fixture.start();

      fixture.now = fixture.now.add(const Duration(hours: 24));
      fixture.resume.resume();
      await pumpEventQueue();

      expect(fixture.registeredTokens, ['fcm-token-1', 'fcm-token-1']);
    });

    test('控えが別のユーザーのものなら送り直す（サーバーで持ち主を移すため）', () async {
      final fixture = _Fixture(
        store: InMemoryPushSettingsStore(
          registration: PushRegistration(
            userId: 99,
            token: 'fcm-token-1',
            registeredAt: DateTime.utc(2026, 10, 2, 8),
          ),
        ),
      );

      await fixture.start();

      expect(fixture.registeredTokens, ['fcm-token-1']);
      expect(fixture.store.registration!.userId, testUser.id);
    });

    test('控えの時刻が未来（時計が戻った）なら古いとみなして送り直す', () async {
      final fixture = _Fixture(
        store: InMemoryPushSettingsStore(
          registration: PushRegistration(
            userId: testUser.id,
            token: 'fcm-token-1',
            registeredAt: DateTime.utc(2026, 10, 3),
          ),
        ),
      );

      await fixture.start();

      expect(fixture.registeredTokens, ['fcm-token-1']);
    });

    test('トークンが作り直されたら新しいトークンを登録する', () async {
      final fixture = _Fixture();
      await fixture.start();

      fixture.messaging.refreshToken('fcm-token-new');
      await pumpEventQueue();

      expect(fixture.registeredTokens, ['fcm-token-1', 'fcm-token-new']);
      expect(fixture.store.registration!.token, 'fcm-token-new');
    });

    test('登録に失敗したら状態に出し、前面復帰でのやり直しは 1 時間に 1 回まで（自宅サーバーを叩き続けない）', () async {
      final fixture = _Fixture();
      fixture.api.registerError = const NetworkException();
      final container = await fixture.start();

      expect(_status(container).registered, isFalse);
      expect(_status(container).failure, const NetworkException().message);
      expect(fixture.store.registration, isNull);
      // 起動時は初期化の終わりと復元の両方から頼まれるが、まとめて 1 回だけ送る。
      expect(fixture.registerAttempts, 1);

      // アプリを切り替えるたびに送らない。失敗の表示は残す（黙って直ったことにしない）。
      fixture.api.registerError = null;
      fixture.now = fixture.now.add(const Duration(minutes: 59));
      fixture.resume.resume();
      await pumpEventQueue();
      expect(fixture.registerAttempts, 1);
      expect(_status(container).failure, isNotNull);

      fixture.now = fixture.now.add(const Duration(minutes: 1));
      fixture.resume.resume();
      await pumpEventQueue();

      expect(fixture.registerAttempts, 2);
      expect(_status(container).registered, isTrue);
      expect(_status(container).failure, isNull);
    });

    test('失敗の直後でも、トークンの更新とスイッチの操作ではすぐ登録し直す（新しいトークンを届かないままにしない）', () async {
      final fixture = _Fixture();
      fixture.api.registerError = const NetworkException();
      final container = await fixture.start();

      fixture.api.registerError = null;
      fixture.messaging.refreshToken('fcm-token-new');
      await pumpEventQueue();
      expect(fixture.registeredTokens, ['fcm-token-new']);

      fixture.api.registerError = const ServerException(statusCode: 500);
      fixture.messaging.refreshToken('fcm-token-3');
      await pumpEventQueue();
      expect(_status(container).failure, isNotNull);

      fixture.api.registerError = null;
      await _controller(container).setEnabled(true);

      expect(fixture.registeredTokens, ['fcm-token-new', 'fcm-token-3']);
      expect(_status(container).failure, isNull);
    });

    test('トークンが取れなければ失敗として出す', () async {
      final fixture = _Fixture();
      fixture.messaging.token = null;

      final container = await fixture.start();

      expect(_status(container).failure, isNotNull);
      expect(fixture.api.registered, isEmpty);
    });
  });

  group('通知の許可', () {
    test('まだ聞いていなければ一度だけ聞き、許可されたら登録する', () async {
      final fixture = _Fixture(permission: PushPermission.denied);

      await fixture.start();

      expect(fixture.messaging.requestPermissionCalls, 1);
      expect(fixture.permissionLog.requested, isTrue);
      expect(fixture.registeredTokens, ['fcm-token-1']);
    });

    test('断られたら登録せず、前面復帰のたびに聞き直さない', () async {
      final fixture = _Fixture(
        permission: PushPermission.denied,
        permissionAfterRequest: PushPermission.denied,
      );
      final container = await fixture.start();

      fixture.resume.resume();
      await pumpEventQueue();

      expect(fixture.messaging.requestPermissionCalls, 1);
      expect(fixture.api.registered, isEmpty);
      expect(_status(container).permission, PushPermission.denied);
      expect(_status(container).registered, isFalse);
    });

    test('ダウンロードの通知で既に聞いていたら自動では聞かない（二重にダイアログを出さない）', () async {
      final fixture = _Fixture(permission: PushPermission.denied);
      fixture.permissionLog.requested = true;

      final container = await fixture.start();

      expect(fixture.messaging.requestPermissionCalls, 0);
      expect(_status(container).permission, PushPermission.denied);
    });

    test('OS の設定で許可されたら、次の前面復帰で登録する', () async {
      final fixture = _Fixture(
        permission: PushPermission.denied,
        permissionAfterRequest: PushPermission.denied,
      );
      final container = await fixture.start();

      fixture.messaging.permission = PushPermission.granted;
      fixture.resume.resume();
      await pumpEventQueue();

      expect(fixture.registeredTokens, ['fcm-token-1']);
      expect(_status(container).permission, PushPermission.granted);
    });
  });

  group('設定の ON / OFF', () {
    test('OFF にするとサーバーの登録を消し、端末のトークンも捨てる', () async {
      final fixture = _Fixture();
      final container = await fixture.start();

      await _controller(container).setEnabled(false);
      await pumpEventQueue();

      expect(fixture.api.unregistered, ['fcm-token-1']);
      expect(fixture.messaging.deleteTokenCalls, 1);
      expect(fixture.store.enabled, isFalse);
      expect(fixture.store.registration, isNull);
      expect(fixture.store.deletionPending, isFalse);
      expect(_status(container).enabled, isFalse);
      expect(_status(container).registered, isFalse);
      // サーバーの登録を消してから端末のトークンを捨てる（消す相手が分かるうちに）。
      expect(
        fixture.log.indexOf('unregister fcm-token-1'),
        lessThan(fixture.log.indexOf('delete fcm token')),
      );
    });

    test('ON に戻すと新しいトークンを登録する（前面復帰を待たない）', () async {
      final fixture = _Fixture();
      final container = await fixture.start();
      await _controller(container).setEnabled(false);
      await pumpEventQueue();

      await _controller(container).setEnabled(true);

      expect(fixture.registeredTokens, ['fcm-token-1', 'fcm-token-2']);
      expect(_status(container).registered, isTrue);
    });

    test('自分で ON にしたときは、断った後でも許可を聞き直す', () async {
      final fixture = _Fixture(
        permission: PushPermission.denied,
        permissionAfterRequest: PushPermission.denied,
      );
      final container = await fixture.start();
      expect(fixture.messaging.requestPermissionCalls, 1);
      await _controller(container).setEnabled(false);
      fixture.messaging.permissionAfterRequest = PushPermission.granted;

      await _controller(container).setEnabled(true);

      expect(fixture.messaging.requestPermissionCalls, 2);
      expect(_status(container).registered, isTrue);
    });

    test('OFF のまま起動したら、許可も聞かず登録もしない', () async {
      final fixture = _Fixture(
        permission: PushPermission.denied,
        store: InMemoryPushSettingsStore(enabled: false),
      );

      final container = await fixture.start();

      expect(fixture.messaging.requestPermissionCalls, 0);
      expect(fixture.api.registered, isEmpty);
      expect(_status(container).enabled, isFalse);
    });

    test('設定を保存できなければ投げ、表示は変えない（保存できていないのに切り替わって見せない）', () async {
      final fixture = _Fixture();
      final container = await fixture.start();
      fixture.store.writeError = StateError('disk full');

      await expectLater(
        _controller(container).setEnabled(false),
        throwsA(isA<StateError>()),
      );

      expect(_status(container).enabled, isTrue);
      expect(fixture.api.unregistered, isEmpty);
    });

    test('ON にしたときの登録の失敗は呼び出し側に投げる（SnackBar で知らせる）', () async {
      final fixture = _Fixture(
        store: InMemoryPushSettingsStore(enabled: false),
      );
      final container = await fixture.start();
      fixture.api.registerError = const ServerException(statusCode: 500);

      await expectLater(
        _controller(container).setEnabled(true),
        throwsA(isA<ServerException>()),
      );

      // SnackBar が消えた後も「登録しています…」のまま止まって見せない。
      expect(_status(container).enabled, isTrue);
      expect(_status(container).registered, isFalse);
      expect(_status(container).failure, isNotNull);
    });

    test('OFF で解除も端末のトークンの破棄もできなければ投げ、止めきれていないことを状態に残す', () async {
      final fixture = _Fixture();
      final container = await fixture.start();
      fixture.api.unregisterError = const NetworkException();
      fixture.messaging.deleteTokenError = const NetworkException();

      // 黙って「通知しません」と出すと、OS が出し続ける通知の理由が分からない。
      await expectLater(
        _controller(container).setEnabled(false),
        throwsA(isA<PushRegistrationException>()),
      );

      expect(_status(container).enabled, isFalse);
      expect(_status(container).failure, isNotNull);
      expect(fixture.store.deletionPending, isTrue);

      // 通信が戻った次の前面復帰で捨て直し、警告も消える。
      fixture.messaging.deleteTokenError = null;
      fixture.resume.resume();
      await pumpEventQueue();

      expect(fixture.store.deletionPending, isFalse);
      expect(_status(container).failure, isNull);
    });

    test('OFF でサーバーの解除だけ失敗しても、端末のトークンを捨てられれば成功として扱う（もう届かない）', () async {
      final fixture = _Fixture();
      final container = await fixture.start();
      fixture.api.unregisterError = const NetworkException();

      await _controller(container).setEnabled(false);

      expect(fixture.messaging.deleteTokenCalls, 1);
      expect(fixture.store.deletionPending, isFalse);
      expect(_status(container).failure, isNull);
    });

    test('OFF で端末のトークンの破棄だけ失敗しても、サーバーの登録を消せれば成功として扱う', () async {
      final fixture = _Fixture();
      final container = await fixture.start();
      fixture.messaging.deleteTokenError = const NetworkException();

      await _controller(container).setEnabled(false);

      expect(fixture.api.unregistered, ['fcm-token-1']);
      // 端末のトークンは次の機会に捨て直す（予約は残る）。
      expect(fixture.store.deletionPending, isTrue);
      expect(_status(container).failure, isNull);
    });
  });

  group('使えないビルド', () {
    test('Firebase の設定が無ければ使えないと出し、トークンにも触らない', () async {
      final fixture = _Fixture(available: false);

      final container = await fixture.start();

      expect(_status(container).availability, PushAvailability.unavailable);
      expect(fixture.messaging.getTokenCalls, 0);
      expect(fixture.messaging.requestPermissionCalls, 0);
      expect(fixture.api.registered, isEmpty);
    });

    test('使えなくてもログアウトは普段どおり終わる（解除の通信をしない）', () async {
      final fixture = _Fixture(available: false);
      final container = await fixture.start();

      await container.read(authControllerProvider.notifier).logout();
      await pumpEventQueue();

      expect(
        container.read(authControllerProvider),
        const AuthState.unauthenticated(reason: SessionEndReason.signedOut),
      );
      expect(fixture.api.unregistered, isEmpty);
      expect(fixture.messaging.deleteTokenCalls, 0);
    });
  });

  group('セッションの終わり', () {
    test('ログアウトはサーバーの登録を消してから認証トークンを失効・削除する（DELETE に Bearer が要る）', () async {
      final fixture = _Fixture();
      final container = await fixture.start();
      fixture.log.clear();

      await container.read(authControllerProvider.notifier).logout();
      await pumpEventQueue();

      final log = fixture.log;
      expect(log.first, 'unregister fcm-token-1');
      expect(
        log.indexOf('unregister fcm-token-1'),
        lessThan(log.indexOf('revoke auth')),
      );
      expect(log.indexOf('revoke auth'), lessThan(log.indexOf('clear token')));
      // 端末のトークンも捨てる（DELETE が通らなかったときも届かなくなるように）。
      expect(fixture.messaging.deleteTokenCalls, greaterThanOrEqualTo(1));
      expect(fixture.store.registration, isNull);
      expect(fixture.store.deletionPending, isFalse);
    });

    test('解除の DELETE が失敗してもログアウトは終わり、端末のトークンは捨てる', () async {
      final fixture = _Fixture();
      final container = await fixture.start();
      fixture.api.unregisterError = const NetworkException();

      await container.read(authControllerProvider.notifier).logout();
      await pumpEventQueue();

      expect(
        container.read(authControllerProvider),
        const AuthState.unauthenticated(reason: SessionEndReason.signedOut),
      );
      expect(fixture.messaging.deleteTokenCalls, greaterThanOrEqualTo(1));
      expect(fixture.store.registration, isNull);
    });

    test('失効（401）ではサーバーに DELETE せず、端末のトークンだけ捨てる', () async {
      final fixture = _Fixture();
      final container = await fixture.start();

      await container
          .read(authControllerProvider.notifier)
          .handleSessionExpired();
      await pumpEventQueue();

      expect(fixture.api.unregistered, isEmpty);
      expect(fixture.messaging.deleteTokenCalls, 1);
      expect(fixture.store.registration, isNull);
      expect(_status(container).registered, isFalse);
    });

    test('圏外でトークンを捨てられなければ予約を残し、次の起動で捨て直してから登録する', () async {
      final fixture = _Fixture();
      final container = await fixture.start();
      fixture.messaging.deleteTokenError = const NetworkException();
      await container
          .read(authControllerProvider.notifier)
          .handleSessionExpired();
      await pumpEventQueue();
      expect(fixture.store.deletionPending, isTrue);

      // 次の起動（同じ端末の DB）。今度は通信できる。
      final next = _Fixture(store: fixture.store);
      await next.start();

      expect(next.messaging.deleteTokenCalls, 1);
      expect(next.store.deletionPending, isFalse);
      expect(
        next.log.indexOf('delete fcm token'),
        lessThan(next.log.indexOf('register fcm-token-2')),
      );
    });

    test('時間切れで待つのをやめた解除が遅れて戻っても、次のセッションで登録したトークンを消さない', () {
      fakeAsync((async) {
        final fixture = _Fixture()..allowLogin();
        final container = fixture.build();
        container
          ..read(pushNotificationsProvider)
          ..read(authControllerProvider);
        async.elapse(const Duration(milliseconds: 10));
        expect(fixture.registeredTokens, ['fcm-token-1']);

        // 遅い回線: DELETE が待つ上限を超えても返ってこない。
        final slowDelete = fixture.api.unregisterGate = Completer<void>();
        var loggedOut = false;
        unawaited(
          container
              .read(authControllerProvider.notifier)
              .logout()
              .then((_) => loggedOut = true),
        );
        async.elapse(
          PushNotifications.signOutTimeout + const Duration(seconds: 1),
        );
        expect(loggedOut, isTrue);

        // すぐにログインし直し、新しいトークンを登録した。
        fixture.api.unregisterGate = null;
        unawaited(
          container
              .read(authControllerProvider.notifier)
              .login(email: 'a@example.com', password: 'secret'),
        );
        async.elapse(const Duration(milliseconds: 10));
        expect(fixture.registeredTokens, ['fcm-token-1', 'fcm-token-2']);
        final deletes = fixture.messaging.deleteTokenCalls;

        // 前のログアウトの DELETE がやっと返った。
        slowDelete.complete();
        async.elapse(const Duration(milliseconds: 10));

        expect(fixture.store.registration?.token, 'fcm-token-2');
        expect(fixture.messaging.deleteTokenCalls, deletes);
        expect(fixture.store.deletionPending, isFalse);
        expect(_status(container).registered, isTrue);
      });
    });

    test('登録の POST の応答待ちでログアウトしたら、そのトークンも Bearer があるうちに消す', () async {
      final fixture = _Fixture();
      final slowRegister = fixture.api.registerGate = Completer<void>();
      final container = await fixture.start();
      // 送り出したが応答がまだなので控えに無い（それでもサーバーには届く）。
      expect(fixture.log, contains('register fcm-token-1'));
      expect(fixture.store.registration, isNull);
      fixture.log.clear();

      final logout = container.read(authControllerProvider.notifier).logout();
      await pumpEventQueue();
      // DELETE が POST より先にサーバーへ着くと消えずに残るので、応答を待つ。
      expect(fixture.log, isNot(contains('unregister fcm-token-1')));

      slowRegister.complete();
      await logout;
      await pumpEventQueue();

      final log = fixture.log;
      expect(log, contains('unregister fcm-token-1'));
      expect(
        log.indexOf('unregister fcm-token-1'),
        lessThan(log.indexOf('revoke auth')),
      );
      expect(log.indexOf('revoke auth'), lessThan(log.indexOf('clear token')));
      // 結果は前のセッションのものなので控えに残さない。
      expect(fixture.store.registration, isNull);
    });

    test('捨てられないまま登録できたら予約を下ろす（サーバーが持ち主をこのユーザーへ移したため）', () async {
      final fixture = _Fixture(
        store: InMemoryPushSettingsStore(deletionPending: true),
      );
      fixture.messaging.deleteTokenError = const NetworkException();

      await fixture.start();

      expect(fixture.registeredTokens, ['fcm-token-1']);
      expect(fixture.store.deletionPending, isFalse);
    });
  });

  group('届いた通知', () {
    test('前面にいる間に届いた通知を表示する（FCM は前面では OS に出させない）', () async {
      final fixture = _Fixture();
      await fixture.start();

      fixture.messaging.receive(const PushMessage(title: '新刊', body: '本文'));
      await pumpEventQueue();

      expect(fixture.notifier.shown.single.title, '新刊');
    });

    test('OFF のとき / data だけのとき / ログアウト後は表示しない', () async {
      final fixture = _Fixture();
      final container = await fixture.start();

      fixture.messaging.receive(const PushMessage(data: {'book_id': '1'}));
      await pumpEventQueue();
      await _controller(container).setEnabled(false);
      fixture.messaging.receive(const PushMessage(title: 'OFF 中'));
      await pumpEventQueue();
      await _controller(container).setEnabled(true);
      await container.read(authControllerProvider.notifier).logout();
      fixture.messaging.receive(const PushMessage(title: '前のユーザー宛て'));
      await pumpEventQueue();

      expect(fixture.notifier.shown, isEmpty);
    });

    test('背面の通知を押したら、data が無ければライブラリ、book_id があれば詳細を開く', () async {
      final fixture = _Fixture();
      await fixture.start();

      fixture.messaging.openFromBackground(const PushMessage(title: '新刊'));
      fixture.messaging.openFromBackground(
        const PushMessage(data: {'book_id': '12'}),
      );
      await pumpEventQueue();

      expect(fixture.opened, [AppRoutes.library, AppRoutes.bookDetail(12)]);
    });

    test('終了中に通知を押して起動したら、その通知の遷移先を開く', () async {
      final fixture = _Fixture();
      fixture.messaging.initialMessage = const PushMessage(
        data: {'book_ids': '7'},
      );

      await fixture.start();

      expect(fixture.opened, [AppRoutes.bookDetail(7)]);
    });

    test('前面で出した通知を押したら遷移する（起動中 / 終了後に押して起動）', () async {
      final fixture = _Fixture();
      fixture.notifier.launchData = {'book_id': '3'};
      await fixture.start();

      fixture.notifier.tap(const {});

      expect(fixture.opened, [AppRoutes.bookDetail(3), AppRoutes.library]);
    });

    test('起動時の通知が無ければどこへも遷移しない', () async {
      final fixture = _Fixture();

      await fixture.start();

      expect(fixture.opened, isEmpty);
    });
  });

  group('PushRegistrationPurger', () {
    test('セーフモードの変更（取り直せるものだけの破棄）では走らない（通知が止まるだけのため）', () {
      final purger = PushRegistrationPurger(
        PushTokenEraser(FakePushMessaging(), InMemoryPushSettingsStore()),
      );

      expect(purgersInScope([purger], SessionPurgeScope.refetchable), isEmpty);
    });
  });
}
