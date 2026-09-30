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
    this.completedAt,
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
    completedAt: row.completedAt,
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

  /// [filesVersion] の世代を端末に確定した時刻（一度も完了していなければ `null`）。
  ///
  /// 自動削除の時計の起点に使う（#13）。読了の記録（進捗の `readAt` / 他端末の
  /// 読了に気づいた時刻）が**前回のダウンロード**や前のセッションのものでも、
  /// 落とし直した直後に消さないため。「更新あり」の取り直しが失敗 / 中断して
  /// 旧世代へ戻るときは、旧世代の確定時刻をそのまま持ち越す。
  ///
  /// `==` には含めない。保存の時刻であって、表示や状態の遷移の判断には使わない
  /// ため（同じ状態の行を、時刻の違いだけで別物として扱わない）。
  final DateTime? completedAt;

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

  /// 端末に「読める実体」（[filesVersion] の ZIP とマニフェスト）があるか。
  ///
  /// 「更新あり」の取り直し中（queued / downloading）も、台帳の行は**旧世代**を
  /// 指したままで ZIP も残っている。取り直しの中断 / 失敗は旧世代の完了行へ戻すが、
  /// それ以前のキューが再起動後に書いた中断 / 失敗の行（paused / failed）も同じ
  /// （`DownloadQueue` は世代にかかわる項目 [filesVersion] / [pageCount] /
  /// [archiveEtag] を**検証が通ってから**しか書かない）。そのため status だけで
  /// 「オフラインで読めるか」を判断すると、手元に完全な ZIP があるのに読めない
  /// 巻ができてしまう（#11 のレビュー指摘）。
  ///
  /// 逆に一度も完了していない行は [filesVersion] / [pageCount] が 0 のままで、
  /// `{0}.zip` という実体は存在しないので、ここで拾ってしまうことは無い。
  ///
  /// 実体が本当にあるか（外部から消されていないか）を見るのは、ファイルを触れる
  /// 側（`ZipDownloadedPageSource` / `CatalogOfflineMetadataGateway`）に任せる。
  bool get hasInstalledArchive =>
      isCompleted || (filesVersion > 0 && pageCount > 0);

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
    DateTime? completedAt,
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
    completedAt: completedAt ?? this.completedAt,
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

/// 端末で読める巻 ID（[VolumeDownload.hasInstalledArchive]）。
Set<int> installedVolumeIds(Map<int, VolumeDownload>? downloads) => {
  for (final download in downloads?.values ?? const <VolumeDownload>[])
    if (download.hasInstalledArchive) download.volumeId,
};

/// 読める巻を 1 つ以上持つタイトル ID。
Set<int> installedBookIds(Map<int, VolumeDownload>? downloads) => {
  for (final download in downloads?.values ?? const <VolumeDownload>[])
    if (download.hasInstalledArchive) download.bookId,
};

/// 台帳に行があるタイトル ID（状態は問わない）。
///
/// オフライン用メタ情報の掃除（`OfflineMetadataGateway.prune`）に使う。
/// 取り直し中の控えまで消さないため、完了しているかは見ない。
Set<int> ledgerBookIds(Map<int, VolumeDownload> downloads) => {
  for (final download in downloads.values) download.bookId,
};
