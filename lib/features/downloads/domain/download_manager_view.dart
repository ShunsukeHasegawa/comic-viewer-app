import 'package:flutter/foundation.dart' show immutable;

import '../../../domain/models/book.dart';
import '../../../domain/models/book_detail.dart';
import 'volume_download.dart';

/// 1 タイトル分の表示用メタ情報（端末の控え / 一覧の控え / サーバーから）。
///
/// ダウンロード管理画面は台帳（巻 ID と book ID しか持たない）に名前と巻数を
/// 重ねて見せる。どこから取れたかで持てる情報が違うので、ここで形を揃える。
@immutable
class DownloadTitleInfo {
  const DownloadTitleInfo({
    required this.bookId,
    this.title,
    this.thumbnail,
    this.volumes = const {},
  });

  /// タイトル詳細（控え / サーバー）から作る。巻数・サムネイル・
  /// サーバー側の `files_version` まで分かる。
  factory DownloadTitleInfo.fromDetail(BookDetail detail) {
    final sorted = [...detail.volumes]
      ..sort((a, b) => a.volume.compareTo(b.volume));
    return DownloadTitleInfo(
      bookId: detail.id,
      title: _nonEmpty(detail.title),
      // 詳細にはタイトルのサムネイルが無いので、先頭巻のもので代用する。
      thumbnail: sorted
          .map((volume) => volume.thumbnail)
          .firstWhere((thumbnail) => thumbnail != null, orElse: () => null),
      volumes: {for (final volume in detail.volumes) volume.id: volume},
    );
  }

  /// 一覧の控えから作る。名前とサムネイルしか分からない（初回の取得中で
  /// 詳細の控えがまだ無いタイトル用）。
  factory DownloadTitleInfo.fromBook(Book book) => DownloadTitleInfo(
    bookId: book.id,
    title: _nonEmpty(book.title),
    thumbnail: book.thumbnail,
  );

  final int bookId;

  /// タイトル名。空文字は `null` として扱う（空欄の見出しを作らない）。
  final String? title;

  /// タイトル見出しのサムネイル。
  final String? thumbnail;

  /// 巻 ID → 巻数 / サムネイル / サーバー側の `files_version`。
  final Map<int, BookVolume> volumes;

  static String? _nonEmpty(String value) => value.isEmpty ? null : value;
}

/// 画面の 1 行（巻 1 つ）。
@immutable
class DownloadEntry {
  const DownloadEntry({
    required this.download,
    required this.titleLabel,
    required this.volumeLabel,
    this.volumeNumber,
    this.thumbnail,
    this.isRefetch = false,
    this.isOutdated = false,
    this.refetchFailed = false,
  });

  final VolumeDownload download;
  final String titleLabel;

  /// `3 巻` / `巻（ID: 123）`。
  final String volumeLabel;

  /// 並び替え用の巻数（分からなければ `null`）。
  final int? volumeNumber;

  final String? thumbnail;

  /// 旧世代の ZIP が読める状態での取り直し（「更新あり」の取得中）。
  ///
  /// 取り消しを `remove` にすると読める旧世代まで消えるので、画面は
  /// `pause`（旧世代の completed へ戻す）を使う。
  final bool isRefetch;

  /// サーバーの `files_version` と食い違う。サーバー側が分からなければ `false`。
  final bool isOutdated;

  /// 取り直しに失敗して旧世代へ戻した行（completed + 失敗理由）。
  final bool refetchFailed;

  int get volumeId => download.volumeId;
  int get bookId => download.bookId;
}

/// ダウンロード済みの 1 タイトル（見出し + 巻の行）。
@immutable
class DownloadedTitleGroup {
  const DownloadedTitleGroup({
    required this.bookId,
    required this.titleLabel,
    required this.volumes,
    this.thumbnail,
  });

  final int bookId;
  final String titleLabel;
  final String? thumbnail;

  /// 巻数の昇順。巻数の分からない巻は後ろ（巻 ID 順）。
  final List<DownloadEntry> volumes;

  /// 端末で使っている容量（読める巻の ZIP の大きさ）。
  ///
  /// 「更新あり」の取り直し中は、キューが行の totalBytes を新世代の値で
  /// 上書きする。旧世代とほぼ同じ大きさなので近似として許容する。
  int get bytes => volumes.fold(0, (sum, entry) => sum + _bytesOf(entry));

  int get outdatedCount => volumes.where((entry) => entry.isOutdated).length;
}

/// ダウンロード管理画面の表示内容。
@immutable
class DownloadManagerView {
  const DownloadManagerView({
    required this.inProgress,
    required this.failed,
    required this.downloaded,
  });

  /// 取得中 → 待機中 → 中断の順。同じ状態の中はタイトル名 → 巻数。
  final List<DownloadEntry> inProgress;

  /// 失敗した巻と、取り直しに失敗した巻。
  final List<DownloadEntry> failed;

  /// タイトル名の昇順。
  final List<DownloadedTitleGroup> downloaded;

  /// 読める巻の容量の合計（ストレージ設定の内訳と同じ規則）。
  int get downloadedBytes =>
      downloaded.fold(0, (sum, group) => sum + group.bytes);

  int get downloadedVolumeCount =>
      downloaded.fold(0, (sum, group) => sum + group.volumes.length);

  bool get isEmpty =>
      inProgress.isEmpty && failed.isEmpty && downloaded.isEmpty;
}

/// 台帳（[ledger]）とタイトル情報（[titles]）から画面の内容を組み立てる。
///
/// 1 つの巻が複数の区分に出ることがある（**わざと**）:
/// - 「更新あり」の取り直し中は「進行中」と「ダウンロード済み」の両方。
///   旧世代の ZIP は読めるので、取得中の間に消えたように見せない（#11）。
/// - 取り直しの失敗は「失敗」と「ダウンロード済み」の両方。失敗を黙って
///   「済み」に見せず、読めるものは読めると見せる。
DownloadManagerView buildDownloadManagerView({
  required Map<int, VolumeDownload> ledger,
  required Map<int, DownloadTitleInfo> titles,
}) {
  final entries = [
    for (final download in ledger.values)
      _entryOf(download, titles[download.bookId]),
  ];

  final inProgress = [
    for (final entry in entries)
      if (entry.download.isActive ||
          entry.download.status == VolumeDownloadStatus.paused)
        entry,
  ]..sort(_compareInProgress);

  final failed = [
    for (final entry in entries)
      if (entry.download.status == VolumeDownloadStatus.failed ||
          entry.refetchFailed)
        entry,
  ]..sort(_compareByTitleAndVolume);

  final byBook = <int, List<DownloadEntry>>{};
  for (final entry in entries) {
    // 読める実体があるかで決める（status ではない）。初回の途中の巻は
    // 読めないので容量にも数えない。
    if (!entry.download.hasInstalledArchive) continue;
    byBook.putIfAbsent(entry.bookId, () => []).add(entry);
  }
  final downloaded = [
    for (final MapEntry(key: bookId, value: volumes) in byBook.entries)
      _groupOf(bookId, volumes..sort(_compareByVolume), titles[bookId]),
  ]..sort(_compareGroups);

  return DownloadManagerView(
    inProgress: inProgress,
    failed: failed,
    downloaded: downloaded,
  );
}

/// タイトル名が分からないときの見出し。
///
/// 圏外で控えも一覧も無いタイトルでも、空欄の行を作らない。
String fallbackTitleLabel(int bookId) => 'タイトル（ID: $bookId）';

/// 巻数が分からないときの表示。
String fallbackVolumeLabel(int volumeId) => '巻（ID: $volumeId）';

DownloadEntry _entryOf(VolumeDownload download, DownloadTitleInfo? info) {
  final volume = info?.volumes[download.volumeId];
  return DownloadEntry(
    download: download,
    titleLabel: info?.title ?? fallbackTitleLabel(download.bookId),
    volumeLabel: volume == null
        ? fallbackVolumeLabel(download.volumeId)
        : '${volume.volume} 巻',
    volumeNumber: volume?.volume,
    thumbnail: volume?.thumbnail ?? info?.thumbnail,
    isRefetch: download.isActive && download.hasInstalledArchive,
    // サーバー側の files_version は控えにしか無い。分からなければ
    // 「更新あり」にしない（通信できないだけで古い扱いにしない）。
    isOutdated: download.isOutdated(volume?.filesVersion),
    refetchFailed: download.isCompleted && download.failureReason != null,
  );
}

DownloadedTitleGroup _groupOf(
  int bookId,
  List<DownloadEntry> sortedVolumes,
  DownloadTitleInfo? info,
) => DownloadedTitleGroup(
  bookId: bookId,
  titleLabel: sortedVolumes.first.titleLabel,
  thumbnail: info?.thumbnail ?? sortedVolumes.first.thumbnail,
  volumes: List.unmodifiable(sortedVolumes),
);

int _bytesOf(DownloadEntry entry) =>
    entry.download.hasInstalledArchive ? entry.download.totalBytes : 0;

int _statusRank(VolumeDownloadStatus status) => switch (status) {
  VolumeDownloadStatus.downloading => 0,
  VolumeDownloadStatus.queued => 1,
  _ => 2,
};

int _compareInProgress(DownloadEntry a, DownloadEntry b) {
  // いま動いているものを先に見せる。
  final byStatus = _statusRank(a.download.status)
      .compareTo(_statusRank(b.download.status));
  if (byStatus != 0) return byStatus;
  return _compareByTitleAndVolume(a, b);
}

int _compareByTitleAndVolume(DownloadEntry a, DownloadEntry b) {
  final byTitle = a.titleLabel.compareTo(b.titleLabel);
  if (byTitle != 0) return byTitle;
  final byBook = a.bookId.compareTo(b.bookId);
  if (byBook != 0) return byBook;
  return _compareByVolume(a, b);
}

/// 巻数の昇順。巻数の分からない巻は後ろ（控えの無い巻を先頭に割り込ませない）。
int _compareByVolume(DownloadEntry a, DownloadEntry b) {
  final av = a.volumeNumber;
  final bv = b.volumeNumber;
  if (av != null && bv != null && av != bv) return av.compareTo(bv);
  if (av == null && bv != null) return 1;
  if (av != null && bv == null) return -1;
  return a.volumeId.compareTo(b.volumeId);
}

int _compareGroups(DownloadedTitleGroup a, DownloadedTitleGroup b) {
  final byTitle = a.titleLabel.compareTo(b.titleLabel);
  if (byTitle != 0) return byTitle;
  return a.bookId.compareTo(b.bookId);
}
