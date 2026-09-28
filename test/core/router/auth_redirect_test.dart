import 'dart:async';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/router/app_router.dart';
import 'package:comic_laz/core/router/app_routes.dart';
import 'package:comic_laz/domain/models/user.dart';
import 'package:comic_laz/features/auth/application/auth_controller.dart';
import 'package:comic_laz/features/auth/data/auth_api.dart';
import 'package:comic_laz/features/auth/presentation/login_screen.dart';
import 'package:comic_laz/features/auth/presentation/splash_screen.dart';
import 'package:comic_laz/features/library/presentation/library_screen.dart';
import 'package:comic_laz/features/title/presentation/title_detail_screen.dart';
import 'package:comic_laz/features/viewer/presentation/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/auth_fakes.dart';
import '../../support/test_scope.dart';

/// 認証状態を差し替えたアプリを起動し、コンテナとルータを返す。
Future<({ProviderContainer container, GoRouter router})> pumpApp(
  WidgetTester tester, {
  required MockAuthApi api,
  FakeAuthStore? store,
  bool settle = true,
}) async {
  final container = createContainer(
    authStore: store ?? FakeAuthStore(),
    authApi: api,
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // スプラッシュのローディング表示は無限アニメーションなので settle できない。
    await tester.pump();
  }
  return (container: container, router: router);
}

void main() {
  late MockAuthApi api;

  setUp(() {
    api = MockAuthApi();
  });

  testWidgets('トークン検証中はスプラッシュを表示する', (tester) async {
    // 応答を保留させて「検証中」の状態を維持する
    final pending = Completer<User>();
    when(api.fetchCurrentUser).thenAnswer((_) => pending.future);
    final app = await pumpApp(
      tester,
      api: api,
      store: FakeAuthStore(token: 'valid'),
      settle: false,
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(app.router.state.matchedLocation, AppRoutes.splash);
  });

  testWidgets('未ログインならログイン画面に送る', (tester) async {
    final app = await pumpApp(tester, api: api);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(app.router.state.matchedLocation, AppRoutes.login);
  });

  testWidgets('ログイン済みならライブラリを表示する', (tester) async {
    when(api.fetchCurrentUser).thenAnswer((_) async => testUser);

    await pumpApp(
      tester,
      api: api,
      store: FakeAuthStore(token: 'valid'),
    );

    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  testWidgets('未ログインで深いリンクを開くと、ログイン後にその画面へ進む', (tester) async {
    when(
      () => api.createToken(
        email: any(named: 'email'),
        password: any(named: 'password'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenAnswer(
      (_) async => const AuthTokenResult(token: 'token', user: testUser),
    );
    final app = await pumpApp(tester, api: api);

    app.router.go(AppRoutes.viewer(34));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      app.router.state.uri.queryParameters[AppRoutes.fromQueryParam],
      AppRoutes.viewer(34),
    );

    await app.container
        .read(authControllerProvider.notifier)
        .login(email: 'a@example.com', password: 'secret');
    await tester.pumpAndSettle();

    expect(find.byType(ViewerScreen), findsOneWidget);
  });

  testWidgets('ログイン後に戻る先が無ければライブラリへ', (tester) async {
    when(
      () => api.createToken(
        email: any(named: 'email'),
        password: any(named: 'password'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenAnswer(
      (_) async => const AuthTokenResult(token: 'token', user: testUser),
    );
    final app = await pumpApp(tester, api: api);

    await app.container
        .read(authControllerProvider.notifier)
        .login(email: 'a@example.com', password: 'secret');
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  testWidgets('from に外部 URL やログイン画面を仕込まれても従わない', (tester) async {
    when(api.fetchCurrentUser).thenAnswer((_) async => testUser);
    final app = await pumpApp(
      tester,
      api: api,
      store: FakeAuthStore(token: 'valid'),
    );

    for (final from in [
      '//evil.example.com',
      'https://evil.example.com',
      '/login',
      '/splash',
    ]) {
      app.router.go('${AppRoutes.login}?${AppRoutes.fromQueryParam}=$from');
      await tester.pumpAndSettle();

      expect(find.byType(LibraryScreen), findsOneWidget, reason: 'from=$from');
      expect(
        app.router.state.matchedLocation,
        AppRoutes.library,
        reason: 'from=$from',
      );
    }
  });

  testWidgets('401 を受けるとログイン画面へ戻る', (tester) async {
    when(api.fetchCurrentUser).thenAnswer((_) async => testUser);
    final store = FakeAuthStore(token: 'valid');
    final purger = RecordingPurger();
    final container = ProviderContainer(
      overrides: testOverrides(
        authStore: store,
        authApi: api,
        purgers: [purger],
      ),
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);

    router.go(AppRoutes.bookDetail(12));
    await tester.pumpAndSettle();
    expect(find.byType(TitleDetailScreen), findsOneWidget);

    await container
        .read(authControllerProvider.notifier)
        .handleSessionExpired();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(store.token, isNull);
    expect(purger.calls, 1);
  });

  testWidgets('冷起動のディープリンクはスプラッシュを経てもログイン後に復元される', (tester) async {
    // 起動時は必ず検証中 = スプラッシュを通るので、そこで from を落とさないこと
    final pending = Completer<User>();
    when(api.fetchCurrentUser).thenAnswer((_) => pending.future);
    when(
      () => api.createToken(
        email: any(named: 'email'),
        password: any(named: 'password'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenAnswer(
      (_) async => const AuthTokenResult(token: 'token', user: testUser),
    );
    final app = await pumpApp(
      tester,
      api: api,
      store: FakeAuthStore(token: 'expired'),
      settle: false,
    );

    app.router.go(AppRoutes.bookDetail(12));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      app.router.state.uri.queryParameters[AppRoutes.fromQueryParam],
      AppRoutes.bookDetail(12),
    );

    // トークンが失効していてログイン画面に落ちる
    pending.completeError(const UnauthorizedException());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      app.router.state.uri.queryParameters[AppRoutes.fromQueryParam],
      AppRoutes.bookDetail(12),
      reason: 'スプラッシュ経由でディープリンクを失ってはいけない',
    );

    await app.container
        .read(authControllerProvider.notifier)
        .login(email: 'a.com', password: 'secret');
    await tester.pumpAndSettle();

    expect(find.byType(TitleDetailScreen), findsOneWidget);
  });

  testWidgets('ログアウトするとログイン画面へ戻る', (tester) async {
    when(api.fetchCurrentUser).thenAnswer((_) async => testUser);
    when(api.deleteToken).thenAnswer((_) async {});
    final app = await pumpApp(
      tester,
      api: api,
      store: FakeAuthStore(token: 'valid'),
    );

    await app.container.read(authControllerProvider.notifier).logout();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
