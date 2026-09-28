import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/mypage/presentation/my_page_screen.dart';
import '../../features/title/presentation/title_detail_screen.dart';
import '../../features/viewer/presentation/viewer_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'not_found_screen.dart';

part 'app_router.g.dart';

/// ルート定義。テストからも同じテーブルを使えるよう関数として切り出す。
List<RouteBase> buildRoutes() => [
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) =>
        AppShell(navigationShell: navigationShell),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.library,
            builder: (context, state) => const LibraryScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.history,
            builder: (context, state) => const HistoryScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.myPage,
            builder: (context, state) => const MyPageScreen(),
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: AppRoutes.login,
    builder: (context, state) => const LoginScreen(),
  ),
  // `/book/view/{id}` は `/book/{id}` より先に宣言する。
  GoRoute(
    path: AppRoutes.viewerPattern,
    builder: (context, state) => _withIntParam(
      state,
      AppRoutes.volumeIdParam,
      (volumeId) => ViewerScreen(volumeId: volumeId),
    ),
  ),
  GoRoute(
    path: AppRoutes.bookDetailPattern,
    builder: (context, state) => _withIntParam(
      state,
      AppRoutes.bookIdParam,
      (bookId) => TitleDetailScreen(bookId: bookId),
    ),
  ),
];

/// 正の整数のパスパラメータを取り出す。不正なら [NotFoundScreen] を返す。
Widget _withIntParam(
  GoRouterState state,
  String name,
  Widget Function(int value) builder,
) {
  final raw = state.pathParameters[name];
  final value = raw == null ? null : int.tryParse(raw);
  if (value == null || value <= 0) {
    return NotFoundScreen(location: state.uri.toString());
  }
  return builder(value);
}

/// アプリの [GoRouter]。
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.library,
    debugLogDiagnostics: kDebugMode,
    routes: buildRoutes(),
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
  );
  ref.onDispose(router.dispose);
  return router;
}
