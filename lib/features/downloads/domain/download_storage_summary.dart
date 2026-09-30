import 'package:flutter/foundation.dart' show immutable;

import 'volume_download.dart';

/// ダウンロードが端末で使っている容量（設定画面の内訳）。
///
/// ダウンロード管理画面と**同じ規則**で数える（2 つの画面の数字を揃える）:
/// - 読める巻（[VolumeDownload.hasInstalledArchive]）は `totalBytes`
///   （確定時にマニフェストの `archive_bytes`、無ければ実ファイル長）。
///   「更新あり」の取り直し中の旧世代もここに入る（ZIP は端末に残っている）。
/// - それ以外の途中の行は受信済みバイトを「途中」として別に数える
///   （読めないが、端末の容量は使っている）。
///
/// 既知の近似: 取り直し中は `totalBytes` が新世代の値で上書きされる。
/// 旧世代とほぼ同じ大きさなので、そのまま使う。
@immutable
class DownloadStorageSummary {
  const DownloadStorageSummary({
    this.installedVolumes = 0,
    this.installedBytes = 0,
    this.partialBytes = 0,
  });

  /// 読める巻の数。
  final int installedVolumes;

  /// 読める巻の容量の合計。
  final int installedBytes;

  /// 一度も完了していない巻（取得中 / 待機 / 中断 / 失敗）の受信済みバイト。
  final int partialBytes;

  /// ダウンロードが使っている容量の合計。
  int get totalBytes => installedBytes + partialBytes;

  @override
  bool operator ==(Object other) =>
      other is DownloadStorageSummary &&
      other.installedVolumes == installedVolumes &&
      other.installedBytes == installedBytes &&
      other.partialBytes == partialBytes;

  @override
  int get hashCode =>
      Object.hash(installedVolumes, installedBytes, partialBytes);

  @override
  String toString() =>
      'DownloadStorageSummary($installedVolumes vols, '
      '$installedBytes B, partial $partialBytes B)';
}

/// 台帳から容量の内訳を出す。
DownloadStorageSummary summarizeDownloads(Map<int, VolumeDownload> ledger) {
  var installedVolumes = 0;
  var installedBytes = 0;
  var partialBytes = 0;
  for (final download in ledger.values) {
    if (download.hasInstalledArchive) {
      installedVolumes++;
      installedBytes += download.totalBytes;
    } else if (download.receivedBytes > 0) {
      partialBytes += download.receivedBytes;
    }
  }
  return DownloadStorageSummary(
    installedVolumes: installedVolumes,
    installedBytes: installedBytes,
    partialBytes: partialBytes,
  );
}
