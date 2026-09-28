import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/widgets/error_view.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/reading_book.dart';
import 'package:comic_laz/features/library/application/library_controller.dart';
import 'package:comic_laz/features/library/presentation/library_screen.dart';
import 'package:comic_laz/features/library/presentation/widgets/book_tiles.dart';
import 'package:comic_laz/features/library/presentation/widgets/continue_reading_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';
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

Future<ProviderContainer> pumpLibrary(
  WidgetTester tester, {
  FakeBooksApi? booksApi,
  FakeUserApi? userApi,
  FakeTaxonomyApi? taxonomyApi,
}) async {
  final container = createContainer(
    booksApi: booksApi ?? FakeBooksApi(books: sampleBooks),
    userApi: userApi ?? FakeUserApi(),
    taxonomyApi: taxonomyApi ?? FakeTaxonomyApi(),
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

  testWidgets('オフライン時はキャッシュを出しつつバナーで伝える', (tester) async {
    final api = FakeBooksApi(books: sampleBooks, etag: '"v1"');
    final container = await pumpLibrary(tester, booksApi: api);

    api.error = const NetworkException();
    await container.read(libraryControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(find.textContaining('オフラインです'), findsOneWidget);
    expect(find.byType(BookGridTile), findsNWidgets(2));
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
    final container = await pumpLibrary(tester, booksApi: api);

    // キャッシュで代替できない種類のエラー（黙って古い一覧を見せない）
    api.error = const UnexpectedResponseException();
    await container.read(libraryControllerProvider.notifier).refresh();
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
