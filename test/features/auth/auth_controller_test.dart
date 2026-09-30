import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/session/session_data_purger.dart';
import 'package:comic_laz/domain/models/user.dart';
import 'package:comic_laz/features/auth/application/auth_controller.dart';
import 'package:comic_laz/features/auth/data/auth_api.dart';
import 'package:comic_laz/features/auth/data/auth_store.dart';
import 'package:comic_laz/features/auth/domain/auth_state.dart';
import 'package:comic_laz/features/auth/domain/session_cleanup_exception.dart';
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

  group('破棄のやり直し（#15）', () {
    /// ログイン済みの状態を作る（ログアウトの破棄を試すため）。
    Future<ProviderContainer> signedIn({
      required FakeSessionPurgeJournal journal,
      required List<RecordingPurger> purgers,
      FakeAuthStore? store,
    }) async {
      final api = MockAuthApi()..stubCurrentUser();
      when(api.deleteToken).thenAnswer((_) async {});
      final container = createContainer(
        authStore: store ?? FakeAuthStore(token: 'valid', user: testUser),
        authApi: api,
        purgers: purgers,
        sessionPurgeJournal: journal,
      );
      addTearDown(container.dispose);
      await settleAuth(container);
      return container;
    }

    test('ログアウトの破棄が 1 つ失敗したら印を残し、次の起動でやり直す（前のユーザーのデータを端末に残さないため）', () async {
      final journal = FakeSessionPurgeJournal();
      final failing = RecordingPurger(throwOnPurge: true);
      final container = await signedIn(journal: journal, purgers: [failing]);

      await container.read(authControllerProvider.notifier).logout();
      expect(journal.pending, SessionPurgeScope.session);

      // 次の起動: トークンも前のユーザーも無いが、印があるので破棄をやり直す。
      final retry = RecordingPurger();
      final next = createContainer(
        authStore: FakeAuthStore(),
        authApi: MockAuthApi(),
        purgers: [retry],
        sessionPurgeJournal: journal,
      );
      addTearDown(next.dispose);
      expect(await settleAuth(next), const AuthState.unauthenticated());

      expect(retry.calls, 1);
      expect(journal.pending, isNull, reason: '成功したら起動のたびに消し直さない');
    });

    test('破棄の途中でアプリが落ちても（印だけ残った状態）、次の起動で破棄をやり直す', () async {
      final journal = FakeSessionPurgeJournal(
        pending: SessionPurgeScope.session,
      );
      final purger = RecordingPurger(purgesRefetchableOnly: false);
      final container = createContainer(
        authStore: FakeAuthStore(),
        authApi: MockAuthApi(),
        purgers: [purger],
        sessionPurgeJournal: journal,
      );
      addTearDown(container.dispose);

      await settleAuth(container);

      expect(purger.calls, 1);
      expect(journal.pending, isNull);
    });

    test('破棄がすべて成功したら印を消す（起動のたびに消し直さないため）', () async {
      final journal = FakeSessionPurgeJournal();
      final container = await signedIn(
        journal: journal,
        purgers: [RecordingPurger()],
      );

      await container.read(authControllerProvider.notifier).logout();

      expect(journal.pending, isNull);
      expect(journal.log, ['mark session', 'complete session']);
    });

    test('破棄の印はトークンより先に書く（トークンだけ消えて印が無い状態を作らないため）', () async {
      final log = <String>[];
      final journal = FakeSessionPurgeJournal(log: log);
      final container = await signedIn(
        journal: journal,
        purgers: [RecordingPurger()],
        store: FakeAuthStore(token: 'valid', user: testUser, log: log),
      );

      await container.read(authControllerProvider.notifier).logout();

      expect(log.indexOf('mark session'), lessThan(log.indexOf('clear token')));
    });

    test('印を書けなくてもログアウトは完了する', () async {
      final journal = FakeSessionPurgeJournal()..error = StateError('db');
      final purger = RecordingPurger();
      final container = await signedIn(journal: journal, purgers: [purger]);

      await container.read(authControllerProvider.notifier).logout();

      expect(purger.calls, 1);
      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
    });

    test('やり直しの破棄ではトークンを消さない（印はデータを消す意味しか持たないため）', () async {
      final journal = FakeSessionPurgeJournal(
        pending: SessionPurgeScope.session,
      );
      final store = FakeAuthStore(token: 'valid', user: testUser);
      final purger = RecordingPurger();
      final container = createContainer(
        authStore: store,
        authApi: MockAuthApi()..stubCurrentUser(),
        purgers: [purger],
        sessionPurgeJournal: journal,
      );
      addTearDown(container.dispose);

      expect(await settleAuth(container), AuthState.authenticated(testUser));
      expect(purger.calls, 1);
      expect(store.token, 'valid');
      expect(store.clearCount, 0);
    });

    test(
      '起動時のユーザー切り替えの破棄が失敗したら、印を残してログイン済みにしない（前のユーザーのデータの上でセッションを始めないため）',
      () async {
        final journal = FakeSessionPurgeJournal();
        final failing = RecordingPurger(
          throwOnPurge: true,
          purgesRefetchableOnly: false,
        );
        final store = FakeAuthStore(token: 'valid', user: testUser);
        final container = createContainer(
          authStore: store,
          authApi: MockAuthApi()..stubCurrentUser(const User(id: 2, name: '別')),
          purgers: [failing],
          sessionPurgeJournal: journal,
        );
        addTearDown(container.dispose);

        expect(await settleAuth(container), const AuthState.unauthenticated());

        expect(failing.calls, 1);
        expect(journal.pending, SessionPurgeScope.session);
        expect(store.user, testUser, reason: '保存すると次の起動で切り替えに気づけない');
      },
    );

    // 残したままだと、次の起動のやり直しが新しいセッションのダウンロードまで消す。
    test('ログイン時に印が残っていれば、新しいセッションを始める前に破棄する', () async {
      final journal = FakeSessionPurgeJournal();
      final api = MockAuthApi();
      when(
        () => api.createToken(
          email: any(named: 'email'),
          password: any(named: 'password'),
          deviceName: any(named: 'deviceName'),
        ),
      ).thenAnswer(
        (_) async => const AuthTokenResult(token: 'new', user: testUser),
      );
      final purger = RecordingPurger();
      final container = createContainer(
        authStore: FakeAuthStore(),
        authApi: api,
        purgers: [purger],
        sessionPurgeJournal: journal,
      );
      addTearDown(container.dispose);
      await settleAuth(container);
      // 起動後に印が残った（起動時のやり直しも失敗した）状態。
      journal.pending = SessionPurgeScope.session;

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'a@example.com', password: 'secret');

      expect(purger.calls, 1);
      expect(journal.pending, isNull);
    });
  });

  group('セーフモードの再検証の予約（#15）', () {
    Future<InMemorySafeModeRevalidationStore> restore(
      User previous,
      User next, {
      InMemorySafeModeRevalidationStore? store,
      FakeAuthStore? authStore,
    }) async {
      final revalidation = store ?? InMemorySafeModeRevalidationStore();
      final container = createContainer(
        authStore: authStore ?? FakeAuthStore(token: 'valid', user: previous),
        authApi: MockAuthApi()..stubCurrentUser(next),
        purgers: [RecordingPurger()],
        safeModeRevalidationStore: revalidation,
      );
      addTearDown(container.dispose);
      await settleAuth(container);
      return revalidation;
    }

    test('セーフモードが ON になったら、ダウンロード済みの巻の再検証を予約する', () async {
      final store = await restore(testUser, testUser.copyWith(safeMode: true));

      expect(store.pending, isTrue);
    });

    test('セーフモードが OFF になっただけでは再検証を予約しない（隠すものが増えないため）', () async {
      final store = await restore(testUser.copyWith(safeMode: true), testUser);

      expect(store.scheduleCalls, 0);
    });

    test('予約を書けなければユーザーを保存しない（次の起動で同じ差分から予約し直すため）', () async {
      final authStore = FakeAuthStore(token: 'valid', user: testUser);
      await restore(
        testUser,
        testUser.copyWith(safeMode: true),
        store: InMemorySafeModeRevalidationStore()
          ..scheduleError = StateError('db'),
        authStore: authStore,
      );

      expect(authStore.user, testUser, reason: '保存すると OFF → ON の差分が消える');
    });
  });

  group('前のユーザーを読めないとき（#15）', () {
    test(
      'ログイン時に前のユーザーを読めなければ、別のユーザーとみなして全部破棄する（持ち主を確かめられないデータを残さないため）',
      () async {
        final api = MockAuthApi();
        when(
          () => api.createToken(
            email: any(named: 'email'),
            password: any(named: 'password'),
            deviceName: any(named: 'deviceName'),
          ),
        ).thenAnswer(
          (_) async => const AuthTokenResult(token: 'new', user: testUser),
        );
        final store = FakeAuthStore();
        final localOnly = RecordingPurger(purgesRefetchableOnly: false);
        final container = createContainer(
          authStore: store,
          authApi: api,
          purgers: [localOnly],
        );
        addTearDown(container.dispose);
        await settleAuth(container);
        store.readUserError = const FakePlatformException('BAD_DECRYPT');

        await container
            .read(authControllerProvider.notifier)
            .login(email: 'a@example.com', password: 'secret');

        expect(localOnly.calls, 1);
        expect(
          container.read(authControllerProvider),
          AuthState.authenticated(testUser),
          reason: 'ログイン自体は失敗させない',
        );
      },
    );

    test(
      '起動時の復元で前のユーザーを読めなくても破棄しない（ロック解除前のバックグラウンド起動で同じユーザーのデータを消さないため）',
      () async {
        final store = FakeAuthStore(token: 'valid', user: testUser)
          ..readUserError = const FakePlatformException('locked');
        final localOnly = RecordingPurger(purgesRefetchableOnly: false);
        final container = createContainer(
          authStore: store,
          authApi: MockAuthApi()..stubCurrentUser(),
          purgers: [localOnly],
        );
        addTearDown(container.dispose);

        await settleAuth(container);

        expect(localOnly.calls, 0);
        expect(store.token, 'valid');
      },
    );

    test('ログイン時に保存済みユーザーを読み解けなければ（アプリの更新で形式が変わった）、持ち主不明として全部破棄する（前のユーザーの巻と未送信の進捗を次のユーザーに渡さないため）', () async {
      final store = FakeAuthStore(token: 'old')
        ..readUserError = const StoredUserUnreadableException('schema');
      final localOnly = RecordingPurger(purgesRefetchableOnly: false);
      final container = createContainer(
        authStore: store,
        authApi: _loginApi(
          const AuthTokenResult(
            token: 'new',
            user: User(id: 2, name: '別の人'),
          ),
        )..stubCurrentUser(),
        purgers: [localOnly],
      );
      addTearDown(container.dispose);
      await settleAuth(container);
      localOnly.calls = 0;

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'b@example.com', password: 'secret');

      expect(localOnly.calls, 1);
      expect(
        container.read(authControllerProvider),
        const AuthState.authenticated(User(id: 2, name: '別の人')),
      );
    });

    test('起動時に保存済みユーザーを読み解けなくても、トークンが通れば破棄せずに新しい形式で保存し直す（トークンの持ち主と端末のデータの持ち主は同じため）', () async {
      final store = FakeAuthStore(token: 'valid')
        ..readUserError = const StoredUserUnreadableException('schema');
      final localOnly = RecordingPurger(purgesRefetchableOnly: false);
      final container = createContainer(
        authStore: store,
        authApi: MockAuthApi()..stubCurrentUser(),
        purgers: [localOnly],
      );
      addTearDown(container.dispose);

      expect(await settleAuth(container), AuthState.authenticated(testUser));

      expect(localOnly.calls, 0);
      expect(store.user, testUser);
    });

    test(
      '起動時に保存済みユーザーを読み解けず、セーフモードなら再検証を予約する（前の設定が分からないので OFF → ON を取りこぼさないため）',
      () async {
        final store = FakeAuthStore(token: 'valid')
          ..readUserError = const StoredUserUnreadableException('schema');
        final revalidation = InMemorySafeModeRevalidationStore();
        final container = createContainer(
          authStore: store,
          authApi: MockAuthApi()
            ..stubCurrentUser(testUser.copyWith(safeMode: true)),
          purgers: [RecordingPurger()],
          safeModeRevalidationStore: revalidation,
        );
        addTearDown(container.dispose);

        await settleAuth(container);

        expect(revalidation.pending, isTrue);
      },
    );

    test('圏外起動で保存済みユーザーを読み解けなければ、未ログインにしてトークンは残す', () async {
      final api = MockAuthApi();
      when(api.fetchCurrentUser).thenThrow(const NetworkException());
      final store = FakeAuthStore(token: 'valid')
        ..readUserError = const StoredUserUnreadableException('schema');
      final localOnly = RecordingPurger(purgesRefetchableOnly: false);
      final container = createContainer(
        authStore: store,
        authApi: api,
        purgers: [localOnly],
      );
      addTearDown(container.dispose);

      expect(await settleAuth(container), const AuthState.unauthenticated());

      expect(store.token, 'valid', reason: '通信エラーでトークンを捨てない');
      expect(localOnly.calls, 0);
    });

    test('ログイン時に前のトークンだけが残りユーザーが無ければ、持ち主不明として全部破棄する', () async {
      final localOnly = RecordingPurger(purgesRefetchableOnly: false);
      final api = MockAuthApi();
      when(api.fetchCurrentUser).thenThrow(const NetworkException());
      final store = FakeAuthStore(token: 'old');
      final container = createContainer(
        authStore: store,
        authApi: api,
        purgers: [localOnly],
      );
      addTearDown(container.dispose);
      await settleAuth(container);
      when(
        () => api.createToken(
          email: any(named: 'email'),
          password: any(named: 'password'),
          deviceName: any(named: 'deviceName'),
        ),
      ).thenAnswer(
        (_) async => const AuthTokenResult(token: 'new', user: testUser),
      );

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'a@example.com', password: 'secret');

      expect(localOnly.calls, 1);
      expect(store.token, 'new');
    });

    test('トークンもユーザーも無い初回ログインでは破棄しない（消すものが無いため）', () async {
      final localOnly = RecordingPurger(purgesRefetchableOnly: false);
      final container = createContainer(
        authStore: FakeAuthStore(),
        authApi: _loginApi(const AuthTokenResult(token: 'new', user: testUser)),
        purgers: [localOnly],
      );
      addTearDown(container.dispose);
      await settleAuth(container);

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'a@example.com', password: 'secret');

      expect(localOnly.calls, 0);
    });
  });

  // 片付けが済まないままログイン済みにすると、持ち主の無い未送信の進捗が
  // 新しいユーザーのトークンで一括同期され、サーバーの読書位置が取り消せない形で
  // 書き換わる。前のユーザーの巻も見えてしまう。
  group('前のセッションが片付くまでログインさせない（#15）', () {
    test('ログアウトの印のやり直しが失敗したらログインを止め、トークンを保存しない', () async {
      final journal = FakeSessionPurgeJournal(
        pending: SessionPurgeScope.session,
      );
      final failing = RecordingPurger(
        throwOnPurge: true,
        purgesRefetchableOnly: false,
      );
      final store = FakeAuthStore();
      final container = createContainer(
        authStore: store,
        authApi: _loginApi(const AuthTokenResult(token: 'new', user: testUser)),
        purgers: [failing],
        sessionPurgeJournal: journal,
      );
      addTearDown(container.dispose);
      await settleAuth(container);

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .login(email: 'a@example.com', password: 'secret'),
        throwsA(isA<SessionCleanupException>()),
      );

      expect(store.token, isNull);
      expect(store.user, isNull);
      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
      expect(journal.pending, SessionPurgeScope.session);

      // 破棄が通るようになれば、同じ操作でログインできる（再試行の導線）。
      failing.throwOnPurge = false;
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'a@example.com', password: 'secret');

      expect(
        container.read(authControllerProvider),
        AuthState.authenticated(testUser),
      );
      expect(store.token, 'new');
      expect(journal.pending, isNull);
    });

    test('破棄の印を読めなければログインを止める（片付いたか分からないまま始めないため）', () async {
      final journal = FakeSessionPurgeJournal();
      final store = FakeAuthStore();
      final container = createContainer(
        authStore: store,
        authApi: _loginApi(const AuthTokenResult(token: 'new', user: testUser)),
        sessionPurgeJournal: journal,
      );
      addTearDown(container.dispose);
      await settleAuth(container);
      journal.error = StateError('db');

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .login(email: 'a@example.com', password: 'secret'),
        throwsA(isA<SessionCleanupException>()),
      );

      expect(store.token, isNull);
    });

    test('ログイン時のユーザー切り替えの破棄が失敗したら、新しいトークンもユーザーも残さない', () async {
      final journal = FakeSessionPurgeJournal();
      final failing = RecordingPurger(
        throwOnPurge: true,
        purgesRefetchableOnly: false,
      );
      final store = FakeAuthStore(user: testUser);
      final container = createContainer(
        authStore: store,
        authApi: _loginApi(
          const AuthTokenResult(
            token: 'new',
            user: User(id: 2, name: '別の人'),
          ),
        ),
        purgers: [failing],
        sessionPurgeJournal: journal,
      );
      addTearDown(container.dispose);
      await settleAuth(container);

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .login(email: 'b@example.com', password: 'secret'),
        throwsA(isA<SessionCleanupException>()),
      );

      expect(store.token, isNull, reason: '残すと次の起動で前のユーザーのデータの上に復元する');
      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
      expect(journal.pending, SessionPurgeScope.session, reason: '次のログインで片付ける');
    });

    test(
      '起動時に印のやり直しが失敗したら、トークンがあってもログイン済みにしない（ログイン中のユーザーのデータを起動のたびに消さないため）',
      () async {
        final journal = FakeSessionPurgeJournal(
          pending: SessionPurgeScope.session,
        );
        final failing = RecordingPurger(
          throwOnPurge: true,
          purgesRefetchableOnly: false,
        );
        final store = FakeAuthStore(token: 'valid', user: testUser);
        final api = MockAuthApi()..stubCurrentUser();
        final container = createContainer(
          authStore: store,
          authApi: api,
          purgers: [failing],
          sessionPurgeJournal: journal,
        );
        addTearDown(container.dispose);

        expect(await settleAuth(container), const AuthState.unauthenticated());

        verifyNever(api.fetchCurrentUser);
        expect(store.token, 'valid', reason: '印はデータを消す意味しか持たない');
        expect(journal.pending, SessionPurgeScope.session);
      },
    );

    test('取り直せるものだけの印のやり直しが失敗しても、起動は止めない（同じユーザーのキャッシュなので）', () async {
      final journal = FakeSessionPurgeJournal(
        pending: SessionPurgeScope.refetchable,
      );
      final container = createContainer(
        authStore: FakeAuthStore(token: 'valid', user: testUser),
        authApi: MockAuthApi()..stubCurrentUser(),
        purgers: [RecordingPurger(throwOnPurge: true)],
        sessionPurgeJournal: journal,
      );
      addTearDown(container.dispose);

      expect(await settleAuth(container), AuthState.authenticated(testUser));
      expect(journal.pending, SessionPurgeScope.refetchable);
    });
  });

  // iOS の Keychain はアプリを削除しても残る。入れ直した端末が前の持ち主の
  // トークンで自動ログインしないよう、DB を新しく作ったときの目印で片付ける。
  group('入れ直し直後（#15）', () {
    test('目印があれば、保存済みのトークンを消して未ログインで始める', () async {
      final marker = FakeInstallMarker(fresh: true);
      final store = FakeAuthStore(token: 'previous-owner', user: testUser);
      final api = MockAuthApi()..stubCurrentUser();
      final container = createContainer(
        authStore: store,
        authApi: api,
        installMarker: marker,
      );
      addTearDown(container.dispose);

      expect(await settleAuth(container), const AuthState.unauthenticated());

      expect(store.token, isNull);
      expect(store.user, isNull);
      verifyNever(api.fetchCurrentUser);
      expect(marker.fresh, isFalse, reason: '次の起動からはログインを保つ');
    });

    test('目印が無ければ（アップデート）、保存済みのトークンで復元する', () async {
      final store = FakeAuthStore(token: 'valid', user: testUser);
      final container = createContainer(
        authStore: store,
        authApi: MockAuthApi()..stubCurrentUser(),
        installMarker: FakeInstallMarker(),
      );
      addTearDown(container.dispose);

      expect(await settleAuth(container), AuthState.authenticated(testUser));
      expect(store.clearCount, 0);
    });

    test('トークンを消せなければ目印を残し、未ログインで始める（前の持ち主で復元しないため）', () async {
      final marker = FakeInstallMarker(fresh: true);
      final store = ThrowingAuthStore(failOnClear: true, failOnRead: false);
      final api = MockAuthApi()..stubCurrentUser();
      final container = createContainer(
        authStore: store,
        authApi: api,
        installMarker: marker,
      );
      addTearDown(container.dispose);

      expect(await settleAuth(container), const AuthState.unauthenticated());

      expect(marker.fresh, isTrue, reason: '次の起動でやり直す');
      verifyNever(api.fetchCurrentUser);
    });

    test('ログイン時に目印を片付けられなければログインを止める（後の起動で新しいトークンを消さないため）', () async {
      final marker = FakeInstallMarker(fresh: true)..error = StateError('db');
      final store = FakeAuthStore();
      final container = createContainer(
        authStore: store,
        authApi: _loginApi(const AuthTokenResult(token: 'new', user: testUser)),
        installMarker: marker,
      );
      addTearDown(container.dispose);
      await settleAuth(container);

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .login(email: 'a@example.com', password: 'secret'),
        throwsA(isA<SessionCleanupException>()),
      );

      expect(store.token, isNull);
    });
  });
}

/// `createToken` が [result] を返す API。
MockAuthApi _loginApi(AuthTokenResult result) {
  final api = MockAuthApi();
  when(
    () => api.createToken(
      email: any(named: 'email'),
      password: any(named: 'password'),
      deviceName: any(named: 'deviceName'),
    ),
  ).thenAnswer((_) async => result);
  return api;
}
