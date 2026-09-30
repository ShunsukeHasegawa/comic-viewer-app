import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/features/downloads/domain/download_manager_view.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:flutter_test/flutter_test.dart';

/// 完了済みの巻（世代 [filesVersion] の ZIP が読める）。
VolumeDownload installed(
  int volumeId, {
  int bookId = 12,
  int filesVersion = 1,
  int totalBytes = 100,
  String? failureReason,
}) => VolumeDownload(
  volumeId: volumeId,
  bookId: bookId,
  filesVersion: filesVersion,
  status: VolumeDownloadStatus.completed,
  receivedBytes: totalBytes,
  totalBytes: totalBytes,
  pageCount: 10,
  failureReason: failureReason,
);

/// 一度も完了していない巻（世代 0 = 読める実体が無い）。
VolumeDownload fresh(
  int volumeId,
  VolumeDownloadStatus status, {
  int bookId = 12,
  int receivedBytes = 30,
  int totalBytes = 100,
}) => VolumeDownload(
  volumeId: volumeId,
  bookId: bookId,
  filesVersion: 0,
  status: status,
  receivedBytes: receivedBytes,
  totalBytes: totalBytes,
);

DownloadTitleInfo titleInfo({
  int bookId = 12,
  String title = '進撃の巨人',
  Map<int, (int volume, int? filesVersion)> volumes = const {},
}) => DownloadTitleInfo.fromDetail(
  BookDetail(
    id: bookId,
    title: title,
    volumes: [
      for (final MapEntry(key: id, value: (volume, filesVersion))
          in volumes.entries)
        BookVolume(
          id: id,
          volume: volume,
          filesVersion: filesVersion,
          thumbnail: '/books/thumbnail/$id?m=1',
        ),
    ],
  ),
);

void main() {
  test('取り直し中の巻は「進行中」と「ダウンロード済み」の両方に出す（旧世代の ZIP は読めるので消えたように見せない）', () {
    final refetching = installed(340)
        .copyWith(status: VolumeDownloadStatus.downloading, receivedBytes: 10);

    final view = buildDownloadManagerView(
      ledger: {340: refetching},
      titles: {
        12: titleInfo(volumes: {340: (1, 2)}),
      },
    );

    expect(view.inProgress.single.volumeId, 340);
    expect(view.inProgress.single.isRefetch, isTrue);
    expect(view.downloaded.single.volumes.single.volumeId, 340);
    expect(view.downloadedVolumeCount, 1);
  });

  test('取り直しに失敗した巻は「失敗」に出しつつ「ダウンロード済み」にも残す（読めるものは読めると見せる）', () {
    final view = buildDownloadManagerView(
      ledger: {340: installed(340, failureReason: 'ネットワークに接続できません。')},
      titles: const {},
    );

    expect(view.failed.single.refetchFailed, isTrue);
    expect(view.downloaded.single.volumes.single.volumeId, 340);
    expect(view.inProgress, isEmpty);
  });

  test('初回の取得中・中断・失敗の巻はダウンロード済みの容量に数えない（途中のデータは読めない）', () {
    final view = buildDownloadManagerView(
      ledger: {
        340: installed(340, totalBytes: 500),
        341: fresh(341, VolumeDownloadStatus.downloading),
        342: fresh(342, VolumeDownloadStatus.paused),
        343: fresh(343, VolumeDownloadStatus.failed),
      },
      titles: const {},
    );

    expect(view.downloadedBytes, 500);
    expect(view.downloadedVolumeCount, 1);
    expect(view.inProgress.map((entry) => entry.volumeId), [341, 342]);
    expect(view.failed.map((entry) => entry.volumeId), [343]);
  });

  test('タイトルの容量は読める巻の totalBytes の合計（設定画面の内訳と同じ規則で数字を揃える）', () {
    final view = buildDownloadManagerView(
      ledger: {
        340: installed(340, totalBytes: 100),
        341: installed(341, totalBytes: 250),
        342: fresh(342, VolumeDownloadStatus.queued, receivedBytes: 999),
        500: installed(500, bookId: 20, totalBytes: 7),
      },
      titles: const {},
    );

    final byBook = {for (final group in view.downloaded) group.bookId: group};
    expect(byBook[12]!.bytes, 350);
    expect(byBook[20]!.bytes, 7);
    expect(view.downloadedBytes, 357);
  });

  test('控えが無いタイトルは一覧の名前、どちらも無ければ ID で出す（圏外で空欄の行を作らない）', () {
    final view = buildDownloadManagerView(
      ledger: {340: installed(340), 500: installed(500, bookId: 20)},
      titles: {
        12: DownloadTitleInfo.fromBook(const Book(id: 12, title: '進撃の巨人')),
      },
    );

    final labels = {
      for (final group in view.downloaded) group.bookId: group.titleLabel,
    };
    expect(labels, {12: '進撃の巨人', 20: 'タイトル（ID: 20）'});
    // 一覧の控えには巻数が無い。
    final attack = view.downloaded.singleWhere((group) => group.bookId == 12);
    expect(attack.volumes.single.volumeLabel, '巻（ID: 340）');
  });

  test('空文字のタイトル名も ID の表示に倒す（空欄の見出しを作らない）', () {
    final view = buildDownloadManagerView(
      ledger: {340: installed(340)},
      titles: {12: titleInfo(title: '')},
    );

    expect(view.downloaded.single.titleLabel, 'タイトル（ID: 12）');
  });

  test('サーバーの files_version が分からない巻は「更新あり」にしない（通信できないだけで古い扱いにしない）', () {
    final view = buildDownloadManagerView(
      ledger: {
        340: installed(340, filesVersion: 1),
        341: installed(341, filesVersion: 1),
        342: installed(342, filesVersion: 1),
      },
      titles: {
        12: titleInfo(volumes: {340: (1, 2), 341: (2, null), 342: (3, 1)}),
      },
    );

    final outdated = {
      for (final entry in view.downloaded.single.volumes)
        entry.volumeId: entry.isOutdated,
    };
    expect(outdated, {340: true, 341: false, 342: false});
    expect(view.downloaded.single.outdatedCount, 1);
  });

  test('巻は巻数の昇順、巻数が分からない巻は後ろ（控えの無い巻が先頭に割り込まない）', () {
    final view = buildDownloadManagerView(
      ledger: {
        900: installed(900),
        350: installed(350),
        340: installed(340),
        100: installed(100),
      },
      titles: {
        12: titleInfo(volumes: {350: (1, 1), 340: (2, 1)}),
      },
    );

    expect(view.downloaded.single.volumes.map((entry) => entry.volumeId), [
      350,
      340,
      100,
      900,
    ]);
    expect(view.downloaded.single.volumes.first.volumeLabel, '1 巻');
  });

  test('進行中は取得中 → 待機 → 中断の順（いま動いているものを先に見せる）', () {
    final view = buildDownloadManagerView(
      ledger: {
        1: fresh(1, VolumeDownloadStatus.paused),
        2: fresh(2, VolumeDownloadStatus.queued),
        3: fresh(3, VolumeDownloadStatus.downloading),
        4: fresh(4, VolumeDownloadStatus.queued),
      },
      titles: {
        12: titleInfo(volumes: {2: (5, 1), 4: (3, 1)}),
      },
    );

    expect(view.inProgress.map((entry) => entry.volumeId), [3, 4, 2, 1]);
  });

  test('ダウンロード済みのタイトルは名前順に並べる', () {
    final view = buildDownloadManagerView(
      ledger: {1: installed(1, bookId: 30), 2: installed(2, bookId: 10)},
      titles: {
        30: titleInfo(bookId: 30, title: 'あ'),
        10: titleInfo(bookId: 10, title: 'か'),
      },
    );

    expect(view.downloaded.map((group) => group.titleLabel), ['あ', 'か']);
  });

  test('台帳が空なら空として扱う', () {
    final view = buildDownloadManagerView(ledger: const {}, titles: const {});

    expect(view.isEmpty, isTrue);
    expect(view.downloadedBytes, 0);
  });
}
