import 'dart:typed_data';

import 'package:comic_laz/app.dart';
import 'package:comic_laz/core/cache/comic_image_loader.dart';
import 'package:comic_laz/core/media/media_urls.dart';
import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/network/dio_provider.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/domain/models/read_volume.dart';
import 'package:comic_laz/features/downloads/data/download_store.dart';
import 'package:comic_laz/features/downloads/data/downloaded_page_source.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/library/data/library_repository.dart';
import 'package:comic_laz/features/library/presentation/library_screen.dart';
import 'package:comic_laz/features/library/presentation/widgets/book_tiles.dart';
import 'package:comic_laz/features/offline/application/offline_metadata_gateway.dart';
import 'package:comic_laz/features/offline/data/offline_catalog.dart';
import 'package:comic_laz/features/progress/data/progress_store.dart';
import 'package:comic_laz/features/title/presentation/title_detail_screen.dart';
import 'package:comic_laz/features/title/presentation/widgets/volume_tile.dart';
import 'package:comic_laz/features/viewer/application/viewer_controller.dart';
import 'package:comic_laz/features/viewer/presentation/viewer_screen.dart';
import 'package:comic_laz/features/viewer/presentation/widgets/volume_end_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';
import '../../support/auth_fakes.dart';
import '../../support/cache_fakes.dart';
import '../../support/download_fakes.dart';
import '../../support/offline_fakes.dart';
import '../../support/progress_fakes.dart';
import '../../support/test_scope.dart';

const _bookId = 12;
const _downloadedVolumeId = 340;
const _otherVolumeId = 341;
const _filesVersion = 111;
const _pageCount = 3;

final _downloadedBook = testBook(
  id: _bookId,
  title: '進撃の巨人',
  kana: 'しんげきのきょじん',
  thumbnail: '/books/thumbnail/340?m=7',
  volumeAddedAt: DateTime.utc(2026, 8, 1),
  latestVolume: 2,
);

final _otherBook = testBook(
  id: 99,
  title: '未ダウンロードの本',
  kana: 'みだうんろーど',
  volumeAddedAt: DateTime.utc(2026, 9, 1),
);

const _detail = BookDetail(
  id: _bookId,
  title: '進撃の巨人',
  volumes: [
    BookVolume(
      id: _downloadedVolumeId,
      volume: 1,
      thumbnail: '/books/thumbnail/340?m=7',
      archiveBytes: 1000,
      filesVersion: _filesVersion,
    ),
    BookVolume(
      id: _otherVolumeId,
      volume: 2,
      thumbnail: '/books/thumbnail/341?m=8',
      archiveBytes: 2000,
      filesVersion: 222,
    ),
  ],
);

/// 機内モードのアプリ一式（すべての API が通信エラー）。
///
/// 端末側は「1 巻をダウンロードして詳細まで開いたあと、圏外になった」状態を
/// 実データ（メモリ DB + 一時ディレクトリの ZIP）で用意する。
Future<
  ({
    ProviderContainer container,
    CacheHarness cache,
    DownloadStore downloads,
    Uint8List archive,
    MediaUrls urls,
  })
>
pumpAirplaneModeRaw(WidgetTester tester) async {
  // 詳細と巻一覧が縦に長いので、既定の 800x600 だと遅延生成の行が作られない。
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final offline = createOfflineCatalog();
  final cache = offline.cache;
  final downloads = DownloadStore(
    database: cache.database,
    directories: cache.directories,
    now: cache.clock.now,
  );

  // 端末の状態づくりは実ファイル I/O を伴うので `runAsync` の中で行う
  // （`testWidgets` の擬似時間では、ディスク完了待ちの future が進まない）。
  final archive = zipWithPages(_pageCount);
  await tester.runAsync(() async {
    // ダウンロード済みの 1 巻（ZIP + マニフェスト + 台帳）。
    await downloads.ensureVolumeDirectory(_downloadedVolumeId);
    downloads
        .archiveFile(volumeId: _downloadedVolumeId, filesVersion: _filesVersion)
        .writeAsBytesSync(archive);
    await downloads.writeManifest(
      testManifest(
        id: _downloadedVolumeId,
        bookId: _bookId,
        filesVersion: _filesVersion,
        archiveBytes: archive.length,
        pageCount: _pageCount,
      ),
    );
    await downloads.save(
      const VolumeDownload(
        volumeId: _downloadedVolumeId,
        bookId: _bookId,
        filesVersion: _filesVersion,
        status: VolumeDownloadStatus.completed,
        pageCount: _pageCount,
      ),
    );

    // オンラインのうちに控えた一覧 / 詳細（再起動後は drift から読む）。
    await offline.catalog.writeLibrary(
      LibrarySnapshot(
        books: [_downloadedBook, _otherBook],
        etag: '"v1"',
        fetchedAt: DateTime.utc(2026, 9, 20),
        userStatus: const UserStatus(unreads: [_bookId]),
      ),
    );
    await offline.catalog.writeBookDetail(_detail);
    // オンラインのうちに 1 度ビューアで開いた巻（サーバーの巻情報を控えてある）。
    await offline.catalog.writeVolume(
      const ReadVolume(
        id: _downloadedVolumeId,
        volume: 1,
        files: [0, 1, 2],
        filesVersion: _filesVersion,
        nextVolumeId: _otherVolumeId,
        nextVolumeThumbnail: '/books/thumbnail/341?m=8',
        book: Book(id: _bookId, title: '進撃の巨人'),
      ),
    );
  });

  // すべての API が圏外。
  const offlineError = NetworkException();
  final booksApi = FakeBooksApi(
    error: offlineError,
    userStatusError: offlineError,
    bookDetailError: offlineError,
    readVolumeError: offlineError,
  );

  final container = ProviderContainer(
    overrides: [
      ...testOverrides(
        authStore: FakeAuthStore(token: 'valid', user: testUser),
        authApi: MockAuthApi()..stubCurrentUser(),
        booksApi: booksApi,
        userApi: FakeUserApi(readingError: offlineError),
        taxonomyApi: FakeTaxonomyApi(error: offlineError),
        progressStore: InMemoryProgressStore(),
        // オフライン保持は本物（drift + ダウンロード領域）を通す。
        libraryCache: PersistentLibraryCacheStore(offline.catalog),
        offlineMetadata: CatalogOfflineMetadataGateway(
          catalog: offline.catalog,
          downloads: () async => downloads,
        ),
        // ダウンロード済みの巻はキューにも見せる（「開ける巻」の判定に使う）。
        downloads: const {
          _downloadedVolumeId: VolumeDownload(
            volumeId: _downloadedVolumeId,
            bookId: _bookId,
            filesVersion: _filesVersion,
            status: VolumeDownloadStatus.completed,
          ),
        },
      ),
      // 端末側は本物（drift + ファイル）を使う。
      ...cache.overrides(),
      downloadStoreProvider.overrideWith((ref) async => downloads),
      offlineCatalogProvider.overrideWithValue(offline.catalog),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ComicLazApp()),
  );

  return (
    container: container,
    cache: cache,
    downloads: downloads,
    archive: archive,
    urls: offline.urls,
  );
}

/// 起動が落ち着くまで待ってから返す。
Future<
  ({
    ProviderContainer container,
    CacheHarness cache,
    DownloadStore downloads,
    Uint8List archive,
    MediaUrls urls,
  })
>
pumpAirplaneMode(WidgetTester tester) async {
  final app = await pumpAirplaneModeRaw(tester);
  await tester.pumpAndSettle();
  return app;
}

void main() {
  // Epic #1 の主目的: 機内モードで一覧 → 詳細 → 読了まで到達できること。
  testWidgets('機内モードで一覧 → 詳細 → ビューア → 読了まで到達できる', (tester) async {
    final app = await pumpAirplaneMode(tester);

    // 1. 一覧: 端末の控えから出て、ダウンロード済みだけが並ぶ。
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.textContaining('オフラインです'), findsOneWidget);
    expect(find.byType(BookGridTile), findsOneWidget);
    expect(find.text('進撃の巨人'), findsOneWidget);
    expect(find.text('未ダウンロードの本'), findsNothing);

    // 2. 詳細: 控えた詳細が開く。
    await tester.tap(find.text('進撃の巨人'));
    await tester.pumpAndSettle();
    expect(find.byType(TitleDetailScreen), findsOneWidget);
    expect(find.byType(VolumeTile), findsNWidgets(2));

    // 未ダウンロードの 2 巻は開けない（エラーダイアログではなく無効表示）。
    final tiles = tester.widgetList<VolumeTile>(find.byType(VolumeTile));
    expect(tiles.map((tile) => tile.onOpen != null), [true, false]);

    // 3. ビューア: ダウンロード済みの 1 巻を開く。
    await tester.tap(find.text('1 巻'));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget);

    final viewer = app.container.read(
      viewerControllerProvider(_downloadedVolumeId),
    );
    expect(viewer.value?.pageCount, _pageCount);
    expect(viewer.value?.isStale, isTrue);

    // ページ画像が ZIP から出せること（描画はスタブなので取得口で確かめる）。
    // ZIP の読み出しは実ファイル I/O なので `runAsync` の中で行う。
    final page = await tester.runAsync(() {
      final loader = ComicImageLoader(
        dio: app.container.read(dioProvider),
        store: app.cache.store,
        localPages: ZipDownloadedPageSource(app.downloads),
      );
      return loader.load(
        ComicImageRequest.page(
          app.urls,
          volumeId: _downloadedVolumeId,
          page: 1,
          filesVersion: _filesVersion,
        ),
      );
    });
    expect(page, isNotEmpty, reason: '圏外でもページが出せる');

    // 4. 読了: 最終ページ → 巻末オーバーレイまで進める。
    final notifier = app.container.read(
      viewerControllerProvider(_downloadedVolumeId).notifier,
    );
    notifier.setPage(_pageCount + 1);
    await tester.pumpAndSettle();
    expect(find.byType(VolumeEndOverlay), findsOneWidget);

    // 未ダウンロードの次巻へは進めない（押せない）。
    final overlay = tester.widget<VolumeEndOverlay>(
      find.byType(VolumeEndOverlay),
    );
    expect(overlay.hasNextVolume, isTrue);
    expect(overlay.onNextVolume, isNull);
    expect(find.text('オフラインでは次の巻を読めません'), findsOneWidget);

    // 読了の進捗は端末に残る（復帰後に一括同期する。#12）。
    final progress = await app.container
        .read(progressStoreProvider)
        .find(_downloadedVolumeId);
    expect(progress?.currentPage, _pageCount);
    expect(progress?.synced, isFalse);
  });

  // セーフモードはサーバー側が正なので `is_unsafe` の巻は端末に無い。ただし
  // 前のユーザー / 前の設定で取った一覧・詳細・巻情報が残っていると、圏外で
  // そのまま見えてしまう。ユーザー切り替え / 設定変更では必ず破棄する。
  testWidgets('控えを破棄したら圏外では何も出せない（キャッシュ経由で見えない）', (tester) async {
    final app = await pumpAirplaneMode(tester);
    expect(find.byType(BookGridTile), findsOneWidget);
    final catalog = app.container.read(offlineCatalogProvider);

    // ログアウト / ユーザー切り替えで走る破棄（`AuthController` が通す経路）。
    await tester.runAsync(() async {
      await catalog.clear();

      expect(await catalog.readLibrary(), isNull);
      expect(await catalog.readBookDetail(_bookId), isNull);
      expect(await catalog.readVolume(_downloadedVolumeId), isNull);

      // 一覧は圏外のままでは組み立てられない（前の一覧を出さない）。
      await expectLater(
        app.container.read(libraryRepositoryProvider).loadBooks(),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
