import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/device/network_kind_monitor.dart';
import '../../../core/storage/app_database.dart';

part 'download_settings.g.dart';

/// ダウンロードの設定（#10）。
class DownloadSettingsStore {
  DownloadSettingsStore(this._database);

  static const wifiOnlyKey = 'downloads.wifi_only';

  /// 通知の許可を一度求めたか。
  static const notificationPermissionRequestedKey =
      'downloads.notification_permission_requested';

  final AppDatabase _database;

  /// 「Wi-Fi のときだけダウンロードする」。既定は ON（モバイル回線で
  /// 1 巻数百 MB を勝手に使わない）。
  Future<bool> readWifiOnly() async => await _read(wifiOnlyKey) != 'false';

  Future<void> writeWifiOnly(bool value) => _write(wifiOnlyKey, '$value');

  /// 通知の許可をもう求めたか。
  ///
  /// 断られた後に積むたびダイアログを出し直さないため、結果に関わらず
  /// 「求めた」ことを残す（許可は OS の設定画面から変えられる）。
  Future<bool> readNotificationPermissionRequested() async =>
      await _read(notificationPermissionRequestedKey) == 'true';

  Future<void> markNotificationPermissionRequested() =>
      _write(notificationPermissionRequestedKey, 'true');

  Future<String?> _read(String key) async {
    final row = await (_database.select(
      _database.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _write(String key, String value) => _database
      .into(_database.settings)
      .insertOnConflictUpdate(SettingRow(key: key, value: value));
}

@Riverpod(keepAlive: true)
DownloadSettingsStore downloadSettingsStore(Ref ref) =>
    DownloadSettingsStore(ref.watch(appDatabaseProvider));

/// 「Wi-Fi のときだけダウンロードする」設定。
///
/// 実際の制限は OS の転送（`ArchiveTransport.setWifiOnly`）が行う。
/// アプリが閉じていても守られるよう、Dart 側では止めない。
@Riverpod(keepAlive: true)
class DownloadWifiOnly extends _$DownloadWifiOnly {
  @override
  Future<bool> build() =>
      ref.watch(downloadSettingsStoreProvider).readWifiOnly();

  /// 保存してから反映する（保存に失敗したら表示を変えず、例外を返す）。
  Future<void> set(bool value) async {
    await ref.read(downloadSettingsStoreProvider).writeWifiOnly(value);
    if (!ref.mounted) return;
    state = AsyncData(value);
  }
}

/// いまダウンロードが進める状況か。
enum DownloadGate {
  open,

  /// Wi-Fi 限定の設定で、Wi-Fi に繋がっていない（繋がれば自動で始まる）。
  waitingForWifi,
}

/// [DownloadWifiOnly] と回線の種類から、ダウンロードが進める状況かを決める。
///
/// **表示と失敗の解釈にだけ使う**（#10）。転送を止めるのは OS 側の Wi-Fi
/// 制限で、ここではない（アプリが閉じている間は Dart が動かないため）。
/// - 画面の「Wi-Fi 待ち」の表示
/// - Wi-Fi が切れて失敗した転送を再試行の回数に数えない判定
///   （`DownloadQueue` の F3。数えると Wi-Fi が 3 回途切れるだけで失敗になる）
///
/// 設定や回線がまだ分からない間は閉じておく。起動直後に一瞬「進める」と
/// 表示するより、数百ミリ秒「Wi-Fi 待ち」と出す方がよい。
@Riverpod(keepAlive: true)
DownloadGate downloadGate(Ref ref) {
  final setting = ref.watch(downloadWifiOnlyProvider);
  // 設定を読めなかったときは既定（ON）に倒す。
  final wifiOnly = setting.hasError ? true : setting.value;
  if (wifiOnly == false) return DownloadGate.open;
  if (wifiOnly == null) return DownloadGate.waitingForWifi;
  return ref.watch(networkKindProvider).value == NetworkKind.unmetered
      ? DownloadGate.open
      : DownloadGate.waitingForWifi;
}
