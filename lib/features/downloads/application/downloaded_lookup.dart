import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/volume_download.dart';
import 'download_queue.dart';

part 'downloaded_lookup.g.dart';

/// 端末で読める（検証まで通った）巻 ID。
///
/// 取得中 / 中断中は含めない。オフラインで「開ける巻」を判断する基準なので、
/// 途中のデータを含めると開いてから読めないことに気づく形になってしまう。
@riverpod
Set<int> downloadedVolumeIds(Ref ref) {
  final downloads = ref.watch(downloadQueueProvider).value;
  return completedVolumeIds(downloads);
}

/// ダウンロード済みの巻を 1 つ以上持つタイトル ID。
@riverpod
Set<int> downloadedBookIds(Ref ref) {
  final downloads = ref.watch(downloadQueueProvider).value;
  return completedBookIds(downloads);
}

Set<int> completedVolumeIds(Map<int, VolumeDownload>? downloads) => {
  for (final download in downloads?.values ?? const <VolumeDownload>[])
    if (download.isCompleted) download.volumeId,
};

Set<int> completedBookIds(Map<int, VolumeDownload>? downloads) => {
  for (final download in downloads?.values ?? const <VolumeDownload>[])
    if (download.isCompleted) download.bookId,
};
