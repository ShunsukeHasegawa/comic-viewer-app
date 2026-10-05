import 'package:comic_laz/core/cache/comic_image_loader.dart';
import 'package:comic_laz/core/device/reading_screen_mode.dart';
import 'package:comic_laz/core/device/screen_wake_lock.dart';
import 'package:comic_laz/features/viewer/application/viewer_controller.dart';
import 'package:comic_laz/features/viewer/data/progress_recorder.dart';
import 'package:comic_laz/features/viewer/presentation/viewer_screen.dart';
import 'package:comic_laz/features/viewer/presentation/widgets/viewer_chrome.dart';
import 'package:comic_laz/features/viewer/presentation/widgets/viewer_page_image.dart';
import 'package:comic_laz/features/viewer/presentation/widgets/volume_end_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';
import '../../support/test_scope.dart';
import '../../support/viewer_fakes.dart';
import 'viewer_controller_test.dart' show volumeFixture;

/// 描画されたページ URL（先読みと区別して記録する）。
final rendered = <ComicImageRequest>[];
final prefetched = <ComicImageRequest>[];

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
  // ビューアを一覧などの上に push した形で開く（戻る操作を試すため）。
  bool pushed = false,
  // 「読書中は画面を消さない」（#19）。
  bool keepScreenOn = true,
}) async {
  rendered.clear();
  prefetched.clear();
  final recorder = RecordingProgressRecorder();
  final wakeLock = FakeScreenWakeLock();
  final screenMode = ReadingScreenMode(
    wakeLock,
    keepScreenOn: () async => keepScreenOn,
  );

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
            (context, request, onRetry) {
              rendered.add(request);
              return const ColoredBox(color: Colors.grey);
            },
        pagePrecacher: (context, request) async {
          prefetched.add(request);
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
      child: MaterialApp(
        home: pushed
            ? Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ViewerScreen(volumeId: 340),
                    ),
                  ),
                  child: const Text('open'),
                ),
              )
            : const ViewerScreen(volumeId: 340),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (pushed) {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
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

  group('シークバーで遠くへ飛ぶ（#18）', () {
    /// ドラッグの途中（指を離す前）まで進める。
    Future<TestGesture> dragHalfway(WidgetTester tester) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Slider)),
      );
      // RTL なので左へ動かすと先のページ。刻みごとにフレームを回す
      // （実機のドラッグと同じく onChanged が何度も呼ばれる）。
      for (var step = 0; step < 20; step++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump();
      }
      return gesture;
    }

    String pathOf(int page) => '/books/view/340/$page';

    testWidgets('ドラッグ中は番号だけ動き、途中のページを読み込まない', (tester) async {
      // 刻みごとに移動すると、通り過ぎたページを全部（先読みの窓ごと）
      // 自宅サーバーへ要求し、飛び先がその後ろに並んで表示が遅れる。
      final app = await pumpViewer(tester, pageCount: 200);
      await tapZone(tester, 0.5);
      rendered.clear();
      prefetched.clear();
      app.recorder.saved.clear();

      final gesture = await dragHalfway(tester);

      expect(stateOf(app.container).currentPage, 1, reason: 'まだ移動しない');
      expect(rendered, isEmpty, reason: '途中のページを組み立てない');
      expect(prefetched, isEmpty, reason: '途中のページを先読みしない');
      expect(app.recorder.saved, isEmpty, reason: '刻みごとに端末へ書かない');
      expect(
        find.textContaining(RegExp(r'^(?!1 / )\d+ / 201$')),
        findsOneWidget,
        reason: 'ドラッグ中の位置は番号で見せる',
      );

      await gesture.up();
      await tester.pumpAndSettle();

      final target = stateOf(app.container).currentPage;
      expect(target, greaterThan(20), reason: '一気に遠くへ飛んでいる');
      expect(find.text('$target / 201'), findsOneWidget);
      // 元のページ（1）は移動の直前のフレームで組み立て直されるが、同じ画像なので
      // 要求は増えない。間のページを 1 枚も通り過ぎないことを確かめる。
      expect(
        rendered.map((request) => request.url.path).toSet(),
        containsAll([pathOf(target)]),
      );
      expect(
        rendered.map((request) => request.url.path).toSet(),
        everyElement(isIn([pathOf(1), pathOf(target)])),
        reason: '飛び先だけを組み立てる（間のページを通り過ぎない）',
      );
      expect(app.recorder.saved.map((row) => row.currentPage), [target]);
    });

    testWidgets('ドラッグ中にメニューが閉じられても、見せていた番号へ移動する（黙って捨てない）', (tester) async {
      // 別の指で中央をタップするとシークバーごと外れ、Slider は onChangeEnd を
      // 呼ばない。以前は刻みごとに移動していたので、移動が消えるのは退行になる。
      final app = await pumpViewer(tester, pageCount: 200);
      await tapZone(tester, 0.5);
      app.recorder.saved.clear();

      final gesture = await dragHalfway(tester);
      final shown = tester
          .widget<Text>(find.textContaining(RegExp(r'^\d+ / 201$')))
          .data!;
      final draggedTo = int.parse(shown.split(' / ').first);
      expect(draggedTo, greaterThan(1));
      expect(stateOf(app.container).currentPage, 1, reason: 'まだ移動していない');

      app.container.read(viewerControllerProvider(340).notifier).toggleMenu();
      await tester.pumpAndSettle();
      expect(find.byType(ViewerFooter), findsNothing);

      expect(stateOf(app.container).currentPage, draggedTo);
      expect(app.recorder.saved.map((row) => row.currentPage), [draggedTo]);

      // 外れた後に指を離しても、二重に移動したり落ちたりしない。
      await gesture.up();
      await tester.pumpAndSettle();
      expect(stateOf(app.container).currentPage, draggedTo);
    });

    // ドラッグ中に戻ったのなら、確定していない位置を進捗として保存・送信しない
    // （読んでいない数十ページ先まで読書位置が進んでしまう）。
    testWidgets('ドラッグ中にビューアを閉じたら、途中の位置へは移動しない', (tester) async {
      final app = await pumpViewer(tester, pageCount: 200, pushed: true);
      await tapZone(tester, 0.5);
      app.recorder.saved.clear();

      final gesture = await dragHalfway(tester);
      final container = app.container;
      // 閉じる前に購読しておき、ビューアの状態が破棄されずに残る最悪の場合を作る。
      final keep = container.listen(viewerControllerProvider(340), (_, _) {});
      addTearDown(keep.close);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(stateOf(container).currentPage, 1);
      expect(app.recorder.saved, isEmpty);
    });

    testWidgets('離したら飛び先を最初に要求し、先読みの窓を飛び先に置き直す', (tester) async {
      await pumpViewer(tester, pageCount: 200);
      await tapZone(tester, 0.5);
      prefetched.clear();

      final gesture = await dragHalfway(tester);
      await gesture.up();
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ViewerScreen)),
      );
      final target = stateOf(container).currentPage;
      expect(prefetched.map((request) => request.url.path), [
        pathOf(target),
        pathOf(target + 1),
        pathOf(target + 2),
        pathOf(target + 3),
        pathOf(target - 1),
      ], reason: '飛び先 → 周辺の順。元の位置（1-4）の周辺は要求し直さない');
    });
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
      prefetched.map((request) => request.url.path),
      containsAll([
        '/books/view/340/1',
        '/books/view/340/2',
        '/books/view/340/3',
        '/books/view/340/4',
      ]),
    );
    // ページ URL には必ず files_version が付く
    expect(prefetched.first.url.queryParameters['v'], '1758763245');
  });

  testWidgets('ページ画像の失敗は再読み込みできる（タップ領域に邪魔されない）', (tester) async {
    // 実際のエラー表示と同じく中央にボタンを置いたスタブ
    await pumpViewer(
      tester,
      imageBuilder: (context, request, onRetry) {
        rendered.add(request);
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
      prefetched.map((request) => request.url.path),
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

  testWidgets('「読書中は画面を消さない」が OFF でも全画面表示にはする（#19）', (tester) async {
    // 全画面表示の切り替えを記録する（テストのバインディングの疑似メッセンジャー）。
    final uiModes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          uiModes.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final app = await pumpViewer(tester, keepScreenOn: false);

    expect(app.screenMode.activeCount, 1);
    expect(uiModes, ['SystemUiMode.immersiveSticky']);
    expect(app.wakeLock.enableCount, 0, reason: '消灯は端末の設定に任せる');
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
