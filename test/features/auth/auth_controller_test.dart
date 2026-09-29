import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/domain/models/user.dart';
import 'package:comic_laz/features/auth/application/auth_controller.dart';
import 'package:comic_laz/features/auth/data/auth_api.dart';
import 'package:comic_laz/features/auth/domain/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/auth_fakes.dart';
import '../../support/test_scope.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(const User(id: 0));
  });

  group('起動時の復元', () {
    test('トークンが無ければ未ログイン', () async {
      final container = createContainer(
        authStore: FakeAuthStore(),
        authApi: MockAuthApi(),
      );
      addTearDown(container.dispose);

      expect(container.read(authControllerProvider), isA<AuthRestoring>());
      await settleAuth(container);

      expect(
        container.read(authControllerProvider),
        const AuthState.unauthenticated(),
      );
    });

    test('トークンが有効ならユーザーを取得してログイン済みになる', () async {
      final api = MockAuthApi();
      when(api.fetchCurrentUser).thenAnswer((_) async => testUser);
      final store = FakeAuthStore(token: 'valid');
      final container = createContainer(authStore: store, authApi: api);
      addTearDown(container.dispose);

      await settleAuth(container);

      expect(
        container.read(authControllerProvider),
        AuthState.authenticated(testUser),
      );
      // 次回のオフライン起動用にユーザーを保存する
      expect(store.user, testUser);
    });

    test('401 ならトークンを破棄し端末内データも消す', () async {
      final api = MockAuthApi();
      when(api.fetchCurrentUser).thenThrow(const UnauthorizedException());
      final store = FakeAuthStore(token: 'expired', user: testUser);
      final purger = RecordingPurger();
      final container = createContainer(
        authStore: store,
        authApi: api,
        purgers: [purger],
      );
      addTearDown(container.dispose);

      await settleAuth(container);

      expect(
        container.read(authControllerProvider),
        const AuthState.unauthenticated(reason: SessionEndReason.expired),
      );
      expect(store.token, isNull);
      expect(store.clearCount, 1);
      expect(purger.calls, 1);
    });

    test('圏外ならトークンを保持し、保存済みユーザーで続行する', () async {
      final api = MockAuthApi();
      when(api.fetchCurrentUser).thenThrow(const NetworkException());
      final store = FakeAuthStore(token: 'valid', user: testUser);
      final purger = RecordingPurger();
      final container = createContainer(
        authStore: store,
        authApi: api,
        purgers: [purger],
      );
      addTearDown(container.dispose);

      await settleAuth(container);

      expect(
        container.read(authControllerProvider),
        AuthState.authenticated(testUser),
      );
      expect(store.token, 'valid', reason: '通信エラーでトークンを捨ててはいけない');
      expect(purger.calls, 0);
    });

    test('圏外で保存済みユーザーも無ければ未ログイン（トークンは残す）', () async {
      final api = MockAuthApi();
      when(api.fetchCurrentUser).thenThrow(const ApiTimeoutException());
      final store = FakeAuthStore(token: 'valid');
      final container = createContainer(authStore: store, authApi: api);
      addTearDown(container.dispose);

      await settleAuth(container);

      expect(
        container.read(authControllerProvider),
        const AuthState.unauthenticated(),
      );
      expect(store.token, 'valid');
    });
  });

  // セーフモードはサーバー側が正（`is_unsafe` の巻は配信されない）なので、
  // 端末に落ちているデータは「そのとき見られたもの」だけ。ただし別のユーザーや
  // 別の設定に変わった後は、一覧・詳細・サムネイルがキャッシュ経由で見えて
  // しまうので破棄する（#11）。
  group('ユーザー / セーフモードの変更', () {
    /// 前回は [previous]、今回サーバーが [next} を返した状況を作る。
    ///
    /// 取り直せるもの（一覧 / 画像キャッシュ）と、端末にしか無いもの
    /// （ダウンロード済みの巻 / 未送信の進捗）を別々に見られるようにしておく。
    Future<({RecordingPurger refetchable, RecordingPurger localOnly})>
    restoreWithPurgers(User previous, User next) async {
      final api = MockAuthApi()..stubCurrentUser(next);
      final refetchable = RecordingPurger(debugLabel: 'offline metadata');
      final localOnly = RecordingPurger(
        purgesRefetchableOnly: false,
        debugLabel: 'downloaded volumes',
      );
      final container = createContainer(
        authStore: FakeAuthStore(token: 'valid', user: previous),
        authApi: api,
        purgers: [refetchable, localOnly],
      );
      addTearDown(container.dispose);

      await settleAuth(container);
      expect(
        container.read(authControllerProvider),
        AuthState.authenticated(next),
      );
      return (refetchable: refetchable, localOnly: localOnly);
    }

    Future<RecordingPurger> restoreWith(User previous, User next) async =>
        (await restoreWithPurgers(previous, next)).refetchable;

    test('別のユーザーに変わったら端末内データを全部破棄する', () async {
      final purgers = await restoreWithPurgers(
        testUser,
        const User(id: 2, name: '別の人'),
      );

      expect(purgers.refetchable.calls, 1);
      expect(purgers.localOnly.calls, 1, reason: '前のユーザーのコミックと読書位置を端末に残さない');
    });

    // #11 のレビュー指摘: 同じユーザーなのにダウンロード済みの巻（数 GB）と
    // 未送信の進捗まで消していた。未送信の進捗はサーバーにも無いので、消したら
    // 永久に失われる。セーフモードで隠したいのは前の設定で取った一覧・詳細・画像。
    test('セーフモード設定だけが変わったら取り直せるものしか破棄しない', () async {
      final purgers = await restoreWithPurgers(
        testUser,
        testUser.copyWith(safeMode: true),
      );

      expect(purgers.refetchable.calls, 1, reason: '前の設定で取った一覧がオフラインで見えてしまう');
      expect(
        purgers.localOnly.calls,
        0,
        reason: 'ダウンロード済みの巻と未送信の進捗は同じユーザーのものなので残す',
      );
    });

    test('同じユーザー・同じ設定なら破棄しない', () async {
      final purger = await restoreWith(testUser, testUser);

      expect(purger.calls, 0);
    });

    test('ログイン時にユーザーが変わっていても破棄する', () async {
      final api = MockAuthApi();
      when(
        () => api.createToken(
          email: any(named: 'email'),
          password: any(named: 'password'),
          deviceName: any(named: 'deviceName'),
        ),
      ).thenAnswer(
        (_) async => const AuthTokenResult(
          token: 'new-token',
          user: User(id: 2, name: '別の人'),
        ),
      );
      final purger = RecordingPurger();
      final container = createContainer(
        // ログアウトを経ずに別のユーザーでログインした（トークンだけ消えた状態）。
        authStore: FakeAuthStore(user: testUser),
        authApi: api,
        purgers: [purger],
      );
      addTearDown(container.dispose);
      await settleAuth(container);

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'b@example.com', password: 'secret');

      expect(purger.calls, 1);
    });
  });

  group('login', () {
    test('トークンとユーザーを保存してログイン済みになる', () async {
      final api = MockAuthApi();
      when(
        () => api.createToken(
          email: any(named: 'email'),
          password: any(named: 'password'),
          deviceName: any(named: 'deviceName'),
        ),
      ).thenAnswer(
        (_) async => const AuthTokenResult(token: 'new-token', user: testUser),
      );
      final store = FakeAuthStore();
      final device = FakeDeviceNameResolver('Pixel 8');
      final container = createContainer(
        authStore: store,
        authApi: api,
        deviceNameResolver: device,
      );
      addTearDown(container.dispose);
      await settleAuth(container);

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'a@example.com', password: 'secret');

      expect(
        container.read(authControllerProvider),
        AuthState.authenticated(testUser),
      );
      expect(store.token, 'new-token');
      expect(store.user, testUser);
      verify(
        () => api.createToken(
          email: 'a@example.com',
          password: 'secret',
          deviceName: 'Pixel 8',
        ),
      ).called(1);
      verifyNever(api.fetchCurrentUser);
    });

    test('ユーザーを返さないサーバーでは /api/user で補う', () async {
      final api = MockAuthApi();
      when(
        () => api.createToken(
          email: any(named: 'email'),
          password: any(named: 'password'),
          deviceName: any(named: 'deviceName'),
        ),
      ).thenAnswer((_) async => const AuthTokenResult(token: 'new-token'));
      when(api.fetchCurrentUser).thenAnswer((_) async => testUser);
      final container = createContainer(
        authStore: FakeAuthStore(),
        authApi: api,
      );
      addTearDown(container.dispose);
      await settleAuth(container);

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'a@example.com', password: 'secret');

      expect(
        container.read(authControllerProvider),
        AuthState.authenticated(testUser),
      );
    });

    test('失敗したら例外を投げ、未ログインのまま', () async {
      final api = MockAuthApi();
      when(
        () => api.createToken(
          email: any(named: 'email'),
          password: any(named: 'password'),
          deviceName: any(named: 'deviceName'),
        ),
      ).thenThrow(const InvalidCredentialsException());
      final store = FakeAuthStore();
      final container = createContainer(authStore: store, authApi: api);
      addTearDown(container.dispose);
      await settleAuth(container);

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .login(email: 'a@example.com', password: 'wrong'),
        throwsA(isA<InvalidCredentialsException>()),
      );

      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
      expect(store.token, isNull);
    });
  });

  group('logout', () {
    test('サーバーに通知し、トークンと端末内データを消す', () async {
      final api = MockAuthApi();
      when(api.fetchCurrentUser).thenAnswer((_) async => testUser);
      when(api.deleteToken).thenAnswer((_) async {});
      final store = FakeAuthStore(token: 'valid', user: testUser);
      final purger = RecordingPurger();
      final container = createContainer(
        authStore: store,
        authApi: api,
        purgers: [purger],
      );
      addTearDown(container.dispose);
      await settleAuth(container);

      await container.read(authControllerProvider.notifier).logout();

      expect(
        container.read(authControllerProvider),
        const AuthState.unauthenticated(reason: SessionEndReason.signedOut),
      );
      expect(store.token, isNull);
      expect(store.user, isNull);
      expect(purger.calls, 1);
      verify(api.deleteToken).called(1);
    });

    test('圏外でもログアウトは完了する', () async {
      final api = MockAuthApi();
      when(api.fetchCurrentUser).thenAnswer((_) async => testUser);
      when(api.deleteToken).thenThrow(const NetworkException());
      final store = FakeAuthStore(token: 'valid', user: testUser);
      final purger = RecordingPurger();
      final container = createContainer(
        authStore: store,
        authApi: api,
        purgers: [purger],
      );
      addTearDown(container.dispose);
      await settleAuth(container);

      await container.read(authControllerProvider.notifier).logout();

      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
      expect(store.token, isNull);
      expect(purger.calls, 1);
    });

    test('破棄処理が失敗しても他の破棄とログアウトは続行する', () async {
      final api = MockAuthApi();
      when(api.fetchCurrentUser).thenAnswer((_) async => testUser);
      when(api.deleteToken).thenAnswer((_) async {});
      final failing = RecordingPurger(throwOnPurge: true);
      final succeeding = RecordingPurger();
      final container = createContainer(
        authStore: FakeAuthStore(token: 'valid', user: testUser),
        authApi: api,
        purgers: [failing, succeeding],
      );
      addTearDown(container.dispose);
      await settleAuth(container);

      await container.read(authControllerProvider.notifier).logout();

      expect(failing.calls, 1);
      expect(succeeding.calls, 1);
      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
    });
  });

  group('handleSessionExpired', () {
    test('並行した 401 でも破棄は 1 回だけ', () async {
      final api = MockAuthApi();
      when(api.fetchCurrentUser).thenAnswer((_) async => testUser);
      final store = FakeAuthStore(token: 'valid', user: testUser);
      final purger = RecordingPurger();
      final container = createContainer(
        authStore: store,
        authApi: api,
        purgers: [purger],
      );
      addTearDown(container.dispose);
      await settleAuth(container);

      final notifier = container.read(authControllerProvider.notifier);
      await Future.wait([
        notifier.handleSessionExpired(),
        notifier.handleSessionExpired(),
        notifier.handleSessionExpired(),
      ]);

      expect(purger.calls, 1);
      expect(store.clearCount, 1);
      expect(
        container.read(authControllerProvider),
        const AuthState.unauthenticated(reason: SessionEndReason.expired),
      );
    });

    test('未ログインなら何もしない', () async {
      final store = FakeAuthStore();
      final purger = RecordingPurger();
      final container = createContainer(
        authStore: store,
        authApi: MockAuthApi(),
        purgers: [purger],
      );
      addTearDown(container.dispose);
      await settleAuth(container);

      await container
          .read(authControllerProvider.notifier)
          .handleSessionExpired();

      expect(purger.calls, 0);
      expect(store.clearCount, 0);
    });

    test('未ログインだがトークンが残っている（圏外起動）なら破棄する', () async {
      final api = MockAuthApi();
      // 圏外起動: トークンは残るが保存済みユーザーが無いので未ログイン表示になる
      when(api.fetchCurrentUser).thenThrow(const NetworkException());
      final store = FakeAuthStore(token: 'valid');
      final purger = RecordingPurger();
      final container = createContainer(
        authStore: store,
        authApi: api,
        purgers: [purger],
      );
      addTearDown(container.dispose);
      expect(await settleAuth(container), const AuthState.unauthenticated());
      expect(store.token, 'valid');

      await container
          .read(authControllerProvider.notifier)
          .handleSessionExpired();

      expect(store.token, isNull, reason: '残ったトークンは破棄されるべき');
      expect(purger.calls, 1, reason: '端末内データも破棄されるべき');
    });
  });

  group('ストレージ障害', () {
    test('トークンを読めなくてもスプラッシュで固まらない', () async {
      final container = createContainer(
        authStore: ThrowingAuthStore(),
        authApi: MockAuthApi(),
      );
      addTearDown(container.dispose);

      expect(await settleAuth(container), const AuthState.unauthenticated());
    });

    test('削除に失敗してもログアウトは完了する', () async {
      final api = MockAuthApi();
      when(api.deleteToken).thenAnswer((_) async {});
      final store = ThrowingAuthStore(failOnRead: false, failOnClear: true);
      final purger = RecordingPurger();
      final container = createContainer(
        authStore: store,
        authApi: api,
        purgers: [purger],
      );
      addTearDown(container.dispose);
      await settleAuth(container);

      await container.read(authControllerProvider.notifier).logout();

      expect(store.clearCount, 1);
      expect(purger.calls, 1);
      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
    });
  });

  group('ログアウトと失効の競合', () {
    test('ログアウト中に 401 を受けても理由はログアウトになる', () async {
      final api = MockAuthApi();
      when(api.fetchCurrentUser).thenAnswer((_) async => testUser);
      late final ProviderContainer container;
      // サーバー側で既に失効していて DELETE が 401 を返すケース。
      // インターセプタ相当の失効処理が先に走る。
      when(api.deleteToken).thenAnswer((_) async {
        await container
            .read(authControllerProvider.notifier)
            .handleSessionExpired();
        throw const UnauthorizedException();
      });
      final store = FakeAuthStore(token: 'valid', user: testUser);
      final purger = RecordingPurger();
      container = createContainer(
        authStore: store,
        authApi: api,
        purgers: [purger],
      );
      addTearDown(container.dispose);
      await settleAuth(container);

      await container.read(authControllerProvider.notifier).logout();

      expect(
        container.read(authControllerProvider),
        const AuthState.unauthenticated(reason: SessionEndReason.signedOut),
        reason: '自分でログアウトしたのに「期限切れ」と表示してはいけない',
      );
      expect(store.token, isNull);
      expect(purger.calls, 1, reason: '破棄は 1 回に集約されるべき');
    });
  });
}
