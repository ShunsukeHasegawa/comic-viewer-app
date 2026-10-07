import 'package:comic_laz/features/downloads/application/download_queue.dart';
import 'package:comic_laz/features/downloads/application/downloaded_lookup.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/download_fakes.dart';
import '../../../support/test_scope.dart';

const _installed = VolumeDownload(
  volumeId: 340,
  bookId: 12,
  filesVersion: 1,
  status: VolumeDownloadStatus.completed,
  receivedBytes: 100,
  totalBytes: 100,
);

VolumeDownload _downloading(int receivedBytes) => VolumeDownload(
  volumeId: 341,
  bookId: 12,
  filesVersion: 1,
  status: VolumeDownloadStatus.downloading,
  receivedBytes: receivedBytes,
  totalBytes: 100,
);

void main() {
  test('別の巻の進捗だけが変わっても、読める巻 / タイトルは知らせ直さない', () async {
    // 台帳は進捗のたびに作り直される。ふつうの Set を返すと、watch している
    // タイトル詳細やライブラリの絞り込みが進捗のたびに全部作り直される。
    final queue = StubDownloadQueue(
      initial: {340: _installed, 341: _downloading(10)},
    );
    final container = createContainer(downloadQueue: () => queue);
    addTearDown(container.dispose);
    await container.read(downloadQueueProvider.future);

    var volumeNotices = 0;
    var bookNotices = 0;
    container
      ..listen(downloadedVolumeIdsProvider, (_, _) => volumeNotices++)
      ..listen(downloadedBookIdsProvider, (_, _) => bookNotices++);

    queue.state = AsyncData({340: _installed, 341: _downloading(50)});
    container
      ..read(downloadedVolumeIdsProvider)
      ..read(downloadedBookIdsProvider);
    expect(volumeNotices, 0);
    expect(bookNotices, 0);

    // 読める巻が増えたときは知らせる（圏外で開ける巻が変わる）。
    queue.state = AsyncData({
      340: _installed,
      341: _downloading(100).copyWith(status: VolumeDownloadStatus.completed),
    });
    expect(container.read(downloadedVolumeIdsProvider), {340, 341});
    expect(volumeNotices, 1);
  });
}
