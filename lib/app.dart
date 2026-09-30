import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/downloads/application/auto_delete_runner.dart';
import 'features/downloads/application/download_queue.dart';
import 'features/progress/presentation/progress_sync_scope.dart';

/// アプリのルートウィジェット。
class ComicLazApp extends ConsumerWidget {
  const ComicLazApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ダウンロードキューも画面に依らず動かし続ける（#10）。どこからも
    // watch されていない provider は Riverpod が一時停止させるので、キューの
    // 中の「Wi-Fi に繋がったら流す」購読まで止まってしまう（詳細画面から
    // 一覧へ戻っただけで、Wi-Fi 待ちの巻が Wi-Fi に繋がっても始まらない）。
    ref.listen(downloadQueueProvider, (_, _) {});
    // 自動削除（#13）も同じ理由で画面に依らず購読しておく（起動時の 1 回と
    // 前面復帰を拾う。既定はオフで、そのときは台帳も控えも読まない）。
    ref.listen(autoDeleteRunnerProvider, (_, _) {});
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
