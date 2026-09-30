import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/storage/storage_protection.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/session_cleanup_notice.dart';
import 'features/downloads/application/auto_delete_runner.dart';
import 'features/downloads/application/download_queue.dart';
import 'features/downloads/application/safe_mode_revalidator.dart';
import 'features/progress/presentation/progress_sync_scope.dart';

/// アプリのルートウィジェット。
class ComicLazApp extends ConsumerStatefulWidget {
  const ComicLazApp({super.key});

  @override
  ConsumerState<ComicLazApp> createState() => _ComicLazAppState();
}

class _ComicLazAppState extends ConsumerState<ComicLazApp> {
  /// 画面を持たない処理（セーフモードの再検証）の結果を、どの画面にいても
  /// 知らせるための入口。
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    // ダウンロードキューも画面に依らず動かし続ける（#10）。どこからも
    // watch されていない provider は Riverpod が一時停止させるので、キューの
    // 中の「Wi-Fi に繋がったら流す」購読まで止まってしまう（詳細画面から
    // 一覧へ戻っただけで、Wi-Fi 待ちの巻が Wi-Fi に繋がっても始まらない）。
    ref.listen(downloadQueueProvider, (_, _) {});
    // 自動削除（#13）も同じ理由で画面に依らず購読しておく（起動時の 1 回と
    // 前面復帰を拾う。既定はオフで、そのときは台帳も控えも読まない）。
    ref.listen(autoDeleteRunnerProvider, (_, _) {});
    // 端末内データの保護（#15）。起動のたびに `.nomedia` とバックアップ除外を
    // 掛け直す（DB と転送の記録は画面に依らず作られるので、ここで起動時に走らせる）。
    ref.listen(storageProtectionProvider, (_, _) {});
    // セーフモードが ON になった後の再検証（#15）。サーバーがもう配信しない巻を
    // 消したら、黙って消さずに知らせる。
    ref.listen(safeModeRevalidatorProvider, (previous, next) {
      if (next == null || identical(previous, next)) return;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('セーフモードで表示できない ${next.volumes} 巻のダウンロードを削除しました'),
        ),
      );
    });
    // ログイン時に前回のデータを消し切れなかった（#15）。個人用アプリなので
    // ログインは止めないが、黙って通さずに知らせる（`AuthController` の説明）。
    ref.listen(sessionCleanupNoticeProvider, (previous, next) {
      if (next <= (previous ?? 0)) return;
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text(SessionCleanupNotice.message)),
      );
    });
    // 未送信の読書進捗の同期は画面に依らないので、ルータより外側で面倒を見る
    // （どの画面にいてもネットワーク復帰 / 復帰直後に送れるように）。
    return ProgressSyncScope(
      child: MaterialApp.router(
        title: 'Comic LAZ',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _messengerKey,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
