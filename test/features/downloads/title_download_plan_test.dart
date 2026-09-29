import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/features/downloads/domain/title_download_plan.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:flutter_test/flutter_test.dart';

BookVolume volume(int number, {bool finished = false, int? filesVersion = 1}) =>
    BookVolume(
      id: 100 + number,
      volume: number,
      archiveBytes: number * 1000,
      filesVersion: filesVersion,
      userStatus: finished
          ? const VolumeUserStatus(
              currentPage: 10,
              maxPage: 10,
              isFinished: true,
            )
          : null,
    );

VolumeDownload download(
  int number,
  VolumeDownloadStatus status, {
  int filesVersion = 1,
  String? failureReason,
}) => VolumeDownload(
  volumeId: 100 + number,
  bookId: 1,
  filesVersion: filesVersion,
  status: status,
  failureReason: failureReason,
);

List<int> numbersOf(TitleDownloadPlan plan) =>
    plan.volumes.map((v) => v.volume).toList();

void main() {
  // サーバーの並びに依存しない（巻数の小さい順 = 読む順に落とす）。
  final volumes = [volume(3), volume(1, finished: true), volume(2), volume(4)];

  test('全巻は巻数の小さい順に並べ、合計容量を数える', () {
    final plan = planTitleDownload(
      volumes: volumes,
      downloads: const {},
      scope: TitleDownloadScope.all,
    );

    expect(numbersOf(plan), [1, 2, 3, 4]);
    expect(plan.bytes, 10000);
  });

  test('未読のみは読了した巻を除く（読みかけは含む）', () {
    final plan = planTitleDownload(
      volumes: volumes,
      downloads: const {},
      scope: TitleDownloadScope.unread,
    );

    expect(numbersOf(plan), [2, 3, 4]);
  });

  test('最新 N 巻は巻数の大きい方から N 巻', () {
    final plan = planTitleDownload(
      volumes: volumes,
      downloads: const {},
      scope: TitleDownloadScope.latest,
      latestCount: 3,
    );

    expect(numbersOf(plan), [2, 3, 4]);
  });

  test('アーカイブが無い巻は数えない（押しても 404 になるだけ）', () {
    final plan = planTitleDownload(
      volumes: [volume(1), volume(2, filesVersion: null)],
      downloads: const {},
      scope: TitleDownloadScope.latest,
      latestCount: 1,
    );

    expect(numbersOf(plan), [1], reason: '「最新 1 巻」がダウンロードできない巻に当たって空振りしない');
  });

  test('最新の世代が手元にある巻・キューにある巻は積まず、容量にも入れない', () {
    final plan = planTitleDownload(
      volumes: volumes,
      downloads: {
        101: download(1, VolumeDownloadStatus.completed),
        102: download(2, VolumeDownloadStatus.queued),
        103: download(3, VolumeDownloadStatus.downloading),
      },
      scope: TitleDownloadScope.all,
    );

    expect(numbersOf(plan), [4]);
    expect(plan.bytes, 4000, reason: '確認ダイアログの容量が実際より大きく出ない');
    expect(plan.skipped, 3);
  });

  test('「更新あり」・中断中・失敗・取り直しに失敗した巻は積む', () {
    final plan = planTitleDownload(
      volumes: volumes,
      downloads: {
        101: download(1, VolumeDownloadStatus.completed, filesVersion: 0),
        102: download(2, VolumeDownloadStatus.paused),
        103: download(3, VolumeDownloadStatus.failed),
        104: download(
          4,
          VolumeDownloadStatus.completed,
          failureReason: 'ネットワークに接続できませんでした。',
        ),
      },
      scope: TitleDownloadScope.all,
    );

    expect(numbersOf(plan), [1, 2, 3, 4]);
    expect(plan.skipped, 0);
  });
}
