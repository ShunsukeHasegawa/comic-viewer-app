import 'package:flutter/foundation.dart' show immutable;

import '../../../core/storage/app_database.dart';

export '../../../core/storage/app_database.dart' show VolumeDownloadStatus;

/// 巻 1 つ分のダウンロード状態（画面に出す形）。
///
/// drift の行をそのまま UI に配らない。再開位置のような「保存はするが表示には
/// 使わない」情報を画面側に持ち込まないため。
@immutable
class VolumeDownload {
  const VolumeDownload({
    required this.volumeId,
    required this.bookId,
    required this.filesVersion,
    required this.status,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.pageCount = 0,
    this.archiveEtag,
    this.failureReason,
  });

  factory VolumeDownload.fromRow(DownloadedVolumeRow row) => VolumeDownload(
    volumeId: row.volumeId,
    bookId: row.bookId,
    filesVersion: row.filesVersion,
    status: row.status,
    receivedBytes: row.receivedBytes,
    totalBytes: row.totalBytes,
    pageCount: row.pageCount,
    archiveEtag: row.archiveEtag,
    failureReason: row.failureReason,
  );

  final int volumeId;
  final int bookId;

  /// 取得した（取得しようとしている）内容のバージョン。
  final int filesVersion;

  final VolumeDownloadStatus status;
  final int receivedBytes;
  final int totalBytes;
  final int pageCount;
  final String? archiveEtag;
  final String? failureReason;

  /// 0〜1。全体のバイト数が分からないうちは `null`（不定の進捗表示にする）。
  double? get progress {
    if (totalBytes <= 0) return null;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  /// 進捗のパーセント表示（0〜100）。
  int get percent => ((progress ?? 0) * 100).round();

  /// キューに載っている（待機中 / 取得中）。
  bool get isActive =>
      status == VolumeDownloadStatus.queued ||
      status == VolumeDownloadStatus.downloading;

  bool get isCompleted => status == VolumeDownloadStatus.completed;

  /// もう一度開始できる状態か（中断 / 失敗）。
  bool get isResumable =>
      status == VolumeDownloadStatus.paused ||
      status == VolumeDownloadStatus.failed;

  /// サーバー側の `files_version` と食い違っている（= 更新あり）。
  ///
  /// [currentFilesVersion] が `null`（サーバー側が不明）のときは判定しない。
  /// 通信できないだけで「更新あり」と表示すると、読めるはずのものが
  /// 古い扱いになってしまう。
  bool isOutdated(int? currentFilesVersion) =>
      isCompleted &&
      currentFilesVersion != null &&
      currentFilesVersion != filesVersion;

  VolumeDownload copyWith({
    int? filesVersion,
    VolumeDownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    int? pageCount,
    String? archiveEtag,
    String? failureReason,
    bool clearFailureReason = false,
  }) => VolumeDownload(
    volumeId: volumeId,
    bookId: bookId,
    filesVersion: filesVersion ?? this.filesVersion,
    status: status ?? this.status,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    pageCount: pageCount ?? this.pageCount,
    archiveEtag: archiveEtag ?? this.archiveEtag,
    failureReason: clearFailureReason
        ? null
        : (failureReason ?? this.failureReason),
  );

  @override
  bool operator ==(Object other) =>
      other is VolumeDownload &&
      other.volumeId == volumeId &&
      other.bookId == bookId &&
      other.filesVersion == filesVersion &&
      other.status == status &&
      other.receivedBytes == receivedBytes &&
      other.totalBytes == totalBytes &&
      other.pageCount == pageCount &&
      other.archiveEtag == archiveEtag &&
      other.failureReason == failureReason;

  @override
  int get hashCode => Object.hash(
    volumeId,
    bookId,
    filesVersion,
    status,
    receivedBytes,
    totalBytes,
    pageCount,
    archiveEtag,
    failureReason,
  );

  @override
  String toString() =>
      'VolumeDownload(v$volumeId, ${status.name}, '
      '$receivedBytes/$totalBytes)';
}
