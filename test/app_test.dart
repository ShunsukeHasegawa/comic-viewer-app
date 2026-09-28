import 'package:comic_laz/app.dart';
import 'package:comic_laz/core/config/app_config.dart';
import 'package:comic_laz/features/library/presentation/library_screen.dart';
import 'package:comic_laz/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('起動するとライブラリ画面が表示される', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.from(
              apiBaseUrl: 'http://localhost:8000',
              flavor: 'development',
            ),
          ),
        ],
        child: const ComicLazApp(),
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
