import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/widgets/error_view.dart';
import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/features/downloads/application/download_settings.dart';
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
import '../../support/offline_fakes.dart';
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
  Map<int, VolumeDownload>? downloads,
  FakeOfflineMetadataGateway? offline,
  DownloadGate downloadGate = DownloadGate.open,
}) async {
  final container = createContainer(
    booksApi: booksApi ?? FakeBooksApi(bookDetail: sampleDetail()),
    downloadQueue: downloadQueue == null ? null : () => downloadQueue,
    downloads: downloads,
    downloadGate: downloadGate,
    offlineMetadata: offline,
  );
  addTearDown(container.dispose);

  // 既定の 800x600 だと、ヒーロー + メタ情報の下に巻一覧が 1 件しか入らない。
  // 実機（縦長）と同じように巻が並ぶ高さにしておく（スクロールしないと
  // 見えない、という理由でテストが落ちるのを避ける）。
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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

    // AppBar は置かず、タイトルはヒーローにだけ出す（Web 版と同じ構成）。
    expect(find.text('進撃の巨人'), findsOneWidget, reason: 'ヒーロー');
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('諫山創'), findsOneWidget);
    expect(find.text('巨人と戦う話'), findsOneWidget);
    expect(find.text('講談社 · 少年マガジンコミックス'), findsOneWidget, reason: '出版社とレーベル');
    expect(find.text('完結'), findsOneWidget);
    expect(find.byType(VolumeTile), findsNWidgets(2));
    expect(find.text('1 巻'), findsOneWidget);
    expect(find.text('2 巻'), findsOneWidget);
    expect(find.text('全 2 巻'), findsOneWidget, reason: 'ヒーローの巻数');
  });

  testWidgets('ヒーローの背景は 1 巻の 1 ページ目', (tester) async {
    // サムネイル（小さい）を引き伸ばすより絵が鮮明に出る。ダウンロード済みなら
    // この画像もローカルから解決される（#11）ので、圏外でも背景が出る。
    await pumpDetail(tester);

    final stubs = tester
        .widgetList<StubThumbnail>(find.byType(StubThumbnail))
        .toList();
    final page = stubs.where((stub) => stub.request.page != null).toList();
    expect(page, isNotEmpty, reason: '背景にページ画像を使う');
    expect(page.first.request.page!.volumeId, 340, reason: '1 巻');
    expect(page.first.request.page!.page, 1, reason: '1 ページ目');
  });

  testWidgets('アーカイブが無いタイトルはサムネイルを背景にする', (tester) async {
    // ページ URL には files_version が要る。無い巻で組み立てると壊れた URL に
    // なるので、サムネイルで代用する。
    await pumpDetail(
      tester,
      booksApi: FakeBooksApi(
        bookDetail: sampleDetail(
          volumes: const [
            BookVolume(
              id: 340,
              volume: 1,
              thumbnail: '/books/thumbnail/340?m=1',
            ),
          ],
        ),
      ),
    );

    final stubs = tester.widgetList<StubThumbnail>(find.byType(StubThumbnail));
    expect(
      stubs.every((stub) => stub.request.page == null),
      isTrue,
      reason: 'ページ画像は組み立てない',
    );
  });

  testWidgets('全巻の容量を表示する（一括ダウンロードの判断材料）', (tester) async {
    await pumpDetail(tester);

    // 範囲ごとの巻数と容量は「まとめてダウンロード」のダイアログで見せる（#10）。
    expect(find.text('100.0 MB'), findsOneWidget, reason: 'メタ情報');
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

    testWidgets('サーバーから消えた巻でも、端末にあるなら削除できる', (tester) async {
      // ZIP が移動・削除されて archive_bytes / files_version が null になった巻。
      // 「ダウンロード不可」だけを出すと、端末の数百 MB を回収する導線が消える。
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
            volumes: const [BookVolume(id: 340, volume: 1)],
          ),
        ),
        downloadQueue: queue,
      );

      expect(find.textContaining('ダウンロード済み'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      await tester.pumpAndSettle();

      expect(queue.removed, [340]);
    });

    testWidgets('取り直し待ちの巻の取り消しは中断にして旧世代を残す（remove で読める ZIP を消さない）', (
      tester,
    ) async {
      // 「更新あり」の取り直しを積んだ直後（待機中）。台帳は旧世代を指したまま。
      final queue = StubDownloadQueue(
        initial: {
          340: const VolumeDownload(
            volumeId: 340,
            bookId: 12,
            filesVersion: 1,
            status: VolumeDownloadStatus.queued,
            receivedBytes: 100,
            totalBytes: 100,
            pageCount: 190,
          ),
        },
      );
      await pumpDetail(tester, downloadQueue: queue);

      await tester.tap(find.byTooltip('更新を中止'));
      await tester.pumpAndSettle();

      expect(queue.paused, [340]);
      expect(queue.removed, isEmpty);
    });

    testWidgets('初回の待機中の取り消しは remove（読める実体が無いので残すものが無い）', (tester) async {
      final queue = StubDownloadQueue(
        initial: {
          340: const VolumeDownload(
            volumeId: 340,
            bookId: 12,
            filesVersion: 0,
            status: VolumeDownloadStatus.queued,
          ),
        },
      );
      await pumpDetail(tester, downloadQueue: queue);

      await tester.tap(find.byTooltip('ダウンロードを取り消す'));
      await tester.pumpAndSettle();

      expect(queue.removed, [340]);
      expect(queue.paused, isEmpty);
    });

    for (final status in [
      VolumeDownloadStatus.paused,
      VolumeDownloadStatus.failed,
    ]) {
      testWidgets(
        '旧世代が読める${status.name}の行の×は、確認してから削除する（黙って remove で読める ZIP を消さない）',
        (tester) async {
          // 以前のキューが、再起動後の取り直しの中断 / 失敗で書いた行
          // （旧世代の ZIP を指したまま）。
          final queue = StubDownloadQueue(
            initial: {
              340: VolumeDownload(
                volumeId: 340,
                bookId: 12,
                filesVersion: 3,
                status: status,
                receivedBytes: 100,
                totalBytes: 100,
                pageCount: 10,
              ),
            },
          );
          await pumpDetail(tester, downloadQueue: queue);

          expect(find.byTooltip('ダウンロードを取り消す'), findsNothing);
          await tester.tap(find.byTooltip('ダウンロードを削除'));
          await tester.pumpAndSettle();
          expect(queue.removed, isEmpty, reason: '確認を出した時点ではまだ消さない');

          await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
          await tester.pumpAndSettle();
          expect(queue.removed, isEmpty);

          await tester.tap(find.byTooltip('ダウンロードを削除'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, '削除'));
          await tester.pumpAndSettle();
          expect(queue.removed, [340]);
        },
      );
    }

    testWidgets('取り直しに失敗した巻は理由を添えて、もう一度試せる', (tester) async {
      // 通信エラーで旧世代（ダウンロード済み）へ戻した行。黙って
      // 「ダウンロード済み」に見せると、更新が入ったと誤解される。
      final queue = StubDownloadQueue(
        initial: {
          340: const VolumeDownload(
            volumeId: 340,
            bookId: 12,
            filesVersion: 1,
            status: VolumeDownloadStatus.completed,
            receivedBytes: 100,
            totalBytes: 100,
            failureReason: 'ネットワークに接続できません。',
          ),
        },
      );
      await pumpDetail(tester, downloadQueue: queue);

      expect(find.textContaining('更新の取得に失敗: ネットワークに接続できません。'), findsOneWidget);

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
        container
            .read(bookDetailControllerProvider(12))
            .value
            ?.detail
            .isFavorite,
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

  group('まとめてダウンロード（#10）', () {
    // 1 巻は読了、4 巻はアーカイブが無い（数えない）。
    final volumes = [
      const BookVolume(
        id: 340,
        volume: 1,
        archiveBytes: 1048576,
        filesVersion: 1,
        userStatus: VolumeUserStatus(
          currentPage: 10,
          maxPage: 10,
          isFinished: true,
        ),
      ),
      const BookVolume(
        id: 341,
        volume: 2,
        archiveBytes: 2097152,
        filesVersion: 1,
      ),
      const BookVolume(
        id: 342,
        volume: 3,
        archiveBytes: 3145728,
        filesVersion: 1,
      ),
      const BookVolume(id: 343, volume: 4),
    ];

    Future<StubDownloadQueue> openDialog(
      WidgetTester tester, {
      DownloadGate downloadGate = DownloadGate.open,
    }) async {
      final queue = StubDownloadQueue();
      await pumpDetail(
        tester,
        booksApi: FakeBooksApi(bookDetail: sampleDetail(volumes: volumes)),
        downloadQueue: queue,
        downloadGate: downloadGate,
      );
      await tester.tap(find.text('まとめてダウンロード'));
      await tester.pumpAndSettle();
      return queue;
    }

    testWidgets('範囲ごとの巻数と容量を見せてから積む', (tester) async {
      final queue = await openDialog(tester);

      // 1 巻数百 MB になるので、押した瞬間には積まない。
      expect(queue.enqueued, isEmpty);
      // 全巻と「最新の 3 巻」が同じ 3 巻になる。
      expect(find.text('3 巻・6.0 MB'), findsNWidgets(2), reason: '全巻 / 最新 3 巻');
      expect(find.text('2 巻・5.0 MB'), findsOneWidget, reason: '未読のみ');

      await tester.tap(find.text('未読のみ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 巻をダウンロード'));
      await tester.pumpAndSettle();

      expect(queue.enqueued, [
        (volumeId: 341, bookId: 12),
        (volumeId: 342, bookId: 12),
      ], reason: '読む順（巻数の小さい順）に積む');
    });

    testWidgets('最新 N 巻は N を選べる', (tester) async {
      final queue = await openDialog(tester);

      await tester.tap(find.byKey(const Key('title-download-latest-count')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 巻をダウンロード'));
      await tester.pumpAndSettle();

      expect(queue.enqueued, [(volumeId: 342, bookId: 12)]);
    });

    testWidgets('Wi-Fi 待ちになることを実行前に伝える', (tester) async {
      await openDialog(tester, downloadGate: DownloadGate.waitingForWifi);

      expect(find.textContaining('Wi-Fi に接続するまで待機します'), findsOneWidget);
    });

    testWidgets('Wi-Fi 待ちの巻は「ダウンロード待ち」ではなくそう表示する', (tester) async {
      await pumpDetail(
        tester,
        downloadGate: DownloadGate.waitingForWifi,
        downloads: {
          340: const VolumeDownload(
            volumeId: 340,
            bookId: 12,
            filesVersion: 0,
            status: VolumeDownloadStatus.queued,
          ),
        },
      );

      expect(find.textContaining('Wi-Fi 接続待ち'), findsOneWidget);
    });

    testWidgets('取得中・待機中の巻をタイトル単位で中断できる', (tester) async {
      final queue = StubDownloadQueue(
        initial: {
          341: const VolumeDownload(
            volumeId: 341,
            bookId: 12,
            filesVersion: 0,
            status: VolumeDownloadStatus.downloading,
          ),
          342: const VolumeDownload(
            volumeId: 342,
            bookId: 12,
            filesVersion: 0,
            status: VolumeDownloadStatus.queued,
          ),
          // 別タイトルの巻は止めない。
          999: const VolumeDownload(
            volumeId: 999,
            bookId: 77,
            filesVersion: 0,
            status: VolumeDownloadStatus.downloading,
          ),
        },
      );
      await pumpDetail(
        tester,
        booksApi: FakeBooksApi(bookDetail: sampleDetail(volumes: volumes)),
        downloadQueue: queue,
      );

      await tester.tap(find.text('2 巻を中断'));
      await tester.pumpAndSettle();

      expect(queue.paused, unorderedEquals([341, 342]));
    });

    testWidgets('すべて手元にあるなら実行できない', (tester) async {
      await pumpDetail(
        tester,
        downloads: {
          340: const VolumeDownload(
            volumeId: 340,
            bookId: 12,
            filesVersion: 1,
            status: VolumeDownloadStatus.completed,
          ),
        },
      );
      await tester.tap(find.text('まとめてダウンロード'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'ダウンロードする巻がありません'),
      );
      expect(button.onPressed, isNull);
    });
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

  group('オフライン（#11）', () {
    /// 圏外（詳細も取れない）で、1 巻だけダウンロード済みの状態。
    Future<void> pumpOffline(WidgetTester tester) async {
      // オフラインの案内が入ると既定の 800x600 では 2 巻目が画面外になり、
      // 遅延生成の SliverList が作らない（見つからない）。縦を広げておく。
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpDetail(
        tester,
        booksApi: FakeBooksApi(bookDetailError: const NetworkException()),
        offline: FakeOfflineMetadataGateway(details: {12: sampleDetail()}),
        downloads: {
          340: const VolumeDownload(
            volumeId: 340,
            bookId: 12,
            filesVersion: 1,
            status: VolumeDownloadStatus.completed,
          ),
        },
      );
    }

    testWidgets('端末の控えで詳細を表示し、オフラインであることを伝える', (tester) async {
      await pumpOffline(tester);

      expect(find.text('オフラインです。ダウンロード済みの巻だけ読めます。'), findsOneWidget);
      expect(find.byType(VolumeTile), findsNWidgets(2));
      // 圏外で積んでも失敗するだけなので、一括ダウンロードは出さない。
      expect(find.text('まとめてダウンロード'), findsNothing);
    });

    testWidgets('未ダウンロードの巻は無効表示にする（エラーダイアログを出さない）', (tester) async {
      await pumpOffline(tester);

      // 1 巻（ダウンロード済み）は開ける。2 巻は開けない。
      final tiles = tester.widgetList<VolumeTile>(find.byType(VolumeTile));
      expect(tiles.map((tile) => tile.onOpen != null), [true, false]);
      expect(find.textContaining('オフラインでは読めません'), findsOneWidget);
    });

    testWidgets('控えが無ければエラー表示（黙って空の詳細を見せない）', (tester) async {
      await pumpDetail(
        tester,
        booksApi: FakeBooksApi(bookDetailError: const NetworkException()),
        offline: FakeOfflineMetadataGateway(),
      );

      expect(find.byType(ErrorView), findsOneWidget);
    });

    // 「詳細を開く → ダウンロード」の順に操作されるので、取得時点ではまだ
    // 未ダウンロード（= 控えは保存されない）。完了を契機に控え直さないと、
    // 圏外でそのタイトルの詳細が開けない。
    testWidgets('ダウンロードが完了したら詳細を控え直す（圏外で開けるように）', (tester) async {
      final offline = FakeOfflineMetadataGateway();
      final queue = StubDownloadQueue();
      await pumpDetail(tester, downloadQueue: queue, offline: offline);
      expect(offline.savedDetails, [12], reason: '取得時にも控えを試みる');

      // ダウンロード完了をキューの状態として流す。
      queue.emit(
        const VolumeDownload(
          volumeId: 340,
          bookId: 12,
          filesVersion: 1,
          status: VolumeDownloadStatus.completed,
        ),
      );
      await tester.pumpAndSettle();

      expect(offline.savedDetails, [12, 12], reason: '完了後にもう一度控える');
    });
  });
}

/// お気に入り登録が必ず失敗する API。
class _FailingFavoriteApi extends FakeBooksApi {
  _FailingFavoriteApi({super.bookDetail});

  @override
  Future<bool> addFavorite(int bookId) async => throw const NetworkException();
}
