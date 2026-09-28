import 'package:comic_laz/app.dart';
import 'package:comic_laz/features/auth/presentation/login_screen.dart';
import 'package:comic_laz/features/library/presentation/library_screen.dart';
import 'package:comic_laz/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fakes.dart';
import 'support/test_scope.dart';

void main() {
  testWidgets('未ログインで起動するとログイン画面が表示される', (tester) async {
    await tester.pumpWidget(
      wrapWithScope(
        const ComicLazApp(),
        overrides: testOverrides(authApi: MockAuthApi()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('保存済みトークンがあればライブラリ画面が表示される', (tester) async {
    await tester.pumpWidget(
      wrapWithScope(
        const ComicLazApp(),
        overrides: testOverrides(
          authStore: FakeAuthStore(token: 'valid'),
          authApi: MockAuthApi()..stubCurrentUser(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  testWidgets('設定エラー画面はメッセージを表示する', (tester) async {
    await tester.pumpWidget(
      const ConfigErrorApp(message: 'API_BASE_URL が空です。'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('設定エラー'), findsOneWidget);
    expect(find.textContaining('API_BASE_URL が空です。'), findsOneWidget);
  });
}
