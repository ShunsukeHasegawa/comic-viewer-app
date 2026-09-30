import 'package:comic_laz/app.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/user.dart';
import 'package:comic_laz/features/auth/presentation/login_screen.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/library/presentation/library_screen.dart';
import 'package:comic_laz/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/api_fakes.dart';
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

  testWidgets('セーフモードで表示できない巻を消したら SnackBar で知らせる（黙って消さないため）', (tester) async {
    const safeUser = User(id: 1, name: 'テスト太郎', safeMode: true);
    await tester.pumpWidget(
      wrapWithScope(
        const ComicLazApp(),
        overrides: testOverrides(
          authStore: FakeAuthStore(token: 'valid', user: safeUser),
          authApi: MockAuthApi()..stubCurrentUser(safeUser),
          // 詳細が 404（サーバーがセーフモードのユーザーに隠している）で、
          // セーフモード版の一覧（books_safe.json）にも載っていない。
          booksApi: FakeBooksApi(books: const [Book(id: 100)]),
          safeModeRevalidationStore: InMemorySafeModeRevalidationStore(
            pending: true,
          ),
          downloads: const {
            1: VolumeDownload(
              volumeId: 1,
              bookId: 7,
              filesVersion: 5,
              status: VolumeDownloadStatus.completed,
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('セーフモードで表示できない 1 巻のダウンロードを削除しました'), findsOneWidget);
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
