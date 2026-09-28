import 'package:comic_laz/core/device/reading_screen_mode.dart';
import 'package:comic_laz/core/device/screen_wake_lock.dart';
import 'package:comic_laz/features/viewer/application/viewer_controller.dart';
import 'package:comic_laz/features/viewer/data/progress_recorder.dart';
import 'package:comic_laz/features/viewer/presentation/viewer_screen.dart';
import 'package:comic_laz/features/viewer/presentation/widgets/viewer_chrome.dart';
import 'package:comic_laz/features/viewer/presentation/widgets/viewer_page_image.dart';
import 'package:comic_laz/features/viewer/presentation/widgets/volume_end_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';
import '../../support/test_scope.dart';
import '../../support/viewer_fakes.dart';
import 'viewer_controller_test.dart' show volumeFixture;

/// 描画されたページ URL（先読みと区別して記録する）。
final rendered = <Uri>[];
final prefetched = <Uri>[];

Future<
  ({
    ProviderContainer container,
    RecordingProgressRecorder recorder,
    FakeScreenWakeLock wakeLock,
    ReadingScreenMode screenMode,
  })
>
pumpViewer(
  WidgetTester tester, {
  FakeBooksApi? booksApi,
  int pageCount = 5,
  int? nextVolumeId = 341,
  ViewerImageBuilder? imageBuilder,
}) async {
  rendered.clear();
  prefetched.clear();
  final recorder = RecordingProgressRecorder();
  final wakeLock = FakeScreenWakeLock();
  final screenMode = ReadingScreenMode(wakeLock);

  final container = ProviderContainer(
    overrides: [
      ...testOverrides(
        booksApi:
            booksApi ??
            FakeBooksApi(
              readVolume: volumeFixture(
                pageCount: pageCount,
                nextVolumeId: nextVolumeId,
              ),
            ),
        viewerImageBuilder:
            imageBuilder ??
            (context, url, headers, onRetry) {
              rendered.add(url);
              return const ColoredBox(color: Colors.grey);
            },
        pagePrecacher: (context, url, headers) async {
          prefetched.add(url);
        },
      ),
      progressRecorderProvider.overrideWithValue(recorder),
      screenWakeLockProvider.overrideWithValue(wakeLock),
      readingScreenModeProvider.overrideWithValue(screenMode),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ViewerScreen(volumeId: 340)),
    ),
  );
  await tester.pumpAndSettle();
  return (
    container: container,
    recorder: recorder,
    wakeLock: wakeLock,
    screenMode: screenMode,
  );
}

ViewerState stateOf(ProviderContainer container) =>
    container.read(viewerControllerProvider(340)).value!;

/// 画面幅に対する比率 [ratio] の位置をタップする（0.1 = 左端 = 次ページ）。
Future<void> tapZone(WidgetTester tester, double ratio) async {
  final size = tester.getSize(find.byType(MaterialApp));
  await tester.tapAt(Offset(size.width * ratio, size.height / 2));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('RTL の PageView でページを表示する', (tester) async {
    await pumpViewer(tester);

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.reverse, isTrue, reason: '右 → 左に読む');
    expect(find.byType(ViewerPageImage), findsWidgets);
  });

  testWidgets('左タップで次 / 右タップで前のページへ', (tester) async {
    final app = await pumpViewer(tester);

    await tapZone(tester, 0.1);
    expect(stateOf(app.container).currentPage, 2);

    await tapZone(tester, 0.9);
    expect(stateOf(app.container).currentPage, 1);
  });

  testWidgets('中央タップでメニューを開閉する', (tester) async {
    final app = await pumpViewer(tester);
    expect(find.byType(ViewerHeader), findsNothing);

    await tapZone(tester, 0.5);

    expect(find.byType(ViewerHeader), findsOneWidget);
    expect(find.byType(ViewerFooter), findsOneWidget);
    expect(find.text('1 / 6'), findsOneWidget, reason: '巻末オーバーレイを含む総数');

    await tapZone(tester, 0.5);
    expect(find.byType(ViewerHeader), findsNothing);
    expect(stateOf(app.container).currentPage, 1, reason: 'メニュー操作でページは動かない');
  });

  testWidgets('シークバーでページを移動できる', (tester) async {
    final app = await pumpViewer(tester);
    await tapZone(tester, 0.5);

    // RTL なので左へドラッグすると先のページへ進む
    await tester.drag(find.byType(Slider), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(stateOf(app.container).currentPage, greaterThan(1));
  });

  testWidgets('最終ページの次は巻末オーバーレイ', (tester) async {
    final app = await pumpViewer(tester);

    app.container.read(viewerControllerProvider(340).notifier).setPage(6);
    await tester.pumpAndSettle();

    expect(find.byType(VolumeEndOverlay), findsOneWidget);
    expect(find.text('3 巻を読み終わりました'), findsOneWidget);
    expect(find.text('次の巻を読む'), findsOneWidget);
    // オーバーレイ上ではページ送りのタップ領域が無い
    await tapZone(tester, 0.1);
    expect(stateOf(app.container).currentPage, 6, reason: 'ページ送りにならない');
  });

  testWidgets('次の巻が無ければ案内だけ出す', (tester) async {
    final app = await pumpViewer(tester, nextVolumeId: null);

    app.container.read(viewerControllerProvider(340).notifier).setPage(6);
    await tester.pumpAndSettle();

    expect(find.text('次の巻を読む'), findsNothing);
    expect(find.text('次の巻はまだありません'), findsOneWidget);
  });

  testWidgets('先読みは現在ページの前後に限る', (tester) async {
    await pumpViewer(tester, pageCount: 20);

    expect(prefetched, hasLength(4), reason: '現在 + 後 3');
    expect(
      prefetched.map((url) => url.path),
      containsAll([
        '/books/view/340/1',
        '/books/view/340/2',
        '/books/view/340/3',
        '/books/view/340/4',
      ]),
    );
    // ページ URL には必ず files_version が付く
    expect(prefetched.first.queryParameters['v'], '1758763245');
  });

  testWidgets('ページ画像の失敗は再読み込みできる（タップ領域に邪魔されない）', (tester) async {
    // 実際のエラー表示と同じく中央にボタンを置いたスタブ
    await pumpViewer(
      tester,
      imageBuilder: (context, url, headers, onRetry) {
        rendered.add(url);
        return ColoredBox(
          color: Colors.grey,
          child: Center(
            child: TextButton(onPressed: onRetry, child: const Text('再読み込み')),
          ),
        );
      },
    );

    final before = rendered.length;
    await tester.tap(find.text('再読み込み').first);
    await tester.pumpAndSettle();

    expect(rendered.length, greaterThan(before), reason: '画像を作り直す');
  });

  testWidgets('ページが 0 枚の巻は案内を出す', (tester) async {
    await pumpViewer(
      tester,
      booksApi: FakeBooksApi(
        readVolume: volumeFixture(pageCount: 0, filesVersion: null),
      ),
    );

    expect(find.text('この巻のページが見つかりませんでした'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('ZIP が無い巻（files はあるが files_version が無い）も案内を出す', (tester) async {
    // ローディング表示のまま固まらないこと
    await pumpViewer(
      tester,
      booksApi: FakeBooksApi(
        readVolume: volumeFixture(pageCount: 20, filesVersion: null),
      ),
    );

    expect(find.text('この巻のページが見つかりませんでした'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('先読みは表示と同じページ識別子の URL を温める', (tester) async {
    await pumpViewer(
      tester,
      booksApi: FakeBooksApi(
        readVolume: volumeFixture(pageCount: 5)
            .copyWith(files: [11, 12, 13, 14, 15]),
      ),
    );

    expect(
      prefetched.map((url) => url.path),
      containsAll([
        '/books/view/340/11',
        '/books/view/340/12',
        '/books/view/340/13',
        '/books/view/340/14',
      ]),
      reason: '位置番号ではなく files の値で URL を組み立てる',
    );
  });

  testWidgets('読み込み失敗は理由を出して再試行できる', (tester) async {
    final api = FakeBooksApi();
    await pumpViewer(tester, booksApi: api);

    expect(find.text('お探しのデータは見つかりませんでした。'), findsOneWidget);
    expect(find.byTooltip('閉じる'), findsOneWidget, reason: '行き止まりにしない');

    api.readVolume = volumeFixture();
    await tester.tap(find.widgetWithText(OutlinedButton, '再試行'));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('表示中は読書モード（全画面 + スリープ抑止）にする', (tester) async {
    final app = await pumpViewer(tester);
    expect(app.screenMode.activeCount, 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    expect(app.screenMode.activeCount, 0, reason: '離れたら解除する');
  });

  testWidgets('閉じるときに進捗を送る（ページ送りでは送らない）', (tester) async {
    final app = await pumpViewer(tester);

    app.container.read(viewerControllerProvider(340).notifier).setPage(4);
    await tester.pumpAndSettle();
    expect(app.recorder.records, isEmpty, reason: 'ページ送りでは送らない');

    // メニューの「閉じる」から離脱する
    await tapZone(tester, 0.5);
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();

    expect(app.recorder.records.single.currentPage, 4);
  });

  testWidgets('通信エラーでも読書は続けられる', (tester) async {
    final app = await pumpViewer(tester);
    app.recorder.succeeds = false;

    app.container.read(viewerControllerProvider(340).notifier).setPage(3);
    await app.container
        .read(viewerControllerProvider(340).notifier)
        .flushProgress();
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(stateOf(app.container).currentPage, 3);
  });
}
