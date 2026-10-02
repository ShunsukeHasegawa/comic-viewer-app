import 'package:comic_laz/app.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/user.dart';
import 'package:comic_laz/features/auth/application/session_cleanup_notice.dart';
import 'package:comic_laz/features/auth/presentation/login_screen.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/library/presentation/library_screen.dart';
import 'package:comic_laz/features/settings/application/theme_mode_setting.dart';
import 'package:comic_laz/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/api_fakes.dart';
import 'support/auth_fakes.dart';
import 'support/settings_fakes.dart';
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

  testWidgets('ログイン時に前回のデータを消し切れなかったら SnackBar で知らせる（止めずに通す代わりに黙らないため）', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithScope(
        const ComicLazApp(),
        overrides: testOverrides(authApi: MockAuthApi()),
      ),
    );
    await tester.pumpAndSettle();

    ProviderScope.containerOf(tester.element(find.byType(ComicLazApp)))
        .read(sessionCleanupNoticeProvider.notifier)
        .report();
    await tester.pump();

    expect(find.text(SessionCleanupNotice.message), findsOneWidget);
  });

  group('表示テーマ（#17）', () {
    ThemeMode appliedMode(WidgetTester tester) =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

    testWidgets('起動前に読み込んでおけば最初のフレームから保存済みのテーマで描く（スプラッシュ後に一瞬切り替わらない）', (
      tester,
    ) async {
      // main と同じ組み立て（bootstrapContainer → buildRootApp）を通す。読み込みを
      // runApp の後へ回したり、ProviderScope で別のコンテナを作り直したりする
      // 変更はここで落ちる。
      final container = await bootstrapContainer(
        testOverrides(
          authApi: MockAuthApi(),
          themeModeStore: InMemoryThemeModeStore(ThemeMode.dark),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildRootApp(container));

      // pumpAndSettle の前（最初のフレーム）で、端末がライトでもダークになっている。
      expect(appliedMode(tester), ThemeMode.dark);
      expect(
        Theme.of(tester.element(find.byType(Navigator).first)).brightness,
        Brightness.dark,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('設定を変えるとアプリ全体の表示が切り替わる', (tester) async {
      await tester.pumpWidget(
        wrapWithScope(
          const ComicLazApp(),
          overrides: testOverrides(authApi: MockAuthApi()),
        ),
      );
      await tester.pumpAndSettle();
      expect(appliedMode(tester), ThemeMode.system);

      await ProviderScope.containerOf(tester.element(find.byType(ComicLazApp)))
          .read(themeModeSettingProvider.notifier)
          .set(ThemeMode.light);
      await tester.pumpAndSettle();

      expect(appliedMode(tester), ThemeMode.light);
    });

    testWidgets('設定を読めなかったときはシステムに合わせて表示する（起動は止めない）', (tester) async {
      await tester.pumpWidget(
        wrapWithScope(
          const ComicLazApp(),
          overrides: testOverrides(
            authApi: MockAuthApi(),
            themeModeStore: InMemoryThemeModeStore(ThemeMode.dark)
              ..readError = Exception('db'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(appliedMode(tester), ThemeMode.system);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
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
