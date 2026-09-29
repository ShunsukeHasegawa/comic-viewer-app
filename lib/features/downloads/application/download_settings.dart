import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/device/network_kind_monitor.dart';
import '../../../core/storage/app_database.dart';

part 'download_settings.g.dart';

/// ダウンロードの設定（#10）。
class DownloadSettingsStore {
  DownloadSettingsStore(this._database);

  static const wifiOnlyKey = 'downloads.wifi_only';

  final AppDatabase _database;

  /// 「Wi-Fi のときだけダウンロードする」。既定は ON（モバイル回線で
  /// 1 巻数百 MB を勝手に使わない）。
  Future<bool> readWifiOnly() async {
    final row = await (_database.select(
      _database.settings,
    )..where((t) => t.key.equals(wifiOnlyKey))).getSingleOrNull();
    return row?.value != 'false';
  }

  Future<void> writeWifiOnly(bool value) => _database
      .into(_database.settings)
      .insertOnConflictUpdate(SettingRow(key: wifiOnlyKey, value: '$value'));
}

@Riverpod(keepAlive: true)
DownloadSettingsStore downloadSettingsStore(Ref ref) =>
    DownloadSettingsStore(ref.watch(appDatabaseProvider));

/// 「Wi-Fi のときだけダウンロードする」設定。
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

/// いまダウンロードを走らせてよいか。
enum DownloadGate {
  open,

  /// Wi-Fi 限定の設定で、Wi-Fi に繋がっていない（繋がれば自動で始まる）。
  waitingForWifi,
}

/// [DownloadWifiOnly] と回線の種類から、キューを流してよいかを決める。
///
/// 設定や回線がまだ分からない間は閉じておく。起動直後に一瞬モバイル回線で
/// 走り出してしまうより、数百ミリ秒待たせる方がよい。
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
