import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_kind_monitor.g.dart';

/// 接続している回線の種類（従量課金かどうか）。
enum NetworkKind {
  /// Wi-Fi / 有線。「Wi-Fi のときだけダウンロード」で通してよい回線。
  unmetered,

  /// モバイル回線など。Wi-Fi 以外は全部ここに寄せる（数百 MB を勝手に使わない）。
  metered,

  /// 圏外。
  none,
}

/// 回線の種類の通知（#10 の Wi-Fi 限定ダウンロード）。
///
/// `ConnectivityMonitor` と違い「今どの回線か」を問い合わせる API を出す。
/// ここで判断するのは「通信量を気にすべき回線か」だけで、自宅サーバーに
/// 届くかどうかは相変わらず実際の通信結果で判断する（CLAUDE.md）。
abstract interface class NetworkKindMonitor {
  Future<NetworkKind> current();

  /// 回線の種類が変わるたびに流れる（同じ種類の繰り返しは流さない）。
  Stream<NetworkKind> get changes;
}

class PluginNetworkKindMonitor implements NetworkKindMonitor {
  PluginNetworkKindMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<NetworkKind> current() async =>
      classify(await _connectivity.checkConnectivity());

  @override
  Stream<NetworkKind> get changes =>
      _connectivity.onConnectivityChanged.map(classify).distinct();

  /// プラグインの結果を回線の種類に分ける。
  ///
  /// VPN は下の回線と一緒に返る（`[vpn, wifi]` など）ので、Wi-Fi / 有線が
  /// 1 つでも含まれていれば従量課金ではないとみなす。VPN だけ・種類不明
  /// （`other`）は下の回線が分からないので、安全側（従量課金）に倒す。
  static NetworkKind classify(List<ConnectivityResult> results) {
    if (results.any(
      (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet,
    )) {
      return NetworkKind.unmetered;
    }
    if (results.any((r) => r != ConnectivityResult.none)) {
      return NetworkKind.metered;
    }
    return NetworkKind.none;
  }
}

@Riverpod(keepAlive: true)
NetworkKindMonitor networkKindMonitor(Ref ref) => PluginNetworkKindMonitor();

/// 今の回線の種類。最初の問い合わせが終わるまでは読み込み中。
@Riverpod(keepAlive: true)
Stream<NetworkKind> networkKind(Ref ref) async* {
  final monitor = ref.watch(networkKindMonitorProvider);
  yield await monitor.current();
  yield* monitor.changes;
}
