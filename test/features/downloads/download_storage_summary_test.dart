import 'package:comic_laz/features/downloads/domain/download_storage_summary.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:flutter_test/flutter_test.dart';

VolumeDownload _download(
  int volumeId,
  VolumeDownloadStatus status, {
  int filesVersion = 0,
  int pageCount = 0,
  int received = 0,
  int total = 0,
}) => VolumeDownload(
  volumeId: volumeId,
  bookId: 1,
  filesVersion: filesVersion,
  status: status,
  pageCount: pageCount,
  receivedBytes: received,
  totalBytes: total,
);

void main() {
  test('読める巻だけを「ダウンロード済み」に数える（取り直し中の旧世代を含む）', () {
    final summary = summarizeDownloads({
      1: _download(
        1,
        VolumeDownloadStatus.completed,
        filesVersion: 5,
        pageCount: 10,
        received: 100,
        total: 100,
      ),
      // 「更新あり」の取り直し中。旧世代の ZIP は端末に残っていて読める。
      2: _download(
        2,
        VolumeDownloadStatus.downloading,
        filesVersion: 5,
        pageCount: 10,
        received: 30,
        total: 200,
      ),
    });

    expect(summary.installedVolumes, 2);
    expect(summary.installedBytes, 300);
    expect(summary.partialBytes, 0, reason: '読める巻の受信済みバイトは途中に二重計上しない');
  });

  test('初回の途中の巻は受信済みバイトを「途中」として別に数える', () {
    final summary = summarizeDownloads({
      1: _download(
        1,
        VolumeDownloadStatus.downloading,
        received: 40,
        total: 100,
      ),
      2: _download(2, VolumeDownloadStatus.paused, received: 10, total: 100),
      3: _download(3, VolumeDownloadStatus.failed, received: 5, total: 100),
      4: _download(4, VolumeDownloadStatus.queued),
    });

    expect(summary.installedVolumes, 0);
    expect(summary.installedBytes, 0, reason: '途中のデータは読めないので済みに数えない');
    expect(summary.partialBytes, 55);
    expect(summary.totalBytes, 55);
  });

  test('台帳が空なら 0', () {
    expect(summarizeDownloads({}), const DownloadStorageSummary());
  });
}
