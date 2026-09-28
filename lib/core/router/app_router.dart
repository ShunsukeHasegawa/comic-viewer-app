import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/mypage/presentation/my_page_screen.dart';
import '../../features/settings/presentation/storage_settings_screen.dart';
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
            routes: [
              // マイページ配下に置く（ボトムナビを残したまま開く）。
              GoRoute(
                path: 'storage',
                builder: (context, state) => const StorageSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: AppRoutes.splash,
    builder: (context, state) => const SplashScreen(),
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

/// 認証状態に応じた遷移先。遷移が不要なら `null`。
@visibleForTesting
String? redirectForAuthState(AuthState authState, GoRouterState state) {
  final location = state.matchedLocation;

  return switch (authState) {
    AuthRestoring() =>
      location == AppRoutes.splash ? null : _withFrom(AppRoutes.splash, state),
    AuthUnauthenticated() =>
      location == AppRoutes.login ? null : _withFrom(AppRoutes.login, state),
    AuthAuthenticated() =>
      location == AppRoutes.login || location == AppRoutes.splash
          ? _pendingTarget(state) ?? AppRoutes.library
          : null,
  };
}

/// 認証前に開こうとしていた URL を `from` として引き継ぐ。
///
/// 冷起動は必ず `/splash` を経由するので、`/splash?from=...` から
/// `/login?from=...` へ **from を引き継ぐ**ことが重要（ディープリンクが失われる）。
String _withFrom(String destination, GoRouterState state) {
  final target = _pendingTarget(state) ?? _sanitizeTarget(state.uri.toString());
  if (target == null) return destination;
  return Uri(
    path: destination,
    queryParameters: {AppRoutes.fromQueryParam: target},
  ).toString();
}

/// 現在の URL が持っている `from`（引き継ぎ中のディープリンク）。
String? _pendingTarget(GoRouterState state) =>
    _sanitizeTarget(state.uri.queryParameters[AppRoutes.fromQueryParam]);

/// ログイン後に戻る先として妥当なら返す。妥当でなければ `null`。
String? _sanitizeTarget(String? target) {
  if (target == null || !target.startsWith('/')) return null;
  // `//example.com` のようなスキーム省略の外部 URL を弾く。
  if (target.startsWith('//')) return null;
  // 戻っても意味が無い URL。
  if (target == AppRoutes.library ||
      target.startsWith(AppRoutes.login) ||
      target.startsWith(AppRoutes.splash)) {
    return null;
  }
  return target;
}

/// アプリの [GoRouter]。
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.library,
    debugLogDiagnostics: kDebugMode,
    routes: buildRoutes(),
    redirect: (context, state) =>
        redirectForAuthState(ref.read(authControllerProvider), state),
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
  );
  // 認証状態が変わったら redirect を再評価させる。
  ref.listen(authControllerProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
}
