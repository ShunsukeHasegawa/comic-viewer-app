import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_monitor.g.dart';

/// ネットワークが繋がったことの通知（#12 の同期トリガ）。
///
/// プラットフォームチャネルを触るので抽象を切る（テストでは差し替える）。
/// 「繋がっているか」を問い合わせる API は出さない: 接続の有無は OS の申告に
/// すぎず、自宅サーバーに届くかは別問題なので、**送信の可否は実際の通信結果で
/// 判断する**（この通知は「試す価値が出た」合図としてだけ使う）。
abstract interface class ConnectivityMonitor {
  /// 圏外 → 接続あり に変わったときだけ流れる。
  Stream<void> get onRestored;
}

class PluginConnectivityMonitor implements ConnectivityMonitor {
  PluginConnectivityMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<void> get onRestored => _connectivity.onConnectivityChanged
      .map(isOnline)
      // 同じ状態の繰り返し（Wi-Fi → モバイルなど）では流さない。
      .distinct()
      .where((online) => online)
      .map<void>((_) {});

  /// 何らかの経路で繋がっているか。
  ///
  /// 空リストは「接続なし」（プラグインは圏外を `none` か空で返す）。
  static bool isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}

@Riverpod(keepAlive: true)
ConnectivityMonitor connectivityMonitor(Ref ref) => PluginConnectivityMonitor();
