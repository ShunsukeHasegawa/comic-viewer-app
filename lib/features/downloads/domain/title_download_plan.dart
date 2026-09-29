import 'package:flutter/foundation.dart' show immutable;

import '../../../domain/models/book_detail.dart';
import 'volume_download.dart';

/// タイトル単位でまとめてダウンロードする範囲（#10）。
enum TitleDownloadScope {
  all('全巻'),

  /// 読了していない巻（読みかけを含む）。
  unread('未読のみ'),

  /// 巻数の大きい方から N 巻。
  latest('最新の巻');

  const TitleDownloadScope(this.label);

  final String label;
}

/// 「最新 N 巻」で選べる N。
const latestVolumeCounts = [1, 3, 5, 10];

/// まとめてダウンロードするときに実際に積む巻。
@immutable
class TitleDownloadPlan {
  const TitleDownloadPlan({required this.volumes, required this.skipped});

  /// 積む巻（巻数の小さい順 = 取得する順）。
  final List<BookVolume> volumes;

  /// 範囲には入ったが、既にダウンロード済み（最新）か取得待ち・取得中で
  /// 積まない巻の数。
  final int skipped;

  /// 積む巻の合計バイト数（確認ダイアログに出す）。
  int get bytes =>
      volumes.fold(0, (sum, volume) => sum + (volume.archiveBytes ?? 0));

  bool get isEmpty => volumes.isEmpty;
}

/// [volumes] のうち [scope] に入る巻から、積むべき巻を選ぶ。
///
/// - サーバーにアーカイブが無い巻は数えない（押しても 404 になるだけ）
/// - 端末に最新の世代があるもの・既にキューにあるものは積まない。
///   合計容量に入れてしまうと、確認ダイアログの「これから落とす量」が
///   実際より大きく出る
/// - 「更新あり」（端末の世代が古い）・中断中・失敗は積む（続きから / 取り直し）
TitleDownloadPlan planTitleDownload({
  required List<BookVolume> volumes,
  required Map<int, VolumeDownload> downloads,
  required TitleDownloadScope scope,
  int latestCount = 3,
}) {
  final downloadable = volumes.where((v) => v.isDownloadable).toList()
    ..sort((a, b) => a.volume.compareTo(b.volume));

  final inScope = switch (scope) {
    TitleDownloadScope.all => downloadable,
    TitleDownloadScope.unread =>
      downloadable.where((v) => !v.isFinished).toList(),
    TitleDownloadScope.latest =>
      downloadable.length <= latestCount
          ? downloadable
          : downloadable.sublist(downloadable.length - latestCount),
  };

  final targets = <BookVolume>[];
  for (final volume in inScope) {
    final download = downloads[volume.id];
    final alreadyHave =
        download != null &&
        (download.isActive ||
            (download.isCompleted &&
                download.failureReason == null &&
                !download.isOutdated(volume.filesVersion)));
    if (!alreadyHave) targets.add(volume);
  }
  return TitleDownloadPlan(
    volumes: targets,
    skipped: inScope.length - targets.length,
  );
}
