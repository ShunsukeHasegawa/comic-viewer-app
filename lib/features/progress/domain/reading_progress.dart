import 'package:flutter/foundation.dart' show immutable;

import '../../../core/storage/app_database.dart';
import '../../../domain/models/reading_book.dart';

/// 端末に貯めた読書進捗 1 件（#12）。
///
/// drift の行をそのまま配らないのは [VolumeDownload] と同じ理由
/// （保存の都合と表示の都合を混ぜない）。
@immutable
class ReadingProgress {
  const ReadingProgress({
    required this.volumeId,
    required this.currentPage,
    required this.maxPage,
    required this.readAt,
    this.synced = false,
  });

  factory ReadingProgress.fromRow(ReadingProgressRow row) => ReadingProgress(
    volumeId: row.volumeId,
    currentPage: row.currentPage,
    maxPage: row.maxPage,
    readAt: row.readAt,
    synced: row.synced,
  );

  final int volumeId;

  /// 表示していたページ（1 始まり）。
  final int currentPage;

  /// 巻のページ数。
  final int maxPage;

  /// 端末が読んだと申告する時刻（サーバーの競合解決の基準）。
  final DateTime readAt;

  /// サーバーへ反映済みか。
  final bool synced;

  /// サーバーへ送る必要があるか。
  bool get isPending => !synced;

  /// 進捗率（0〜100）。サーバーの `ReadingBookResource` と同じ切り捨て。
  int get progressPercent =>
      maxPage > 0 ? (currentPage / maxPage * 100).floor() : 0;
}

/// 「続きを読む」一覧へローカルの未送信進捗を重ねる。
///
/// オフラインで読み進めた巻は、サーバーの値のままだと**読む前のページ**を
/// 指してしまう（タップすると戻ってしまう）。送信できていない行だけを
/// 手元の値で上書きする。
///
/// 「続きを読む」そのもの（`/api/v2/user/reading`）は控えていないので、圏外では
/// 前回表示した内容が残っている場合だけ出る（一覧 / 詳細の永続化は #11）。
List<ReadingBook> applyLocalProgress(
  List<ReadingBook> reading,
  Map<int, ReadingProgress> local,
) {
  if (local.isEmpty) return reading;
  return [
    for (final item in reading)
      switch (local[item.volumeId]) {
        final progress? when progress.isPending => item.copyWith(
          currentPage: progress.currentPage,
          maxPage: progress.maxPage,
          progressPercent: progress.progressPercent,
        ),
        _ => item,
      },
  ];
}
