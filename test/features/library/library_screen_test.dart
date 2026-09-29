import 'package:comic_laz/core/device/connectivity_monitor.dart';
import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/widgets/error_view.dart';
import 'package:comic_laz/core/widgets/thumbnail_image.dart';
import 'package:comic_laz/data/api/conditional_response.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/reading_book.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/library/application/library_controller.dart';
import 'package:comic_laz/features/library/data/library_repository.dart';
import 'package:comic_laz/features/library/presentation/library_screen.dart';
import 'package:comic_laz/features/library/presentation/widgets/book_tiles.dart';
import 'package:comic_laz/features/library/presentation/widgets/continue_reading_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';
import '../../support/download_fakes.dart';
import '../../support/offline_fakes.dart';
import '../../support/progress_fakes.dart';
import '../../support/test_scope.dart';

final sampleBooks = [
  testBook(
    id: 1,
    title: '進撃の巨人',
    kana: 'しんげきのきょじん',
    author: ['諫山創'],
    volumeAddedAt: DateTime.utc(2026, 8, 1),
    latestVolume: 34,
    isComplete: true,
    categories: [1],
  ),
  testBook(
    id: 2,
    title: 'ONE PIECE',
    kana: 'わんぴーす',
    author: ['尾田栄一郎'],
    volumeAddedAt: DateTime.utc(2026, 9, 1),
    latestVolume: 108,
    categories: [2],
  ),
];

/// 1 回目だけ圏外になる [BooksApi]（復帰の合図で取り直せることを見る）。
class _OfflineOnceBooksApi extends FakeBooksApi {
  _OfflineOnceBooksApi() : super(books: sampleBooks, etag: '"v1"');

  @override
  Future<ConditionalResponse<List<Book>>> fetchBooks({
    String? ifNoneMatch,
  }) async {
    if (fetchBooksCount == 0) {
      fetchBooksCount++;
      ifNoneMatchCalls.add(ifNoneMatch);
      throw const NetworkException();
    }
    return super.fetchBooks(ifNoneMatch: ifNoneMatch);
  }
}

Future<ProviderContainer> pumpLibrary(
  WidgetTester tester, {
  FakeBooksApi? booksApi,
  FakeUserApi? userApi,
  FakeTaxonomyApi? taxonomyApi,
  Map<int, VolumeDownload>? downloads,
  FakeOfflineMetadataGateway? offline,
  ConnectivityMonitor? connectivityMonitor,
  LibraryCacheStore? libraryCache,
}) async {
  final container = createContainer(
    booksApi: booksApi ?? FakeBooksApi(books: sampleBooks),
    userApi: userApi ?? FakeUserApi(),
    taxonomyApi: taxonomyApi ?? FakeTaxonomyApi(),
    downloads: downloads,
    offlineMetadata: offline,
    connectivityMonitor: connectivityMonitor,
    libraryCache: libraryCache,
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LibraryScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('一覧をグリッドで表示する', (tester) async {
    await pumpLibrary(tester);

    expect(find.byType(BookGridTile), findsNWidgets(2));
    expect(find.text('進撃の巨人'), findsOneWidget);
    expect(find.text('2 件'), findsOneWidget);
  });

  testWidgets('表紙の大きさはタイトルの行数に左右されない', (tester) async {
    // 表紙を残りの高さに合わせていると、タイトルが 1 行の本と 2 行の本で
    // 表紙の大きさが変わる（Web 版は枠を固定しているので揃っている）。
    await pumpLibrary(
      tester,
      booksApi: FakeBooksApi(
        books: [
          testBook(id: 1, title: '短い', kana: 'みじかい', latestVolume: 1),
          testBook(
            id: 2,
            title: '折り返して二行になるとても長いタイトルの作品',
            kana: 'おりかえして',
            latestVolume: 1,
          ),
        ],
      ),
    );

    final covers = find.descendant(
      of: find.byType(BookGridTile),
      matching: find.byType(ThumbnailImage),
    );
    expect(covers, findsNWidgets(2));
    final short = tester.getSize(covers.at(0));
    final long = tester.getSize(covers.at(1));
    expect(long, short);
    // Web 版（`aspect-[2/3]`）と同じ縦横比で切り抜く。
    expect(short.width / short.height, closeTo(bookCoverAspectRatio, 0.01));
  });

  testWidgets('グリッドとリストを切り替えられる', (tester) async {
    await pumpLibrary(tester);

    await tester.tap(find.byTooltip('リスト表示'));
    await tester.pumpAndSettle();

    expect(find.byType(BookListTile), findsNWidgets(2));
    expect(find.byType(BookGridTile), findsNothing);
  });

  testWidgets('検索でタイトル・かな・著者を引ける', (tester) async {
    await pumpLibrary(tester);

    await tester.enterText(find.byType(TextField), 'きょじん');
    await tester.pumpAndSettle();

    expect(find.text('進撃の巨人'), findsOneWidget);
    expect(find.text('ONE PIECE'), findsNothing);
    expect(find.text('1 件'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '尾田');
    await tester.pumpAndSettle();

    expect(find.text('ONE PIECE'), findsOneWidget);
  });

  testWidgets('検索をクリアできる', (tester) async {
    await pumpLibrary(tester);

    await tester.enterText(find.byType(TextField), 'きょじん');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('検索をクリア'));
    await tester.pumpAndSettle();

    expect(find.byType(BookGridTile), findsNWidgets(2));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('一致しない検索では空表示', (tester) async {
    await pumpLibrary(tester);

    await tester.enterText(find.byType(TextField), 'そんな作品はない');
    await tester.pumpAndSettle();

    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.textContaining('条件に一致する書籍がありません'), findsOneWidget);
  });

  testWidgets('完結チップで絞り込み、解除できる', (tester) async {
    await pumpLibrary(tester);

    await tester.tap(find.widgetWithText(FilterChip, '完結'));
    await tester.pumpAndSettle();
    expect(find.byType(BookGridTile), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, '解除'));
    await tester.pumpAndSettle();
    expect(find.byType(BookGridTile), findsNWidgets(2));
  });

  testWidgets('未読 / お気に入りチップはユーザー状態で絞り込む', (tester) async {
    await pumpLibrary(
      tester,
      booksApi: FakeBooksApi(
        books: sampleBooks,
        userStatus: const UserStatus(unreads: [2], favorites: [1]),
      ),
    );

    await tester.tap(find.widgetWithText(FilterChip, '未読'));
    await tester.pumpAndSettle();
    expect(find.text('ONE PIECE'), findsOneWidget);
    expect(find.text('進撃の巨人'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, '未読'));
    await tester.tap(find.widgetWithText(FilterChip, 'お気に入り'));
    await tester.pumpAndSettle();
    expect(find.text('進撃の巨人'), findsOneWidget);
    expect(find.text('ONE PIECE'), findsNothing);
  });

  testWidgets('カテゴリチップで絞り込む', (tester) async {
    await pumpLibrary(
      tester,
      taxonomyApi: FakeTaxonomyApi(
        categories: const [
          Taxonomy(id: 1, name: '少年'),
          Taxonomy(id: 2, name: '青年'),
        ],
      ),
    );

    await tester.tap(find.widgetWithText(FilterChip, '少年'));
    await tester.pumpAndSettle();

    expect(find.text('進撃の巨人'), findsOneWidget);
    expect(find.text('ONE PIECE'), findsNothing);
  });

  testWidgets('並び替えを更新日から五十音へ変えられる', (tester) async {
    await pumpLibrary(tester);

    // 既定（更新日）では新しい ONE PIECE が先頭
    expect(
      tester.widget<BookGridTile>(find.byType(BookGridTile).first).book.title,
      'ONE PIECE',
    );

    await tester.tap(find.byTooltip('並び替え'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('五十音').last);
    await tester.pumpAndSettle();

    expect(
      tester.widget<BookGridTile>(find.byType(BookGridTile).first).book.title,
      '進撃の巨人',
      reason: 'しんげきのきょじん < わんぴーす',
    );
  });

  testWidgets('続きを読むカルーセルを表示し、検索中は隠す', (tester) async {
    await pumpLibrary(
      tester,
      userApi: FakeUserApi(
        reading: const [
          ReadingBook(
            bookId: 1,
            volumeId: 340,
            title: '進撃の巨人',
            volumeNumber: 3,
            currentPage: 10,
            maxPage: 190,
            progressPercent: 5,
          ),
        ],
      ),
    );

    expect(find.byType(ContinueReadingCarousel), findsOneWidget);
    expect(find.text('続きを読む'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '巨人');
    await tester.pumpAndSettle();

    expect(find.text('続きを読む'), findsNothing);
  });

  group('オフライン（#11）', () {
    /// 1 冊だけダウンロード済み（book 1）にして圏外にする。
    Future<ProviderContainer> goOffline(WidgetTester tester) async {
      final api = FakeBooksApi(books: sampleBooks, etag: '"v1"');
      final container = await pumpLibrary(
        tester,
        booksApi: api,
        downloads: {
          340: const VolumeDownload(
            volumeId: 340,
            bookId: 1,
            filesVersion: 1,
            status: VolumeDownloadStatus.completed,
          ),
        },
      );

      api.error = const NetworkException();
      await container.read(libraryControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('バナーを出し、既定でダウンロード済みのみ表示する', (tester) async {
      await goOffline(tester);

      expect(find.textContaining('オフラインです'), findsOneWidget);
      expect(
        find.byType(BookGridTile),
        findsOneWidget,
        reason: '読めないタイトルを並べても開けないだけ',
      );
      expect(find.text('進撃の巨人'), findsOneWidget);
      expect(find.text('1 件'), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'ダウンロード済み'))
            .selected,
        isTrue,
      );
    });

    testWidgets('トグルを切れば圏外でも全部見られる（明示操作は尊重する）', (tester) async {
      await goOffline(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'ダウンロード済み'));
      await tester.pumpAndSettle();

      expect(find.byType(BookGridTile), findsNWidgets(2));
    });

    testWidgets('ダウンロードが 1 つも無ければ理由と逃げ道を出す', (tester) async {
      final api = FakeBooksApi(books: sampleBooks, etag: '"v1"');
      final container = await pumpLibrary(tester, booksApi: api);
      api.error = const NetworkException();
      await container.read(libraryControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();

      expect(find.textContaining('ダウンロード済みのタイトルがありません'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'すべて表示'));
      await tester.pumpAndSettle();

      expect(find.byType(BookGridTile), findsNWidgets(2));
    });

    // 台帳（path_provider + ディレクトリ作成）は一覧（drift の控え）より遅れる。
    // その間の空集合を「ダウンロード済みが 0 件」と言い切ると、ここで「すべて表示」を
    // 押されて絞り込み解除が明示状態として残り、読み終えても戻らない（#11 の
    // レビュー指摘）。pumpAndSettle は進行表示で止まらないので pump で進める。
    testWidgets('台帳を読み終えるまでは「ありません」と言い切らない', (tester) async {
      final queue = LoadingDownloadQueue();
      final cache = InMemoryLibraryCacheStore();
      await cache.write(
        LibrarySnapshot(
          books: sampleBooks,
          etag: '"v1"',
          fetchedAt: DateTime.utc(2026, 9, 20),
        ),
      );
      final container = createContainer(
        booksApi: FakeBooksApi(error: const NetworkException()),
        taxonomyApi: FakeTaxonomyApi(error: const NetworkException()),
        libraryCache: cache,
        downloadQueue: () => queue,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LibraryScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('オフラインです'), findsOneWidget);
      expect(find.textContaining('ダウンロード済みのタイトルがありません'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'すべて表示'), findsNothing);

      // 台帳を読み終えて、初めて理由と逃げ道を出す。
      queue.finish();
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('ダウンロード済みのタイトルがありません'), findsOneWidget);
    });

    testWidgets('ネットワーク復帰で自動的に最新化する', (tester) async {
      final monitor = FakeConnectivityMonitor();
      final api = FakeBooksApi(books: sampleBooks, etag: '"v1"');
      final container = await pumpLibrary(
        tester,
        booksApi: api,
        connectivityMonitor: monitor,
      );
      api.error = const NetworkException();
      await container.read(libraryControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(find.textContaining('オフラインです'), findsOneWidget);

      // 復帰: 新しい一覧が取れる
      api
        ..error = null
        ..books = [...sampleBooks, testBook(id: 3, title: '新しい本')];
      monitor.restore();
      await tester.pumpAndSettle();

      expect(find.textContaining('オフラインです'), findsNothing);
      expect(find.byType(BookGridTile), findsNWidgets(3));
      expect(
        api.ifNoneMatchCalls.last,
        '"v1"',
        reason: '復帰時は ETag で確認する（変わっていなければ 304 で済む）',
      );
    });

    // 本物の監視（connectivity_plus）は購読した瞬間に現在の接続状態を 1 件流す。
    // 初回ロードの最中に 2 本目を走らせると、/api/books を ETag 無しで二重に
    // 叩いてしまい（どちらもキャッシュ書き込み前に読むので送れない）、後から
    // 終わった方が古い結果で上書きしかねない（#11 のレビュー指摘）。
    testWidgets('一覧を開いた瞬間の復帰通知で二重に取りに行かない', (tester) async {
      final api = FakeBooksApi(books: sampleBooks, etag: '"v1"');
      final offline = FakeOfflineMetadataGateway();

      await pumpLibrary(
        tester,
        booksApi: api,
        offline: offline,
        connectivityMonitor: FakeConnectivityMonitor(emitsOnListen: true),
      );

      expect(api.fetchBooksCount, 1, reason: '起動のたびに 2 回叩かない');
      expect(offline.pruneCount, 1, reason: '掃除も同時に 2 本走らせない');
      expect(find.textContaining('オフラインです'), findsNothing);
      expect(find.byType(BookGridTile), findsNWidgets(2));
    });

    // 復帰の合図より前に始まったロードが圏外で終わった場合は、そのあと改めて
    // 取り直しに行く（「進行中があれば何もしない」では復帰を取りこぼす）。
    // ウィジェットを出さないので擬似時間に縛られない `test` で書く。
    test('進行中のロードが圏外で終わったら、復帰通知で取り直す', () async {
      final cache = InMemoryLibraryCacheStore();
      await cache.write(
        LibrarySnapshot(
          books: sampleBooks,
          etag: '"v1"',
          fetchedAt: DateTime.utc(2026, 9, 20),
        ),
      );
      final api = _OfflineOnceBooksApi();

      final container = createContainer(
        booksApi: api,
        // 購読した瞬間（= 初回ロードの最中）に復帰通知が届く。
        connectivityMonitor: FakeConnectivityMonitor(emitsOnListen: true),
        libraryCache: cache,
      );
      addTearDown(container.dispose);
      final sub = container.listen(libraryControllerProvider, (_, _) {});
      addTearDown(sub.close);

      // 初回ロードは圏外で終わる（控えを isStale つきで返す）。
      final first = await container.read(libraryControllerProvider.future);
      expect(first.isStale, isTrue);
      await pumpEventQueue();

      final data = container.read(libraryControllerProvider).value!;
      expect(api.fetchBooksCount, 2, reason: '復帰の合図を取りこぼさない');
      expect(data.isStale, isFalse);
    });

    testWidgets('最新を表示中なら復帰通知で取りに行かない', (tester) async {
      final monitor = FakeConnectivityMonitor();
      final api = FakeBooksApi(books: sampleBooks, etag: '"v1"');
      await pumpLibrary(tester, booksApi: api, connectivityMonitor: monitor);
      final before = api.fetchBooksCount;

      monitor.restore();
      await tester.pumpAndSettle();

      expect(api.fetchBooksCount, before, reason: '自宅サーバーを無駄に叩かない');
    });

    // 再起動直後の圏外（プロセス内に前回の内容が無い）を模す。一覧は端末の
    // キャッシュから、カテゴリ / タグは端末の控えから出せること。
    testWidgets('再起動後の圏外でも一覧と絞り込みチップが出る', (tester) async {
      final cache = InMemoryLibraryCacheStore();
      await cache.write(
        LibrarySnapshot(
          books: sampleBooks,
          etag: '"v1"',
          fetchedAt: DateTime.utc(2026, 9, 20),
          userStatus: const UserStatus(favorites: [1]),
        ),
      );
      final offline = FakeOfflineMetadataGateway(
        categories: const [Taxonomy(id: 1, name: '少年')],
      );

      await pumpLibrary(
        tester,
        booksApi: FakeBooksApi(error: const NetworkException()),
        taxonomyApi: FakeTaxonomyApi(error: const NetworkException()),
        offline: offline,
        libraryCache: cache,
        downloads: {
          340: const VolumeDownload(
            volumeId: 340,
            bookId: 1,
            filesVersion: 1,
            status: VolumeDownloadStatus.completed,
          ),
        },
      );

      expect(find.text('進撃の巨人'), findsOneWidget, reason: '端末のキャッシュから出す');
      expect(
        find.widgetWithText(FilterChip, '少年'),
        findsOneWidget,
        reason: 'チップが無いと絞り込みを解除できない',
      );
    });

    testWidgets('掃除の契機を通す（ダウンロードを消したタイトルの控えを残さない）', (tester) async {
      final offline = FakeOfflineMetadataGateway();
      await pumpLibrary(tester, offline: offline);

      expect(offline.pruneCount, 1);
    });
  });

  testWidgets('手元に何も無い状態の失敗はエラー表示 + 再試行', (tester) async {
    final api = FakeBooksApi(error: const NetworkException());
    await pumpLibrary(tester, booksApi: api);

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('ネットワークに接続できませんでした。'), findsOneWidget);

    api
      ..error = null
      ..books = sampleBooks;
    await tester.tap(find.widgetWithText(OutlinedButton, '再試行'));
    await tester.pumpAndSettle();

    expect(find.byType(BookGridTile), findsNWidgets(2));
  });

  testWidgets('更新に失敗したら（エラー表示に切り替わらない場合）知らせる', (tester) async {
    final api = FakeBooksApi(books: sampleBooks, etag: '"v1"');
    await pumpLibrary(tester, booksApi: api);

    // キャッシュで代替できない種類のエラー（黙って古い一覧を見せない）
    api.error = const UnexpectedResponseException();
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('更新できませんでした'), findsOneWidget);
    expect(find.byType(BookGridTile), findsNWidgets(2), reason: '一覧は残す');
  });

  testWidgets('オフラインでもカテゴリチップと続きを読むを保つ', (tester) async {
    final api = FakeBooksApi(books: sampleBooks, etag: '"v1"');
    final userApi = FakeUserApi(
      reading: const [
        ReadingBook(bookId: 1, volumeId: 340, title: '進撃の巨人', volumeNumber: 3),
      ],
    );
    final taxonomyApi = FakeTaxonomyApi(
      categories: const [Taxonomy(id: 1, name: '少年')],
    );
    final container = await pumpLibrary(
      tester,
      booksApi: api,
      userApi: userApi,
      taxonomyApi: taxonomyApi,
    );
    expect(find.widgetWithText(FilterChip, '少年'), findsOneWidget);

    // 圏外: 一覧はキャッシュ、補助データは取得できない
    api.error = const NetworkException();
    userApi.readingError = const NetworkException();
    taxonomyApi.error = const NetworkException();
    await container.read(libraryControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(FilterChip, '少年'),
      findsOneWidget,
      reason: 'チップが消えると絞り込みを解除できなくなる',
    );
    expect(find.text('続きを読む'), findsOneWidget);
  });

  testWidgets('お気に入りの変更はオフライン用キャッシュにも反映する', (tester) async {
    final api = FakeBooksApi(
      books: sampleBooks,
      userStatus: const UserStatus(favorites: []),
      etag: '"v1"',
    );
    final container = await pumpLibrary(tester, booksApi: api);

    container
        .read(libraryControllerProvider.notifier)
        .setFavorite(bookId: 1, isFavorite: true);
    // キャッシュへの書き込みは表示を待たせないよう非同期（#11 で永続化したため）。
    await tester.pumpAndSettle();

    // 圏外で開き直してもお気に入りが残る
    api.error = const NetworkException();
    await container.read(libraryControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(
      container.read(libraryControllerProvider).value?.favoriteIds,
      contains(1),
    );
  });

  testWidgets('完結していない作品は「全 N 巻」と表示しない', (tester) async {
    await pumpLibrary(tester);

    expect(find.text('全 34 巻'), findsOneWidget, reason: '進撃の巨人は完結');
    expect(find.text('108 巻まで'), findsOneWidget, reason: 'ONE PIECE は連載中');
    expect(find.text('全 108 巻'), findsNothing);
  });

  testWidgets('書籍が 0 件なら空表示', (tester) async {
    await pumpLibrary(tester, booksApi: FakeBooksApi());

    expect(find.textContaining('表示できる書籍がありません'), findsOneWidget);
  });
}
