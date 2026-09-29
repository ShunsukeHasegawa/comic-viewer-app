import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/progress/presentation/progress_sync_scope.dart';

/// アプリのルートウィジェット。
class ComicLazApp extends ConsumerWidget {
  const ComicLazApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 未送信の読書進捗の同期は画面に依らないので、ルータより外側で面倒を見る
    // （どの画面にいてもネットワーク復帰 / 復帰直後に送れるように）。
    return ProgressSyncScope(
      child: MaterialApp.router(
        title: 'Comic LAZ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
