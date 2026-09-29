import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderBase;

import '../../../core/device/connectivity_monitor.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../history/application/history_controller.dart';
import '../../library/application/library_controller.dart';
import '../../mypage/application/stats_controller.dart';
import '../application/progress_syncer.dart';

/// 未送信の読書進捗を「送れそうになったタイミング」で流し込む（#12）。
///
/// 送る契機は 3 つ:
/// - ログイン済みになった直後（アプリ起動時 / 再ログイン時）
/// - ネットワーク復帰時
/// - フォアグラウンド復帰時（別端末で進めた分の取り込みも兼ねる）
///
/// ビューアを閉じるときの送信は [LocalProgressRecorder] が行うので、ここは
/// 「圏外で溜まった分の後始末」に徹する。未ログインでは送らない（401 を
/// 誘発してセッション失効の扱いを汚さない）。
class ProgressSyncScope extends ConsumerStatefulWidget {
  const ProgressSyncScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ProgressSyncScope> createState() => _ProgressSyncScopeState();
}

class _ProgressSyncScopeState extends ConsumerState<ProgressSyncScope> {
  AppLifecycleListener? _lifecycleListener;
  StreamSubscription<void>? _connectivity;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _syncQuietly);
    _connectivity = ref
        .read(connectivityMonitorProvider)
        .onRestored
        .listen((_) => _syncQuietly());
    // 既にログイン済みの状態でこの widget が作られた場合（トークン検証が
    // 先に終わっていた / 作り直された）は `ref.listen` が発火しないので、
    // 最初のフレームで 1 回だけ試す。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncQuietly();
    });
  }

  @override
  void dispose() {
    _connectivity?.cancel();
    _lifecycleListener?.dispose();
    super.dispose();
  }

  /// best-effort。失敗しても画面には出さない（次の契機で送り直す）。
  void _syncQuietly() {
    if (ref.read(authControllerProvider) is! AuthAuthenticated) return;
    unawaited(
      ref
          .read(progressSyncerProvider)
          .sync()
          .then(_refreshProgressViews)
          .catchError((Object _) {}),
    );
  }

  /// 同期でサーバー / ローカルの値が動いたら、進捗を出している画面を作り直す。
  ///
  /// 黙って古い進捗を見せ続けないため。表示していない画面を作り直すと無駄な
  /// 取得が走るので、生きている provider だけ。
  void _refreshProgressViews(bool changed) {
    if (!changed || !mounted) return;
    final providers = <ProviderBase<Object?>>[
      libraryControllerProvider,
      historyControllerProvider,
      statsControllerProvider,
    ];
    for (final provider in providers) {
      if (ref.exists(provider)) ref.invalidate(provider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ログイン完了（起動時のトークン検証 / ログイン操作）で送る。
    ref.listen(authControllerProvider, (previous, next) {
      if (previous is! AuthAuthenticated && next is AuthAuthenticated) {
        _syncQuietly();
      }
    });
    return widget.child;
  }
}
