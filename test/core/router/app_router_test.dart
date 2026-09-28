import 'dart:async';

import 'package:comic_laz/core/router/app_router.dart';
import 'package:comic_laz/core/router/app_routes.dart';
import 'package:comic_laz/core/router/not_found_screen.dart';
import 'package:comic_laz/core/widgets/app_back_button.dart';
import 'package:comic_laz/features/history/presentation/history_screen.dart';
import 'package:comic_laz/features/library/presentation/library_screen.dart';
import 'package:comic_laz/features/mypage/presentation/my_page_screen.dart';
import 'package:comic_laz/features/title/presentation/title_detail_screen.dart';
import 'package:comic_laz/features/viewer/presentation/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// 指定 URL でルータを起動する。
Future<GoRouter> pumpRouterAt(WidgetTester tester, String location) async {
  final router = GoRouter(
    initialLocation: location,
    routes: buildRoutes(),
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('URL 生成ヘルパはパターンと対応している', (tester) async {
    expect(AppRoutes.bookDetail(12), '/book/12');
    expect(AppRoutes.viewer(34), '/book/view/34');
  });

  testWidgets('ルート URL でライブラリが表示される', (tester) async {
    await pumpRouterAt(tester, AppRoutes.library);

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('/book/{id} でタイトル詳細が表示される', (tester) async {
    await pumpRouterAt(tester, AppRoutes.bookDetail(12));

    final screen = tester.widget<TitleDetailScreen>(
      find.byType(TitleDetailScreen),
    );
    expect(screen.bookId, 12);
    // 全画面表示なのでボトムナビは出さない
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('/book/view/{id} は詳細ではなくビューアに解決される', (tester) async {
    await pumpRouterAt(tester, AppRoutes.viewer(34));

    final screen = tester.widget<ViewerScreen>(find.byType(ViewerScreen));
    expect(screen.volumeId, 34);
    expect(find.byType(TitleDetailScreen), findsNothing);
  });

  testWidgets('数値でない / 非正の ID は NotFound になる', (tester) async {
    for (final location in [
      '/book/abc',
      '/book/0',
      '/book/-3',
      '/book/view/abc',
      '/book/view',
    ]) {
      await pumpRouterAt(tester, location);
      expect(
        find.byType(NotFoundScreen),
        findsOneWidget,
        reason: '$location は NotFound',
      );
    }
  });

  testWidgets('未知の URL は NotFound になり、ライブラリへ戻れる', (tester) async {
    final router = await pumpRouterAt(tester, '/unknown/path');
    expect(find.byType(NotFoundScreen), findsOneWidget);

    await tester.tap(find.text('ライブラリへ戻る'));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(router.state.uri.toString(), AppRoutes.library);
  });

  testWidgets('全画面ページを直接開いても行き止まりにならない', (tester) async {
    for (final location in [
      AppRoutes.viewer(34),
      AppRoutes.bookDetail(12),
      AppRoutes.login,
    ]) {
      await pumpRouterAt(tester, location);

      final backButton = find.byType(AppBackButton);
      expect(backButton, findsOneWidget, reason: ' に脱出口が無い');

      await tester.tap(backButton);
      await tester.pumpAndSettle();
      expect(find.byType(LibraryScreen), findsOneWidget, reason: ' から戻れない');
    }
  });

  testWidgets('詳細から遷移した場合は元の画面に戻る', (tester) async {
    final router = await pumpRouterAt(tester, AppRoutes.library);
    unawaited(router.push(AppRoutes.bookDetail(12)));
    await tester.pumpAndSettle();
    expect(find.byType(TitleDetailScreen), findsOneWidget);

    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  testWidgets('ボトムナビでタブを切り替えられる', (tester) async {
    await pumpRouterAt(tester, AppRoutes.library);

    await tester.tap(find.text('履歴'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);

    await tester.tap(find.text('マイページ'));
    await tester.pumpAndSettle();
    expect(find.byType(MyPageScreen), findsOneWidget);

    await tester.tap(find.text('ライブラリ'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  testWidgets('routerProvider はライブラリを初期表示にする', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(routerProvider);

    expect(router.configuration.routes, isNotEmpty);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
  });
}
