import 'dart:async';

import 'package:comic_laz/core/router/app_router.dart';
import 'package:comic_laz/core/router/app_routes.dart';
import 'package:comic_laz/core/router/not_found_screen.dart';
import 'package:comic_laz/core/widgets/app_back_button.dart';
import 'package:comic_laz/data/api/books_api.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/read_volume.dart';
import 'package:comic_laz/features/downloads/presentation/download_manager_screen.dart';
import 'package:comic_laz/features/history/presentation/history_screen.dart';
import 'package:comic_laz/features/library/presentation/library_screen.dart';
import 'package:comic_laz/features/mypage/presentation/my_page_screen.dart';
import 'package:comic_laz/features/title/presentation/title_detail_screen.dart';
import 'package:comic_laz/features/viewer/presentation/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/api_fakes.dart';
import '../../support/auth_fakes.dart';
import '../../support/test_scope.dart';

/// 指定 URL でルータを起動する。
Future<GoRouter> pumpRouterAt(
  WidgetTester tester,
  String location, {
  BooksApi? booksApi,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: buildRoutes(),
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    wrapWithScope(
      MaterialApp.router(routerConfig: router),
      overrides: testOverrides(authApi: MockAuthApi(), booksApi: booksApi),
    ),
  );
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

  testWidgets('/mypage/downloads はボトムナビを残したまま開く', (tester) async {
    await pumpRouterAt(tester, AppRoutes.downloadManager);

    expect(find.byType(DownloadManagerScreen), findsOneWidget);
    // マイページ配下（設定画面から行き来する）なのでタブは残す。
    expect(find.byType(NavigationBar), findsOneWidget);
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

  testWidgets('タイトル詳細を直接開いても行き止まりにならない', (tester) async {
    // ログイン画面は認証状態による redirect で管理するため対象外。
    await pumpRouterAt(tester, AppRoutes.bookDetail(12));

    final backButton = find.byType(AppBackButton);
    expect(backButton, findsOneWidget, reason: '脱出口が無い');

    await tester.tap(backButton);
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget, reason: '戻れない');
  });

  testWidgets('ビューア（巻情報を取得できない）でも閉じてライブラリへ戻れる', (tester) async {
    // ビューアは全画面表示なので AppBar を持たず、自前の「閉じる」で離脱する。
    await pumpRouterAt(tester, AppRoutes.viewer(34));

    final closeButton = find.byTooltip('閉じる');
    expect(closeButton, findsOneWidget, reason: '脱出口が無い');

    await tester.tap(closeButton);
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget, reason: '戻れない');
  });

  testWidgets('読み込めたビューアもメニューの「閉じる」でライブラリへ戻れる', (tester) async {
    await pumpRouterAt(
      tester,
      AppRoutes.viewer(340),
      booksApi: FakeBooksApi(
        readVolume: ReadVolume(
          id: 340,
          volume: 3,
          files: const [1, 2, 3],
          filesVersion: 1,
          book: const Book(id: 12, title: '進撃の巨人'),
        ),
      ),
    );
    expect(find.byType(PageView), findsOneWidget, reason: '読み込めている');

    // 中央タップでメニューを開いてから閉じる
    final size = tester.getSize(find.byType(MaterialApp));
    await tester.tapAt(Offset(size.width / 2, size.height / 2));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsOneWidget);
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
    final container = createContainer(
      authStore: FakeAuthStore(token: 'valid', user: testUser),
      authApi: MockAuthApi()..stubCurrentUser(),
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);

    expect(router.configuration.routes, isNotEmpty);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
  });
}
