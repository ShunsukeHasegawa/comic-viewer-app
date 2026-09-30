import 'dart:async';
import 'dart:io';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/features/downloads/application/download_manager_controller.dart';
import 'package:comic_laz/features/downloads/application/download_queue.dart';
import 'package:comic_laz/features/downloads/domain/download_manager_view.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/library/data/library_repository.dart';
import 'package:comic_laz/features/offline/application/offline_detail_warmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';
import '../../support/download_fakes.dart';
import '../../support/offline_fakes.dart';
import '../../support/test_scope.dart';

/// 控えを読んだ回数を数える（読み直しの有無を確かめる）。
class CountingOfflineGateway extends FakeOfflineMetadataGateway {
  CountingOfflineGateway({super.details, this.failingBooks = const {}});

  /// 読み込みで失敗させるタイトル。
  final Set<int> failingBooks;

  final reads = <int>[];

  @override
  Future<BookDetail?> readBookDetail(int bookId) async {
    reads.add(bookId);
    if (failingBooks.contains(bookId)) {
      throw const FileSystemException('db locked');
    }
    return super.readBookDetail(bookId);
  }
}

VolumeDownload installed(
  int volumeId, {
  int bookId = 12,
  int filesVersion = 1,
}) => VolumeDownload(
  volumeId: volumeId,
  bookId: bookId,
  filesVersion: filesVersion,
  status: VolumeDownloadStatus.completed,
  receivedBytes: 100,
  totalBytes: 100,
  pageCount: 10,
);

BookDetail detail({
  int id = 12,
  String title = '進撃の巨人',
  int volumeId = 340,
  int? filesVersion = 1,
}) => BookDetail(
  id: id,
  title: title,
  volumes: [BookVolume(id: volumeId, volume: 1, filesVersion: filesVersion)],
);

({ProviderContainer container, StubDownloadQueue queue}) setUpContainer({
  required Map<int, VolumeDownload> ledger,
  required CountingOfflineGateway gateway,
  FakeBooksApi? booksApi,
  LibraryCacheStore? libraryCache,
}) {
  final queue = StubDownloadQueue(initial: ledger);
  final container = createContainer(
    downloadQueue: () => queue,
    offlineMetadata: gateway,
    booksApi: booksApi,
    libraryCache: libraryCache,
  );
  addTearDown(container.dispose);
  // autoDispose なので、画面の代わりに購読しておく。
  container.listen(downloadManagerTitlesProvider, (_, _) {});
  return (container: container, queue: queue);
}

Future<DownloadTitleCatalog> loadTitles(ProviderContainer container) async {
  await container.read(downloadQueueProvider.future);
  await pumpEventQueue();
  return container.read(downloadManagerTitlesProvider.future);
}

void main() {
  test('開いただけではサーバーに問い合わせない（自宅サーバーの HDD を起こさない・圏外でも即表示）', () async {
    final api = FakeBooksApi(bookDetail: detail());
    final gateway = CountingOfflineGateway(details: {12: detail()});
    final app = setUpContainer(
      ledger: {340: installed(340)},
      gateway: gateway,
      booksApi: api,
    );

    final catalog = await loadTitles(app.container);

    expect(catalog.titles[12]?.title, '進撃の巨人');
    expect(api.fetchBookDetailCalls, isEmpty);
  });

  test('進捗が届くたびに控えを読み直さない（タイトル集合が変わったときだけ作り直す）', () async {
    final gateway = CountingOfflineGateway(
      details: {
        12: detail(),
        20: detail(id: 20, title: '別のタイトル'),
      },
    );
    final app = setUpContainer(
      ledger: {
        340: installed(340),
        341: const VolumeDownload(
          volumeId: 341,
          bookId: 12,
          filesVersion: 0,
          status: VolumeDownloadStatus.downloading,
          receivedBytes: 10,
          totalBytes: 100,
        ),
      },
      gateway: gateway,
    );
    await loadTitles(app.container);
    expect(gateway.reads, [12]);

    // 同じタイトルの進捗だけが進む。
    for (final received in [20, 40, 60]) {
      app.queue.emit(
        VolumeDownload(
          volumeId: 341,
          bookId: 12,
          filesVersion: 0,
          status: VolumeDownloadStatus.downloading,
          receivedBytes: received,
          totalBytes: 100,
        ),
      );
      await pumpEventQueue();
    }
    expect(gateway.reads, [12]);

    // 新しいタイトルが台帳に入ったら読み直す。
    app.queue.emit(installed(500, bookId: 20));
    await pumpEventQueue();
    final catalog = await app.container.read(
      downloadManagerTitlesProvider.future,
    );
    expect(catalog.titles[20]?.title, '別のタイトル');
    expect(gateway.reads, [12, 12, 20]);
  });

  test('控えが無いタイトルは一覧の控えで名前を補う（初回の取得中は詳細の控えが無い）', () async {
    final cache = InMemoryLibraryCacheStore();
    await cache.write(
      LibrarySnapshot(
        books: const [Book(id: 20, title: '一覧の名前')],
        fetchedAt: DateTime(2026, 9, 30),
      ),
    );
    final app = setUpContainer(
      ledger: {
        500: const VolumeDownload(
          volumeId: 500,
          bookId: 20,
          filesVersion: 0,
          status: VolumeDownloadStatus.queued,
        ),
      },
      gateway: CountingOfflineGateway(),
      libraryCache: cache,
    );

    final catalog = await loadTitles(app.container);

    expect(catalog.titles[20]?.title, '一覧の名前');
    expect(catalog.hasFailure, isFalse);
  });

  test('1 タイトルの控えが読めなくても他のタイトルは出し、失敗を持つ（黙って空欄にしない）', () async {
    final app = setUpContainer(
      ledger: {340: installed(340), 500: installed(500, bookId: 20)},
      gateway: CountingOfflineGateway(
        details: {12: detail()},
        failingBooks: {20},
      ),
    );

    final catalog = await loadTitles(app.container);

    expect(catalog.titles[12]?.title, '進撃の巨人');
    expect(catalog.failedBookIds, {20});
    expect(catalog.error, isA<FileSystemException>());
  });

  test('「更新を確認」で詳細を取り直して控えを更新し、更新ありが分かるようになる', () async {
    // 控えは世代 1 のまま。サーバーでは世代 2 に更新されている。
    final api = FakeBooksApi(bookDetail: detail(filesVersion: 2));
    final gateway = CountingOfflineGateway(details: {12: detail()});
    final app = setUpContainer(
      ledger: {340: installed(340)},
      gateway: gateway,
      booksApi: api,
    );
    final before = await loadTitles(app.container);
    expect(
      buildDownloadManagerView(
        ledger: {340: installed(340)},
        titles: before.titles,
      ).downloaded.single.outdatedCount,
      0,
    );

    final error = await app.container
        .read(downloadManagerTitlesProvider.notifier)
        .refreshFromServer();

    expect(error, isNull);
    expect(api.fetchBookDetailCalls, [12]);
    expect(gateway.savedDetails, [12], reason: '圏外で開いたときも更新ありが分かるように');
    final after = app.container.read(downloadManagerTitlesProvider).value!;
    expect(
      buildDownloadManagerView(
        ledger: {340: installed(340)},
        titles: after.titles,
      ).downloaded.single.outdatedCount,
      1,
    );
  });

  test('「更新を確認」で取った詳細は、作り直しの後も使う（控えを持てないタイトルの分）', () async {
    final api = FakeBooksApi(bookDetail: detail(filesVersion: 2));
    // 保存しても控えに残らない（初回の取得中のタイトルはゲートで弾かれる）。
    final gateway = CountingOfflineGateway();
    final app = setUpContainer(
      ledger: {340: installed(340)},
      gateway: gateway,
      booksApi: api,
    );
    await loadTitles(app.container);
    await app.container
        .read(downloadManagerTitlesProvider.notifier)
        .refreshFromServer();

    // タイトル集合が変わって作り直しても、取った詳細は消えない。
    app.queue.emit(installed(500, bookId: 20));
    await pumpEventQueue();
    final catalog = await app.container.read(
      downloadManagerTitlesProvider.future,
    );

    expect(catalog.titles[12]?.volumes[340]?.filesVersion, 2);
  });

  test('「更新を確認」が失敗したらエラーを返し、表示中の名前は残す（SnackBar で知らせるため）', () async {
    final api = FakeBooksApi(bookDetailError: const NetworkException());
    final app = setUpContainer(
      ledger: {340: installed(340)},
      gateway: CountingOfflineGateway(details: {12: detail()}),
      booksApi: api,
    );
    await loadTitles(app.container);

    final error = await app.container
        .read(downloadManagerTitlesProvider.notifier)
        .refreshFromServer();

    expect(error, isA<NetworkException>());
    final catalog = app.container.read(downloadManagerTitlesProvider).value!;
    expect(catalog.titles[12]?.title, '進撃の巨人');
  });

  test('一部のタイトルだけ失敗しても取れた分は反映する', () async {
    final api = FakeBooksApi(
      bookDetails: {12: detail(title: '新しい名前', filesVersion: 2)},
    );
    final app = setUpContainer(
      ledger: {340: installed(340), 500: installed(500, bookId: 20)},
      gateway: CountingOfflineGateway(
        details: {
          12: detail(),
          20: detail(id: 20, title: '別のタイトル'),
        },
      ),
      booksApi: api,
    );
    await loadTitles(app.container);

    final error = await app.container
        .read(downloadManagerTitlesProvider.notifier)
        .refreshFromServer();

    expect(error, isA<NotFoundException>());
    expect(api.fetchBookDetailCalls, [12, 20]);
    final catalog = app.container.read(downloadManagerTitlesProvider).value!;
    expect(catalog.titles[12]?.title, '新しい名前');
    expect(catalog.titles[20]?.title, '別のタイトル');
  });

  test('初めて落としたタイトルは、最初の巻が完了して控えが書かれたら、開いたままでも巻数を出す', () async {
    // 初回の取得中は詳細の控えが無い（ゲートで弾かれる）ので、一覧の控えの
    // 名前だけで出ている。完了後の控えでタイトル集合は変わらない。
    final gateway = SavingOfflineGateway();
    final app = setUpContainer(
      ledger: {
        340: const VolumeDownload(
          volumeId: 340,
          bookId: 12,
          filesVersion: 0,
          status: VolumeDownloadStatus.downloading,
        ),
      },
      gateway: gateway,
      booksApi: FakeBooksApi(bookDetail: detail()),
    );
    final before = await loadTitles(app.container);
    expect(before.titles[12]?.volumes ?? const {}, isEmpty);

    // キューの完了処理と同じ順: 台帳を完了にしてから詳細を控える。
    app.queue.emit(installed(340));
    await pumpEventQueue();
    await app.container.read(offlineDetailWarmerProvider)(12);
    await pumpEventQueue();

    final after = await app.container.read(
      downloadManagerTitlesProvider.future,
    );
    expect(after.titles[12]?.volumes[340]?.volume, 1, reason: 'ID ではなく巻数で出す');
  });

  test('「更新を確認」を重ねて押しても、サーバーへの問い合わせは 1 回だけ', () async {
    final gate = Completer<void>();
    final api = FakeBooksApi(bookDetail: detail(filesVersion: 2))
      ..onFetchBookDetail = (_) => gate.future;
    final app = setUpContainer(
      ledger: {340: installed(340)},
      gateway: CountingOfflineGateway(details: {12: detail()}),
      booksApi: api,
    );
    await loadTitles(app.container);
    final notifier = app.container.read(downloadManagerTitlesProvider.notifier);

    final first = notifier.refreshFromServer();
    await pumpEventQueue();
    final second = notifier.refreshFromServer();
    gate.complete();

    expect(await first, isNull);
    expect(await second, isNull);
    expect(api.fetchBookDetailCalls, [12], reason: '自宅サーバーの HDD を二重に起こさない');

    // 終わった後の操作はもう一度問い合わせる。
    await notifier.refreshFromServer();
    expect(api.fetchBookDetailCalls, [12, 12]);
  });

  test('控えを読んでいる最中に「更新を確認」が終わっても、読み終わりで「更新あり」を消さない', () async {
    final gateway = GatedOfflineGateway(details: {12: detail()});
    final app = setUpContainer(
      ledger: {340: installed(340)},
      gateway: gateway,
      booksApi: FakeBooksApi(bookDetail: detail(filesVersion: 2)),
    );
    await app.container.read(downloadQueueProvider.future);
    await pumpEventQueue();
    expect(gateway.waiting, isTrue, reason: '最初の build が控えを読んでいる');

    final refresh = app.container
        .read(downloadManagerTitlesProvider.notifier)
        .refreshFromServer();
    await pumpEventQueue();
    gateway.gate.complete();
    expect(await refresh, isNull);
    await pumpEventQueue();

    final catalog = app.container.read(downloadManagerTitlesProvider).value!;
    expect(
      buildDownloadManagerView(
        ledger: {340: installed(340)},
        titles: catalog.titles,
      ).downloaded.single.outdatedCount,
      1,
    );
  });
}

/// 保存した詳細を控えとして読み戻せる（完了後に控えができる流れの再現）。
class SavingOfflineGateway extends CountingOfflineGateway {
  @override
  Future<void> saveBookDetail(BookDetail detail) async {
    await super.saveBookDetail(detail);
    details[detail.id] = detail;
  }
}

/// 控えの読み込みを止めておける（build の最中の競合の再現）。
class GatedOfflineGateway extends CountingOfflineGateway {
  GatedOfflineGateway({super.details});

  final gate = Completer<void>();
  bool waiting = false;

  @override
  Future<BookDetail?> readBookDetail(int bookId) async {
    waiting = true;
    await gate.future;
    return super.readBookDetail(bookId);
  }
}
