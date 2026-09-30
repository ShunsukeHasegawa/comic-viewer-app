import 'package:disk_space_2/disk_space_2.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/app_directories.dart';

part 'free_space_probe.g.dart';

/// 端末のストレージ（バイト）。
@immutable
class DeviceStorage {
  const DeviceStorage({required this.freeBytes, this.totalBytes});

  /// アプリが使える空き容量。
  final int freeBytes;

  /// 全体の容量（表示専用。取れなければ `null`）。
  final int? totalBytes;

  @override
  bool operator ==(Object other) =>
      other is DeviceStorage &&
      other.freeBytes == freeBytes &&
      other.totalBytes == totalBytes;

  @override
  int get hashCode => Object.hash(freeBytes, totalBytes);

  @override
  String toString() => 'DeviceStorage(free: $freeBytes, total: $totalBytes)';
}

/// 端末の空き容量（バイト）。**分からない場合は `null`**。
///
/// `DownloadQueue` の「足りなければ開始しない」判定が使う。
typedef FreeSpaceProbe = Future<int?> Function();

/// 端末のストレージ。**分からない場合は `null`**（設定画面は「不明」と出す）。
typedef DeviceStorageProbe = Future<DeviceStorage?> Function();

/// プラグイン呼び出しの差し込み口（MiB 単位の値を返す）。
///
/// 単体テストがプラットフォームチャネルに触らずに、単位の変換と失敗の扱いを
/// 確かめられるようにするため、プラグインの呼び出しはここに閉じ込める。
/// プラグインが実機で使えなかったときも、ここを自前の MethodChannel に
/// 差し替えるだけで provider の形は変えずに済む。
typedef DiskSpaceReader = ({
  Future<double?> Function(String path) freeMebibytesAt,
  Future<double?> Function() totalMebibytes,
});

/// `disk_space_2` を使う本番の読み取り。
///
/// - Android: `StatFs.availableBlocks`（バックグラウンドスレッド）。OS が回収
///   できる他アプリのキャッシュは含まないので、実際に書ける量より**少なめ**に出る
///   （止めすぎる側に倒れるが、足りないのに始めて途中で詰まるよりよい）。
/// - iOS: `volumeAvailableCapacityForImportantUsage`。取得に失敗すると例外では
///   なく `0` を返す（[probeDeviceStorage] が「不明」に倒す）。
///
/// iOS の空き容量 / 全体の容量は Apple の "required reason API"（DiskSpace）。
/// プラグインがプライバシーマニフェストを同梱していないので、アプリ側の
/// `ios/Runner/PrivacyInfo.xcprivacy` で宣言している（理由 E174.1）。
/// 読み取りを差し替えるときも、あの宣言は外さない（外すと App Store Connect
/// へのアップロードが ITMS-91053 で弾かれる）。
const DiskSpaceReader diskSpace2Reader = (
  freeMebibytesAt: DiskSpace.getFreeDiskSpaceForPath,
  totalMebibytes: _totalMebibytes,
);

Future<double?> _totalMebibytes() => DiskSpace.getTotalDiskSpace;

/// [path] のある領域の空き容量と全体の容量を測る。**決して投げない**。
///
/// 値が `0` 以下・NaN・無限大のときは「分からない」（`null`）にする。
/// iOS は失敗を `0` で返すので、そのまま使うと「空きが無い」と判定され、
/// `DownloadQueue` がすべてのダウンロードを容量不足で止めてしまう。
/// 例外（`PlatformException` / `MissingPluginException` / パスが無い）も同じく
/// 「分からない」にする。取得できない端末でダウンロードを塞がないため。
///
/// 全体の容量は表示にしか使わないので、取れなくても空き容量は返す。
Future<DeviceStorage?> probeDeviceStorage({
  required String path,
  required DiskSpaceReader reader,
}) async {
  final free = _toBytes(
    await _readQuietly(() => reader.freeMebibytesAt(path), 'free'),
  );
  if (free == null) return null;
  final total = _toBytes(await _readQuietly(reader.totalMebibytes, 'total'));
  return DeviceStorage(freeBytes: free, totalBytes: total);
}

Future<double?> _readQuietly(
  Future<double?> Function() read,
  String what,
) async {
  try {
    return await read();
  } on Object catch (error) {
    debugPrint('[storage] disk space ($what) unavailable: $error');
    return null;
  }
}

/// MiB をバイトにする（1 MiB 未満の誤差は容量の判定に影響しない）。
int? _toBytes(double? mebibytes) {
  if (mebibytes == null || !mebibytes.isFinite || mebibytes <= 0) return null;
  return (mebibytes * 1024 * 1024).floor();
}

/// 常に「分からない」を返す空き容量（テストの既定 / プラグインが使えないときの逃げ道）。
Future<int?> unknownFreeSpace() async => null;

/// 常に「分からない」を返すストレージ（テストの既定）。
Future<DeviceStorage?> unknownDeviceStorage() async => null;

/// 端末のストレージの測り方。
///
/// 測る場所はダウンロードの置き場（application support）。キャッシュ領域と
/// 別のボリュームになる端末でも、判定したいのは ZIP を書く側の空きだから。
/// ディレクトリが解決できないときも「分からない」にする（決して投げない）。
@Riverpod(keepAlive: true)
DeviceStorageProbe deviceStorageProbe(Ref ref) => () async {
  final String path;
  try {
    path = (await ref.read(appDirectoriesProvider.future)).support.path;
  } on Object catch (error) {
    debugPrint('[storage] app directories unavailable: $error');
    return null;
  }
  return probeDeviceStorage(path: path, reader: diskSpace2Reader);
};

/// ダウンロード前の空き容量チェックに使う値。
///
/// 設定画面の表示と同じ [deviceStorageProbeProvider] から取る（キューと画面で
/// 違う値を見せない）。テストはこの provider ごと差し替え、プラグインには
/// 触らない。
@Riverpod(keepAlive: true)
FreeSpaceProbe freeSpaceProbe(Ref ref) {
  final probe = ref.watch(deviceStorageProbeProvider);
  return () async => (await probe())?.freeBytes;
}
