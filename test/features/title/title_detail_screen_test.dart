import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/widgets/error_view.dart';
import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/library/application/library_controller.dart';
import 'package:comic_laz/features/title/application/book_detail_controller.dart';
import 'package:comic_laz/features/title/presentation/title_detail_screen.dart';
import 'package:comic_laz/features/title/presentation/widgets/volume_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';
import '../../support/download_fakes.dart';
import '../../support/test_scope.dart';

BookDetail sampleDetail({
  bool isFavorite = false,
  bool isComplete = true,
  List<BookVolume>? volumes,
  ReadingProgress? progress,
}) => BookDetail(
  id: 12,
  title: '進撃の巨人',
  overview: '巨人と戦う話',
  isComplete: isComplete,
  isFavorite: isFavorite,
  authors: const ['諫山創'],
  publisher: '講談社',
  label: '少年マガジンコミックス',
  tags: const ['アクション'],
  categories: const [BookCategory(id: 1, name: '少年')],
  volumes:
      volumes ??
      const [
        BookVolume(
          id: 340,
          volume: 1,
          archiveBytes: 104857600,
          filesVersion: 1,
          totalPages: 190,
          userStatus: VolumeUserStatus(
            currentPage: 12,
            maxPage: 190,
            isFinished: false,
          ),
        ),
        BookVolume(id: 341, volume: 2),
      ],
  totalArchiveBytes: 104857600,
  readingProgress:
      progress ??
      const ReadingProgress(
        readVolumes: 0,
        totalVolumes: 2,
        currentVolume: 1,
        currentPage: 12,
        totalPages: 190,
      ),
);

Future<ProviderContainer> pumpDetail(
  WidgetTester tester, {
  FakeBooksApi? booksApi,
  StubDownloadQueue? downloadQueue,
}) async {
  final container = createContainer(
    booksApi: booksApi ?? FakeBooksApi(bookDetail: sampleDetail()),
    downloadQueue: downloadQueue == null ? null : () => downloadQueue,
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TitleDetailScreen(bookId: 12)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('タイトル・著者・メタ情報・巻一覧を表示する', (tester) async {
    await pumpDetail(tester);

    expect(find.text('進撃の巨人'), findsNWidgets(2), reason: 'AppBar とヒーロー');
    expect(find.text('諫山創'), findsOneWidget);
    expect(find.text('巨人と戦う話'), findsOneWidget);
    expect(find.text('講談社'), findsOneWidget);
    expect(find.text('完結'), findsOneWidget);
    expect(find.byType(VolumeTile), findsNWidgets(2));
    expect(find.text('1 巻'), findsOneWidget);
    expect(find.text('2 巻'), findsOneWidget);
    expect(find.text('全 2 巻'), findsOneWidget, reason: 'ヒーローの巻数');
  });

  testWidgets('全巻の容量を表示する（一括ダウンロードの判断材料）', (tester) async {
    await pumpDetail(tester);

    expect(find.text('100.0 MB'), findsOneWidget, reason: 'メタ情報');
    expect(
      find.textContaining('全 1 巻 (100.0 MB)'),
      findsOneWidget,
      reason: '一括ダウンロードの対象巻数と容量',
    );
  });

  testWidgets('読みかけの巻は「続きから読む」', (tester) async {
    await pumpDetail(tester);

    expect(find.text('1 巻の続きから読む'), findsOneWidget);
  });

  testWidgets('読みかけが無ければ最初の未読巻を開く', (tester) async {
    await pumpDetail(
      tester,
      booksApi: FakeBooksApi(
        bookDetail: sampleDetail(
          volumes: const [
            BookVolume(
              id: 340,
              volume: 1,
              userStatus: VolumeUserStatus(
                currentPage: 190,
                maxPage: 190,
                isFinished: true,
              ),
            ),
            BookVolume(id: 341, volume: 2),
          ],
          progress: const ReadingProgress(readVolumes: 1, totalVolumes: 2),
        ),
      ),
    );

    expect(find.text('2 巻を読む'), findsOneWidget);
  });

  testWidgets('巻の読了 / 読みかけ / 未読を表示する', (tester) async {
    await pumpDetail(tester);

    expect(find.textContaining('12 / 190 ページ'), findsOneWidget);
    expect(find.textContaining('未読'), findsOneWidget);
  });

  testWidgets('ダウンロードできない巻はその旨を示す', (tester) async {
    await pumpDetail(tester);

    // 2 巻は archive_bytes / files_version が無いので落とせない。
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.textContaining('ダウンロード不可'), findsOneWidget);
  });

  group('巻ごとのダウンロード導線', () {
    testWidgets('台帳に無い巻は「未ダウンロード」で、押すとキューに積む', (tester) async {
      final queue = StubDownloadQueue();
      await pumpDetail(tester, downloadQueue: queue);

      expect(find.textContaining('未ダウンロード'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.download_outlined));
      await tester.pumpAndSettle();

      expect(queue.enqueued, [
        (volumeId: 340, bookId: 12),
      ], reason: '一括ダウンロード（#10）と共有する台帳のため book_id も渡す');
    });

    testWidgets('取得中は % を出し、押すと中断する', (tester) async {
      final queue = StubDownloadQueue(
        initial: {
          340: const VolumeDownload(
            volumeId: 340,
            bookId: 12,
            filesVersion: 1,
            status: VolumeDownloadStatus.downloading,
            receivedBytes: 30,
            totalBytes: 100,
          ),
        },
      );
      await pumpDetail(tester, downloadQueue: queue);

      expect(find.textContaining('ダウンロード中 30%'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pumpAndSettle();

      expect(queue.paused, [340]);
    });

    testWidgets('中断中は続きから再開できる（取り直しにしない）', (tester) async {
      final queue = StubDownloadQueue(
        initial: {
          340: const VolumeDownload(
            volumeId: 340,
            bookId: 12,
            filesVersion: 1,
            status: VolumeDownloadStatus.paused,
            receivedBytes: 50,
            totalBytes: 100,
          ),
        },
      );
      await pumpDetail(tester, downloadQueue: queue);

      expect(find.textContaining('中断中 50%'), findsOneWidget);
      // ヒーローの「続きから読む」も同じアイコンなので、行の中に絞る。
      await tester.tap(
        find.descendant(
          of: find.byType(VolumeTile),
          matching: find.byIcon(Icons.play_arrow),
        ),
      );
      await tester.pumpAndSettle();

      expect(queue.resumed, [340]);
      expect(queue.enqueued, isEmpty, reason: '再開は Range で続きから取る');
    });

    testWidgets('失敗は理由を添えて見せる（黙って未ダウンロードに戻さない）', (tester) async {
      final queue = StubDownloadQueue(
        initial: {
          340: const VolumeDownload(
            volumeId: 340,
            bookId: 12,
            filesVersion: 1,
            status: VolumeDownloadStatus.failed,
            failureReason: 'ページ数が一致しません（2 / 3 ページ）。',
          ),
        },
      );
      await pumpDetail(tester, downloadQueue: queue);

      expect(find.textContaining('ページ数が一致しません（2 / 3 ページ）。'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('ダウンロード済みは削除の確認を挟む（オフラインで読めなくなる）', (tester) async {
      final queue = StubDownloadQueue(
        initial: {
          340: const VolumeDownload(
            volumeId: 340,
            bookId: 12,
            filesVersion: 1,
            status: VolumeDownloadStatus.completed,
            receivedBytes: 100,
            totalBytes: 100,
          ),
        },
      );
      await pumpDetail(tester, downloadQueue: queue);

      expect(find.textContaining('ダウンロード済み'), findsOneWidget);
      expect(find.byIcon(Icons.offline_pin), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      // 確認を出した時点ではまだ消さない。
      expect(queue.removed, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();
      expect(queue.removed, [340]);
    });

    testWidgets('files_version が変わっていたら「更新あり」として落とし直せる', (tester) async {
      // 手元は世代 1、サーバーの巻は files_version = 9。
      final queue = StubDownloadQueue(
        initial: {
          340: const VolumeDownload(
            volumeId: 340,
            bookId: 12,
            filesVersion: 1,
            status: VolumeDownloadStatus.completed,
            receivedBytes: 100,
            totalBytes: 100,
          ),
        },
      );
      await pumpDetail(
        tester,
        booksApi: FakeBooksApi(
          bookDetail: sampleDetail(
            volumes: const [
              BookVolume(
                id: 340,
                volume: 1,
                archiveBytes: 104857600,
                filesVersion: 9,
                totalPages: 190,
              ),
            ],
          ),
        ),
        downloadQueue: queue,
      );

      expect(find.textContaining('更新あり'), findsOneWidget);
      expect(find.byIcon(Icons.offline_pin), findsNothing);

      await tester.tap(find.byIcon(Icons.sync_problem));
      await tester.pumpAndSettle();
      expect(queue.enqueued, [(volumeId: 340, bookId: 12)]);
    });
  });

  group('お気に入り', () {
    testWidgets('切り替えるとサーバーへ送り、一覧にも反映する', (tester) async {
      final api = FakeBooksApi(bookDetail: sampleDetail());
      final container = await pumpDetail(tester, booksApi: api);

      await tester.tap(find.byTooltip('お気に入りに追加'));
      await tester.pumpAndSettle();

      expect(api.favorites, contains(12));
      expect(
        container.read(bookDetailControllerProvider(12)).value?.isFavorite,
        isTrue,
      );
      expect(find.byTooltip('お気に入りから外す'), findsOneWidget);
    });

    testWidgets('一覧を表示中なら一覧側のお気に入りにも反映する', (tester) async {
      final api = FakeBooksApi(
        bookDetail: sampleDetail(),
        books: [testBook(id: 12)],
      );
      final container = createContainer(booksApi: api);
      addTearDown(container.dispose);
      // 一覧を「表示中」にする
      final sub = container.listen(libraryControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(libraryControllerProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TitleDetailScreen(bookId: 12)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('お気に入りに追加'));
      await tester.pumpAndSettle();

      expect(
        container.read(libraryControllerProvider).value?.favoriteIds,
        contains(12),
      );
    });

    testWidgets('失敗したら元に戻してメッセージを出す', (tester) async {
      final api = _FailingFavoriteApi(bookDetail: sampleDetail());
      await pumpDetail(tester, booksApi: api);

      await tester.tap(find.byTooltip('お気に入りに追加'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('お気に入りに追加'), findsOneWidget, reason: '元の状態へ戻す');
      expect(find.textContaining('お気に入りを変更できませんでした'), findsOneWidget);
    });
  });

  testWidgets('読了済みの巻は「続きから」の対象にしない', (tester) async {
    await pumpDetail(
      tester,
      booksApi: FakeBooksApi(
        bookDetail: sampleDetail(
          volumes: const [
            BookVolume(
              id: 340,
              volume: 1,
              userStatus: VolumeUserStatus(
                currentPage: 190,
                maxPage: 190,
                isFinished: true,
              ),
            ),
            BookVolume(id: 341, volume: 2),
          ],
          // サーバーが読了後も current_volume を返すケース
          progress: const ReadingProgress(
            readVolumes: 1,
            totalVolumes: 2,
            currentVolume: 1,
          ),
        ),
      ),
    );

    expect(find.text('2 巻を読む'), findsOneWidget);
    expect(find.text('1 巻を読む'), findsNothing);
  });

  testWidgets('一括ダウンロードの件数と容量は同じ巻から数える', (tester) async {
    await pumpDetail(
      tester,
      booksApi: FakeBooksApi(
        bookDetail: sampleDetail(
          volumes: const [
            BookVolume(
              id: 340,
              volume: 1,
              archiveBytes: 1048576,
              filesVersion: 1,
            ),
            // files_version が無い = ダウンロード対象外
            BookVolume(id: 341, volume: 2, archiveBytes: 99999999),
          ],
        ).copyWith(totalArchiveBytes: 0),
      ),
    );

    expect(find.textContaining('全 1 巻 (1.0 MB)'), findsOneWidget);
  });

  testWidgets('再取得に失敗したらその場で知らせる（詳細は残す）', (tester) async {
    final api = FakeBooksApi(bookDetail: sampleDetail());
    await pumpDetail(tester, booksApi: api);

    api.bookDetail = null;
    // プルリフレッシュの経路で知らせる
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('タイトル詳細 を更新できませんでした'), findsOneWidget);
    expect(find.byType(VolumeTile), findsNWidgets(2), reason: '表示中の内容は残す');
  });

  testWidgets('読み込み失敗はエラー表示 + 再試行', (tester) async {
    final api = FakeBooksApi();
    await pumpDetail(tester, booksApi: api);

    expect(find.byType(ErrorView), findsOneWidget);

    api.bookDetail = sampleDetail();
    await tester.tap(find.widgetWithText(OutlinedButton, '再試行'));
    await tester.pumpAndSettle();

    expect(find.byType(VolumeTile), findsNWidgets(2));
  });

  testWidgets('巻が無い場合の表示', (tester) async {
    await pumpDetail(
      tester,
      booksApi: FakeBooksApi(
        bookDetail: sampleDetail(
          volumes: const [],
          progress: const ReadingProgress(),
        ),
      ),
    );

    expect(find.text('登録されている巻がありません。'), findsOneWidget);
  });
}

/// お気に入り登録が必ず失敗する API。
class _FailingFavoriteApi extends FakeBooksApi {
  _FailingFavoriteApi({super.bookDetail});

  @override
  Future<bool> addFavorite(int bookId) async => throw const NetworkException();
}
