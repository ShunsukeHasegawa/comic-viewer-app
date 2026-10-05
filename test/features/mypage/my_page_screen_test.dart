import 'package:comic_laz/core/router/app_routes.dart';
import 'package:comic_laz/domain/models/user.dart';
import 'package:comic_laz/features/auth/application/auth_controller.dart';
import 'package:comic_laz/features/auth/domain/auth_state.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/mypage/presentation/my_page_screen.dart';
import 'package:comic_laz/features/settings/application/keep_screen_on_setting.dart';
import 'package:comic_laz/features/settings/presentation/widgets/keep_screen_on_switch.dart';
import 'package:comic_laz/features/settings/presentation/widgets/theme_mode_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

/// マイページのいちばん下の「ログアウト」を押す。
///
/// テーマの切り替え（#17）が入って、テストの画面の高さでは最初から見えて
/// いないので、スクロールしてから押す。
Future<void> tapLogoutTile(WidgetTester tester) async {
  final tile = find.widgetWithText(ListTile, 'ログアウト');
  await scrollIntoView(tester, tile);
  await tester.tap(tile);
}

/// [finder] が押せるところまでスクロールする。
///
/// scrollUntilVisible は端が少し見えた時点で止まり、真ん中を押すと画面外に
/// なることがある（設定が増えて下の項目ほど起きる）。最後に全体を見せる。
Future<void> scrollIntoView(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 100);
  await tester.ensureVisible(finder);
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

  testWidgets('表示テーマを切り替えられる（設定の入口と同じマイページに置く。#17）', (tester) async {
    await pumpMyPage(tester);

    await tester.scrollUntilVisible(find.byType(ThemeModeSelector), 100);
    expect(find.text('テーマ'), findsOneWidget);
    expect(find.text('ダーク'), findsOneWidget);
  });

  testWidgets('「読書中は画面を消さない」をテーマの近くで切り替えられる（#19）', (tester) async {
    final app = await pumpMyPage(tester);

    final tile = find.byKey(KeepScreenOnSwitch.switchKey);
    await scrollIntoView(tester, tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(app.container.read(keepScreenOnSettingProvider).value, isFalse);
  });

  testWidgets('一般ユーザーにはバッジを出さない', (tester) async {
    await pumpMyPage(tester);

    expect(find.text('管理者'), findsNothing);
    expect(find.text('セーフモード'), findsNothing);
  });

  testWidgets('ログアウトは確認ダイアログで端末内データの削除を伝える', (tester) async {
    final app = await pumpMyPage(tester);

    await tapLogoutTile(tester);
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

    await tapLogoutTile(tester);
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

    await tapLogoutTile(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ログアウト'));
    await tester.pumpAndSettle();

    expect(find.text('ログアウトに失敗しました。もう一度お試しください。'), findsOneWidget);
  });

  downloadEntryTests();
}

/// ダウンロード管理へ遷移できるよう、go_router の中でマイページを開く。
Future<GoRouter> pumpMyPageInRouter(
  WidgetTester tester, {
  Map<int, VolumeDownload> downloads = const {},
}) async {
  final container = createContainer(
    authStore: FakeAuthStore(token: 'valid', user: testUser),
    authApi: MockAuthApi()..stubCurrentUser(),
    downloads: downloads,
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: AppRoutes.myPage,
    routes: [
      GoRoute(
        path: AppRoutes.myPage,
        builder: (context, state) => const MyPageScreen(),
        routes: [
          GoRoute(
            path: 'downloads',
            builder: (context, state) => const Text('ダウンロード管理画面'),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void downloadEntryTests() {
  group('ダウンロード', () {
    testWidgets('マイページからダウンロード管理を開ける（プレースホルダを置き換えた）', (tester) async {
      final router = await pumpMyPageInRouter(tester);

      expect(find.text('ダウンロードしたコミックはありません'), findsOneWidget);
      await tester.tap(find.text('ダウンロード'));
      await tester.pumpAndSettle();

      expect(find.text('ダウンロード管理画面'), findsOneWidget);
      expect(router.state.uri.toString(), AppRoutes.downloadManager);
    });

    testWidgets('読める巻の数と容量・進行中の数を出す（管理画面・設定画面と同じ数え方）', (tester) async {
      await pumpMyPageInRouter(
        tester,
        downloads: {
          340: const VolumeDownload(
            volumeId: 340,
            bookId: 12,
            filesVersion: 1,
            status: VolumeDownloadStatus.completed,
            totalBytes: 1024 * 1024,
            pageCount: 10,
          ),
          // 取り直し中の旧世代は読めるので数える（進行中にも数える）。
          341: const VolumeDownload(
            volumeId: 341,
            bookId: 12,
            filesVersion: 1,
            status: VolumeDownloadStatus.downloading,
            totalBytes: 1024 * 1024,
            pageCount: 10,
          ),
          // 初回の途中は読めないので容量に数えない。
          342: const VolumeDownload(
            volumeId: 342,
            bookId: 12,
            filesVersion: 0,
            status: VolumeDownloadStatus.paused,
            receivedBytes: 500,
            totalBytes: 1024 * 1024,
          ),
        },
      );

      expect(find.text('2 巻・2.0 MB（進行中 2）'), findsOneWidget);
    });
  });
}
