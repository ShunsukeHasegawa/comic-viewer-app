import 'package:comic_laz/domain/models/user.dart';
import 'package:comic_laz/features/auth/application/auth_controller.dart';
import 'package:comic_laz/features/auth/domain/auth_state.dart';
import 'package:comic_laz/features/mypage/presentation/my_page_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/auth_fakes.dart';
import '../../support/test_scope.dart';

Future<
  ({ProviderContainer container, FakeAuthStore store, RecordingPurger purger})
>
pumpMyPage(WidgetTester tester, {User user = testUser}) async {
  final api = MockAuthApi()..stubCurrentUser(user);
  when(api.deleteToken).thenAnswer((_) async {});
  final store = FakeAuthStore(token: 'valid', user: user);
  final purger = RecordingPurger();
  final container = createContainer(
    authStore: store,
    authApi: api,
    purgers: [purger],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MyPageScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return (container: container, store: store, purger: purger);
}

Future<void> pumpMyPageWithFailingLogout(WidgetTester tester) async {
  final api = MockAuthApi()..stubCurrentUser();
  // ApiException 以外（プラットフォーム例外など）は logout から漏れてくる。
  when(api.deleteToken).thenThrow(const FakePlatformException('boom'));
  final container = createContainer(
    authStore: FakeAuthStore(token: 'valid', user: testUser),
    authApi: api,
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MyPageScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ログイン中のユーザーを表示する', (tester) async {
    await pumpMyPage(
      tester,
      user: const User(
        id: 1,
        name: '長谷川',
        email: 'a@example.com',
        isAdmin: true,
        safeMode: true,
      ),
    );

    expect(find.text('長谷川'), findsOneWidget);
    expect(find.text('a@example.com'), findsOneWidget);
    expect(find.text('管理者'), findsOneWidget);
    expect(find.text('セーフモード'), findsOneWidget);
  });

  testWidgets('一般ユーザーにはバッジを出さない', (tester) async {
    await pumpMyPage(tester);

    expect(find.text('管理者'), findsNothing);
    expect(find.text('セーフモード'), findsNothing);
  });

  testWidgets('ログアウトは確認ダイアログで端末内データの削除を伝える', (tester) async {
    final app = await pumpMyPage(tester);

    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ダウンロードしたコミックと読書進捗は削除されます'), findsOneWidget);

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(
      app.container.read(authControllerProvider),
      isA<AuthAuthenticated>(),
    );
    expect(app.store.token, 'valid');
    expect(app.purger.calls, 0);
  });

  testWidgets('確認するとログアウトし、端末内データを破棄する', (tester) async {
    final app = await pumpMyPage(tester);

    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ログアウト'));
    await tester.pumpAndSettle();

    expect(
      app.container.read(authControllerProvider),
      const AuthState.unauthenticated(reason: SessionEndReason.signedOut),
    );
    expect(app.store.token, isNull);
    expect(app.purger.calls, 1);
  });

  testWidgets('ログアウトが失敗したらユーザーに伝える', (tester) async {
    await pumpMyPageWithFailingLogout(tester);

    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ログアウト'));
    await tester.pumpAndSettle();

    expect(find.text('ログアウトに失敗しました。もう一度お試しください。'), findsOneWidget);
  });
}
