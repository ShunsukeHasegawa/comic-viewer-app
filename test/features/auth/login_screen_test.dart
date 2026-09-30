import 'dart:async';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/features/auth/application/auth_controller.dart';
import 'package:comic_laz/features/auth/data/auth_api.dart';
import 'package:comic_laz/features/auth/domain/auth_state.dart';
import 'package:comic_laz/features/auth/domain/session_cleanup_exception.dart';
import 'package:comic_laz/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/auth_fakes.dart';
import '../../support/test_scope.dart';

Future<ProviderContainer> pumpLoginScreen(
  WidgetTester tester, {
  required MockAuthApi api,
  FakeAuthStore? store,
  FakeInstallMarker? installMarker,
}) async {
  final container = createContainer(
    authStore: store ?? FakeAuthStore(),
    authApi: api,
    installMarker: installMarker,
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> fillAndSubmit(
  WidgetTester tester, {
  String email = 'a@example.com',
  String password = 'secret',
}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
  await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));
  await tester.pumpAndSettle();
}

void main() {
  late MockAuthApi api;

  setUp(() {
    api = MockAuthApi();
  });

  testWidgets('未入力ならバリデーションで止まり API を呼ばない', (tester) async {
    await pumpLoginScreen(tester, api: api);

    await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));
    await tester.pumpAndSettle();

    expect(find.text('メールアドレスを入力してください'), findsOneWidget);
    expect(find.text('パスワードを入力してください'), findsOneWidget);
    verifyNever(
      () => api.createToken(
        email: any(named: 'email'),
        password: any(named: 'password'),
        deviceName: any(named: 'deviceName'),
      ),
    );
  });

  testWidgets('メールアドレスの形式を検証する', (tester) async {
    await pumpLoginScreen(tester, api: api);

    await fillAndSubmit(tester, email: 'not-an-email');

    expect(find.text('メールアドレスの形式が正しくありません'), findsOneWidget);
  });

  testWidgets('ログインに成功するとログイン済みになる', (tester) async {
    when(
      () => api.createToken(
        email: any(named: 'email'),
        password: any(named: 'password'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenAnswer(
      (_) async => const AuthTokenResult(token: 'token', user: testUser),
    );
    final container = await pumpLoginScreen(tester, api: api);

    await fillAndSubmit(tester, email: '  a@example.com  ');

    expect(
      container.read(authControllerProvider),
      AuthState.authenticated(testUser),
    );
    // 前後の空白は落として送る
    verify(
      () => api.createToken(
        email: 'a@example.com',
        password: 'secret',
        deviceName: any(named: 'deviceName'),
      ),
    ).called(1);
  });

  testWidgets('認証情報が違えばメッセージを出し、再入力できる', (tester) async {
    when(
      () => api.createToken(
        email: any(named: 'email'),
        password: any(named: 'password'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenThrow(const InvalidCredentialsException());
    await pumpLoginScreen(tester, api: api);

    await fillAndSubmit(tester, password: 'wrong');

    expect(find.text('メールアドレスまたはパスワードが正しくありません。'), findsOneWidget);
    // 送信中のままにならない
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('圏外ならネットワークエラーを表示する', (tester) async {
    when(
      () => api.createToken(
        email: any(named: 'email'),
        password: any(named: 'password'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenThrow(const NetworkException());
    await pumpLoginScreen(tester, api: api);

    await fillAndSubmit(tester);

    expect(find.text('ネットワークに接続できませんでした。'), findsOneWidget);
  });

  // 入れ直し直後の認証情報を片付けられずにログインを止めたとき（#15）。黙って
  // 失敗させず、再試行できることを伝える（データの消し残しでは止めない）。
  testWidgets('入れ直し直後の片付けができなければ、その旨を表示して再試行できる', (tester) async {
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
    await pumpLoginScreen(
      tester,
      api: api,
      store: store,
      installMarker: FakeInstallMarker(fresh: true)..error = StateError('db'),
    );

    await fillAndSubmit(tester);

    expect(find.text(const SessionCleanupException().message), findsOneWidget);
    expect(store.token, isNull);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('送信中はボタンを無効化し、二重送信しない', (tester) async {
    final completer = Completer<AuthTokenResult>();
    when(
      () => api.createToken(
        email: any(named: 'email'),
        password: any(named: 'password'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenAnswer((_) => completer.future);
    await pumpLoginScreen(tester, api: api);

    await tester.enterText(find.byType(TextFormField).first, 'a@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();

    completer.complete(const AuthTokenResult(token: 'token', user: testUser));
    await tester.pumpAndSettle();

    verify(
      () => api.createToken(
        email: any(named: 'email'),
        password: any(named: 'password'),
        deviceName: any(named: 'deviceName'),
      ),
    ).called(1);
  });

  testWidgets('トークン失効でログイン画面に戻された場合はその旨を表示する', (tester) async {
    when(api.fetchCurrentUser).thenThrow(const UnauthorizedException());
    final container = await pumpLoginScreen(
      tester,
      api: api,
      store: FakeAuthStore(token: 'expired', user: testUser),
    );

    expect(
      container.read(authControllerProvider),
      const AuthState.unauthenticated(reason: SessionEndReason.expired),
    );
    expect(find.textContaining('有効期限が切れました'), findsOneWidget);
  });

  testWidgets('通常のログイン画面では失効メッセージを出さない', (tester) async {
    await pumpLoginScreen(tester, api: api);

    expect(find.textContaining('有効期限が切れました'), findsNothing);
  });

  testWidgets('パスワードの表示 / 非表示を切り替えられる', (tester) async {
    await pumpLoginScreen(tester, api: api);

    TextField passwordField() => tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).last,
        matching: find.byType(TextField),
      ),
    );

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('パスワードを表示'));
    await tester.pumpAndSettle();
    expect(passwordField().obscureText, isFalse);
  });
}
