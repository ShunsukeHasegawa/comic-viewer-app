import 'dart:async';
import 'dart:io';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/features/downloads/application/download_queue.dart';
import 'package:comic_laz/features/downloads/application/download_settings.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/downloads/presentation/download_manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';
import '../../support/download_fakes.dart';
import '../../support/offline_fakes.dart';
import '../../support/test_scope.dart';

const mib = 1024 * 1024;

VolumeDownload installed(
  int volumeId, {
  int bookId = 12,
  int filesVersion = 1,
  int totalBytes = mib,
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

VolumeDownload fresh(
  int volumeId,
  VolumeDownloadStatus status, {
  int bookId = 12,
  String? failureReason,
}) => VolumeDownload(
  volumeId: volumeId,
  bookId: bookId,
  filesVersion: 0,
  status: status,
  receivedBytes: 30,
  totalBytes: 100,
  failureReason: failureReason,
);

/// 控えの読み込みに失敗するタイトルを作れるゲートウェイ。
class FlakyOfflineGateway extends FakeOfflineMetadataGateway {
  FlakyOfflineGateway({super.details, this.failingBooks = const {}});

  final Set<int> failingBooks;

  @override
  Future<BookDetail?> readBookDetail(int bookId) async {
    if (failingBooks.contains(bookId)) {
      throw const FileSystemException('db locked');
    }
    return super.readBookDetail(bookId);
  }
}

/// 台帳の読み込みに失敗するキュー。
class FailingDownloadQueue extends DownloadQueue {
  @override
  Future<Map<int, VolumeDownload>> build() async =>
      throw const FileSystemException('no space');
}

Future<({ProviderContainer container, StubDownloadQueue queue})> pumpManager(
  WidgetTester tester, {
  Map<int, VolumeDownload> ledger = const {},
  StubDownloadQueue? queue,
  FakeOfflineMetadataGateway? offline,
  FakeBooksApi? booksApi,
  DownloadGate downloadGate = DownloadGate.open,
}) async {
  final stub = queue ?? StubDownloadQueue(initial: ledger);
  final container = createContainer(
    downloadQueue: () => stub,
    offlineMetadata: offline,
    booksApi: booksApi,
    downloadGate: downloadGate,
  );
  addTearDown(container.dispose);

  // 見出し・進行中・失敗・巻の行が 1 画面に収まる高さにする（遅延構築の
  // ListView で、スクロールしないと見えないという理由で落ちないように）。
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: DownloadManagerScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return (container: container, queue: stub);
}

Finder inTile(String key, Finder matching) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: matching);

BookDetail titleDetail({
  int id = 12,
  String title = '進撃の巨人',
  Map<int, (int volume, int? filesVersion)> volumes = const {},
}) => BookDetail(
  id: id,
  title: title,
  volumes: [
    for (final MapEntry(key: volumeId, value: (volume, filesVersion))
        in volumes.entries)
      BookVolume(id: volumeId, volume: volume, filesVersion: filesVersion),
  ],
);

void main() {
  testWidgets('進行中の巻の一時停止・再開・キャンセルがキューへ届く', (tester) async {
    final app = await pumpManager(
      tester,
      ledger: {
        341: fresh(341, VolumeDownloadStatus.downloading),
        342: fresh(342, VolumeDownloadStatus.paused),
      },
    );

    expect(find.text('進行中（2）'), findsOneWidget);
    expect(find.textContaining('ダウンロード中 30%'), findsOneWidget);

    await tester.tap(inTile('progress-341', find.byTooltip('一時停止')));
    await tester.pumpAndSettle();
    await tester.tap(inTile('progress-342', find.byTooltip('再開')));
    await tester.pumpAndSettle();
    await tester.tap(inTile('progress-341', find.byTooltip('キャンセル')));
    await tester.pumpAndSettle();

    expect(app.queue.paused, [341]);
    expect(app.queue.resumed, [342]);
    expect(app.queue.removed, [341]);
  });

  testWidgets('取り直し中の巻の中止は pause で、remove しない（remove だと読める旧世代まで消える）', (
    tester,
  ) async {
    final app = await pumpManager(
      tester,
      ledger: {
        340: installed(340).copyWith(status: VolumeDownloadStatus.queued),
      },
    );

    // 旧世代は読めるので、ダウンロード済みにも残っている。
    expect(find.byKey(const ValueKey('group-12')), findsOneWidget);
    expect(inTile('progress-340', find.byTooltip('キャンセル')), findsNothing);

    await tester.tap(inTile('progress-340', find.byTooltip('更新を中止')));
    await tester.pumpAndSettle();

    expect(app.queue.paused, [340]);
    expect(app.queue.removed, isEmpty);
  });

  testWidgets('失敗した巻の再試行は resume、取り直しの失敗は enqueue（completed は resume できないため）', (
    tester,
  ) async {
    final app = await pumpManager(
      tester,
      ledger: {
        343: fresh(343, VolumeDownloadStatus.failed, failureReason: '容量不足'),
        340: installed(340, failureReason: 'ネットワークに接続できません。'),
      },
    );

    expect(find.text('失敗（2）'), findsOneWidget);
    expect(find.textContaining('ダウンロード失敗: 容量不足'), findsOneWidget);
    expect(
      inTile('failed-340', find.textContaining('更新の取得に失敗: ネットワークに接続できません。')),
      findsOneWidget,
    );

    await tester.tap(inTile('failed-343', find.byTooltip('再試行')));
    await tester.pumpAndSettle();
    await tester.tap(inTile('failed-340', find.byTooltip('再試行')));
    await tester.pumpAndSettle();

    expect(app.queue.resumed, [343]);
    expect(app.queue.enqueued, [(volumeId: 340, bookId: 12)]);
  });

  testWidgets('初回の失敗の削除は確認しない（読める実体が無く、消えて困るものが無い）', (tester) async {
    final app = await pumpManager(
      tester,
      ledger: {343: fresh(343, VolumeDownloadStatus.failed)},
    );

    await tester.tap(inTile('failed-343', find.byTooltip('削除')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(app.queue.removed, [343]);
  });

  testWidgets('更新ありの巻の再取得で enqueue する／タイトルの「更新をまとめて取得」は更新ありの巻だけを積む', (
    tester,
  ) async {
    final app = await pumpManager(
      tester,
      ledger: {340: installed(340), 341: installed(341), 342: installed(342)},
      offline: FakeOfflineMetadataGateway(
        details: {
          12: titleDetail(volumes: {340: (1, 2), 341: (2, 1), 342: (3, 5)}),
        },
      ),
    );

    expect(find.textContaining('更新あり 2'), findsOneWidget);

    await tester.tap(find.byTooltip('更新を取得').first);
    await tester.pumpAndSettle();
    expect(app.queue.enqueued, [(volumeId: 340, bookId: 12)]);

    await tester.tap(find.byTooltip('タイトルの操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('更新をまとめて取得'));
    await tester.pumpAndSettle();

    expect(app.queue.enqueued, [
      (volumeId: 340, bookId: 12),
      (volumeId: 340, bookId: 12),
      (volumeId: 342, bookId: 12),
    ]);
  });

  testWidgets('巻の削除は確認してから remove し、キャンセルでは消さない（数百 MB の取り直しになるため）', (
    tester,
  ) async {
    final offline = FakeOfflineMetadataGateway();
    final app = await pumpManager(
      tester,
      ledger: {340: installed(340)},
      offline: offline,
    );

    await tester.tap(find.byTooltip('ダウンロードを削除'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 巻（1.0 MB）を端末から削除します'), findsOneWidget);
    expect(find.textContaining('読書進捗は消えません'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(app.queue.removed, isEmpty);

    await tester.tap(find.byTooltip('ダウンロードを削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '削除'));
    await tester.pumpAndSettle();

    expect(app.queue.removed, [340]);
    expect(offline.pruneCount, 1, reason: 'ダウンロードが無くなったタイトルの控えを捨てる');
    expect(find.text('1 巻（1.0 MB）を削除しました'), findsOneWidget);
  });

  testWidgets('タイトル単位の削除はそのタイトルの行（進行中・失敗を含む）をすべて消す', (tester) async {
    final app = await pumpManager(
      tester,
      ledger: {
        340: installed(340),
        341: fresh(341, VolumeDownloadStatus.downloading),
        343: fresh(343, VolumeDownloadStatus.failed),
        500: installed(500, bookId: 20),
      },
    );

    await tester.tap(inTile('group-12', find.byTooltip('タイトルの操作')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('このタイトルを削除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('進行中・失敗の分も含めて取り消します'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '削除'));
    await tester.pumpAndSettle();

    expect(app.queue.removed, [340, 341, 343], reason: '他のタイトルは消さない');
  });

  testWidgets('複数選択で選んだ巻だけを削除し、合計容量の表示が減る（受け入れ条件）', (tester) async {
    final app = await pumpManager(
      tester,
      queue: StubDownloadQueue(
        initial: {
          340: installed(340),
          341: installed(341),
          500: installed(500, bookId: 20),
        },
        applyRemovals: true,
      ),
    );
    expect(find.text('ダウンロード済み 3 巻・3.0 MB'), findsOneWidget);

    await tester.tap(find.byTooltip('選択'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('巻（ID: 340）'));
    await tester.tap(find.text('巻（ID: 500）'));
    await tester.pumpAndSettle();
    expect(find.text('2 巻選択・2.0 MB'), findsOneWidget);

    await tester.tap(find.byTooltip('削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '削除'));
    await tester.pumpAndSettle();

    expect(app.queue.removed, [340, 500]);
    expect(find.text('ダウンロード済み 1 巻・1.0 MB'), findsOneWidget);
    expect(find.text('巻（ID: 341）'), findsOneWidget);
    // 全部消せたので選択は終わっている。
    expect(find.byTooltip('選択'), findsOneWidget);
  });

  testWidgets('長押しで選択に入り、タイトル見出しのチェックで配下の巻をまとめて選べる', (tester) async {
    await pumpManager(
      tester,
      ledger: {
        340: installed(340),
        341: installed(341),
        500: installed(500, bookId: 20),
      },
    );

    await tester.longPress(find.text('巻（ID: 500）'));
    await tester.pumpAndSettle();
    expect(find.text('1 巻選択・1.0 MB'), findsOneWidget);

    await tester.tap(inTile('group-12', find.byType(Checkbox)).first);
    await tester.pumpAndSettle();
    expect(find.text('3 巻選択・3.0 MB'), findsOneWidget);

    // もう一度押すとまとめて外れる。
    await tester.tap(inTile('group-12', find.byType(Checkbox)).first);
    await tester.pumpAndSettle();
    expect(find.text('1 巻選択・1.0 MB'), findsOneWidget);
  });

  testWidgets('削除に失敗した巻があれば SnackBar で知らせる（黙って残さない）', (tester) async {
    final app = await pumpManager(
      tester,
      queue: StubDownloadQueue(
        initial: {340: installed(340), 341: installed(341)},
        applyRemovals: true,
        failingRemovals: {340},
      ),
    );

    await tester.tap(find.byTooltip('選択'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('すべて選択'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '削除'));
    await tester.pumpAndSettle();

    expect(find.text('ダウンロードの削除に失敗しました: 端末内のデータを処理できませんでした。'), findsOneWidget);
    expect(app.queue.removed, [341], reason: '失敗した巻の後も残りは続ける');
    // 消せなかった巻は選んだまま（もう一度押せば消し直せる）。
    expect(find.text('1 巻選択・1.0 MB'), findsOneWidget);
  });

  testWidgets('何も無いときは空の案内を出す', (tester) async {
    await pumpManager(tester);

    expect(find.text('ダウンロードしたコミックはありません'), findsOneWidget);
    expect(find.text('タイトル詳細の巻一覧からダウンロードできます'), findsOneWidget);
  });

  testWidgets('Wi-Fi 限定で Wi-Fi 待ちのとき、進行中が動かない理由を出す', (tester) async {
    await pumpManager(
      tester,
      ledger: {341: fresh(341, VolumeDownloadStatus.queued)},
      downloadGate: DownloadGate.waitingForWifi,
    );

    expect(find.text('Wi-Fi に接続すると自動で再開します'), findsOneWidget);
    expect(find.text('Wi-Fi 接続待ち'), findsOneWidget);
  });

  testWidgets('台帳の読み込みに失敗したらエラーと再試行を出す', (tester) async {
    final container = ProviderContainer(
      overrides: [...testOverrides(downloadQueue: FailingDownloadQueue.new)],
      // キューは keepAlive で自動再試行が既定。テストではタイマーを残さない。
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DownloadManagerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('読み込みに失敗しました。'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '再試行'), findsOneWidget);
  });

  testWidgets('タイトル名の読み込みに失敗しても一覧は出し、失敗を知らせる', (tester) async {
    await pumpManager(
      tester,
      ledger: {340: installed(340)},
      offline: FlakyOfflineGateway(failingBooks: {12}),
    );

    expect(find.text('タイトル名を読み込めませんでした（ID で表示しています）'), findsOneWidget);
    expect(find.text('タイトル（ID: 12）'), findsOneWidget);
    expect(find.byTooltip('ダウンロードを削除'), findsOneWidget);
  });

  testWidgets('「更新を確認」で取り直し、失敗したら SnackBar で知らせる（表示中の内容は残す）', (tester) async {
    final api = FakeBooksApi(bookDetailError: const NetworkException());
    await pumpManager(
      tester,
      ledger: {340: installed(340)},
      offline: FakeOfflineMetadataGateway(
        details: {
          12: titleDetail(volumes: {340: (1, 1)}),
        },
      ),
      booksApi: api,
    );
    expect(api.fetchBookDetailCalls, isEmpty, reason: '開いただけでは問い合わせない');

    await tester.tap(find.byTooltip('更新を確認'));
    await tester.pumpAndSettle();

    expect(api.fetchBookDetailCalls, [12]);
    expect(find.textContaining('サーバーの更新情報 を更新できませんでした'), findsOneWidget);
    expect(find.text('進撃の巨人'), findsOneWidget);
  });

  testWidgets('「更新を確認」で更新が見つかれば件数を知らせ、行に「更新あり」を出す', (tester) async {
    final api = FakeBooksApi(bookDetail: titleDetail(volumes: {340: (1, 2)}));
    await pumpManager(
      tester,
      ledger: {340: installed(340)},
      offline: FakeOfflineMetadataGateway(
        details: {
          12: titleDetail(volumes: {340: (1, 1)}),
        },
      ),
      booksApi: api,
    );
    expect(find.textContaining('更新あり'), findsNothing);

    await tester.tap(find.byTooltip('更新を確認'));
    await tester.pumpAndSettle();

    expect(find.text('更新のある巻が 1 巻あります'), findsOneWidget);
    expect(find.textContaining('・更新あり'), findsWidgets);
  });

  testWidgets('複数削除の途中で画面を離れても、選んだ巻はすべて削除し、結果を知らせる', (tester) async {
    final gate = Completer<void>();
    final queue = StubDownloadQueue(
      initial: {340: installed(340), 341: installed(341), 342: installed(342)},
      applyRemovals: true,
    )..onRemove = (volumeId) => volumeId == 340 ? gate.future : Future.value();
    final gateway = FakeOfflineMetadataGateway();
    final container = createContainer(
      downloadQueue: () => queue,
      offlineMetadata: gateway,
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DownloadManagerScreen(),
                  ),
                ),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('選択'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('すべて選択'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '削除'));
    await tester.pump();
    expect(queue.removed, isEmpty, reason: '1 巻目の削除が止まっている');

    // 削除の途中で戻る。
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(DownloadManagerScreen), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(queue.removed, [340, 341, 342], reason: '確定した削除を途中で止めない');
    expect(gateway.pruneCount, 1);
    expect(find.text('3 巻（3.0 MB）を削除しました'), findsOneWidget);
  });

  testWidgets('「更新を確認」の最中は押し直せず、問い合わせも SnackBar も 1 回だけ', (tester) async {
    final gate = Completer<void>();
    final api = FakeBooksApi(bookDetail: titleDetail(volumes: {340: (1, 1)}))
      ..onFetchBookDetail = (_) => gate.future;
    await pumpManager(
      tester,
      ledger: {340: installed(340)},
      offline: FakeOfflineMetadataGateway(
        details: {
          12: titleDetail(volumes: {340: (1, 1)}),
        },
      ),
      booksApi: api,
    );

    await tester.tap(find.byTooltip('更新を確認'));
    await tester.pump();
    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.sync),
    );
    expect(button.onPressed, isNull, reason: '確認中に押し直させない');
    // プルして更新も重ねる。
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    gate.complete();
    await tester.pumpAndSettle();

    expect(api.fetchBookDetailCalls, [12]);
    expect(find.text('更新のある巻はありません'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.sync))
          .onPressed,
      isNotNull,
    );
  });
}
