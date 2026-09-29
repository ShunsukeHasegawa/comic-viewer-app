import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/read_volume.dart';
import 'package:comic_laz/features/history/application/history_controller.dart';
import 'package:comic_laz/features/viewer/application/viewer_controller.dart';
import 'package:comic_laz/features/viewer/data/progress_recorder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';
import '../../support/test_scope.dart';
import '../../support/viewer_fakes.dart';

ReadVolume volumeFixture({
  int pageCount = 5,
  int currentPage = 1,
  int? nextVolumeId = 341,
  int? filesVersion = 1758763245,
}) => ReadVolume(
  id: 340,
  volume: 3,
  currentPage: currentPage,
  nextVolumeId: nextVolumeId,
  nextVolumeThumbnail: '/books/thumbnail/341?m=1',
  files: [for (var i = 1; i <= pageCount; i++) i],
  filesVersion: filesVersion,
  book: const Book(id: 12, title: '進撃の巨人'),
);

({ProviderContainer container, RecordingProgressRecorder recorder}) build({
  ReadVolume? volume,
  bool recordFails = false,

  /// まだ送れていないローカル進捗（巻 ID → ページ）。
  Map<int, int> unsyncedPages = const {},

  /// ローカル進捗の読み出しで投げる例外（ローカル DB が読めない状況）。
  Object? unsyncedPageError,
}) {
  final recorder = RecordingProgressRecorder(succeeds: !recordFails)
    ..unsyncedPages.addAll(unsyncedPages)
    ..unsyncedPageError = unsyncedPageError;
  final container = ProviderContainer(
    overrides: [
      ...testOverrides(
        booksApi: FakeBooksApi(readVolume: volume ?? volumeFixture()),
      ),
      progressRecorderProvider.overrideWithValue(recorder),
    ],
  );
  addTearDown(container.dispose);
  // 画面が表示している状態を模す（購読が無いと autoDispose で即破棄される）。
  final sub = container.listen(viewerControllerProvider(340), (_, _) {});
  addTearDown(sub.close);
  return (container: container, recorder: recorder);
}

void main() {
  group('読み込み', () {
    test('前回の続きのページから開く', () async {
      final fixture = build(volume: volumeFixture(currentPage: 3));

      final state = await fixture.container.read(
        viewerControllerProvider(340).future,
      );

      expect(state.currentPage, 3);
      expect(state.pageCount, 5);
      expect(state.slideCount, 6, reason: '巻末オーバーレイを含む');
      expect(state.hasNextVolume, isTrue);
    });

    test('未送信のローカル進捗があればサーバーの値より優先する', () async {
      // 圏外で読み進めた分がサーバーに届いていない状態で開き直したとき、
      // サーバーの古いページから再開すると手元の進捗が巻き戻る（#12）。
      final fixture = build(
        volume: volumeFixture(currentPage: 2),
        unsyncedPages: const {340: 4},
      );

      final state = await fixture.container.read(
        viewerControllerProvider(340).future,
      );

      expect(state.currentPage, 4);
    });

    test('サーバー由来のページ番号が範囲外でも丸める', () async {
      final fixture = build(volume: volumeFixture(currentPage: 99));

      final state = await fixture.container.read(
        viewerControllerProvider(340).future,
      );

      expect(state.currentPage, 5);
    });

    test('ページが 0 枚の巻でも落ちない', () async {
      final fixture = build(
        volume: volumeFixture(pageCount: 0, filesVersion: null),
      );

      final state = await fixture.container.read(
        viewerControllerProvider(340).future,
      );

      expect(state.pageCount, 0);
      expect(state.slideCount, 0);
      expect(state.currentPage, 1);
    });

    test('ローカル進捗が読めなくても巻は開ける', () async {
      // DB の破損やマイグレーション失敗でローカル進捗が読めないだけで、巻が
      // 取れているなら読書は続けられるようにする。ここで throw すると build() が
      // 失敗して「読み込みに失敗しました」のまま、どの巻も開けなくなる
      // （一覧側の `LibraryController._localProgress` と同じ扱い）。
      final fixture = build(
        volume: volumeFixture(currentPage: 3),
        unsyncedPageError: StateError('ローカル DB が読めない'),
      );

      final state = await fixture.container.read(
        viewerControllerProvider(340).future,
      );

      expect(state.currentPage, 3, reason: 'サーバーの値で開く');
    });

    test('削除済みの巻は 404 として伝わる', () async {
      final container = ProviderContainer(
        overrides: testOverrides(booksApi: FakeBooksApi()),
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(viewerControllerProvider(340).future),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('ページ送り', () {
    test('次 / 前へ動き、範囲外にはいかない', () async {
      final fixture = build(volume: volumeFixture(currentPage: 1));
      final notifier = fixture.container.read(
        viewerControllerProvider(340).notifier,
      );
      await fixture.container.read(viewerControllerProvider(340).future);

      notifier.goToPreviousPage();
      expect(
        fixture.container
            .read(viewerControllerProvider(340))
            .value!
            .currentPage,
        1,
      );

      for (var i = 0; i < 10; i++) {
        notifier.goToNextPage();
      }
      final state = fixture.container
          .read(viewerControllerProvider(340))
          .value!;
      expect(state.currentPage, 6, reason: '巻末オーバーレイまで');
      expect(state.isAtVolumeEnd, isTrue);
    });

    test('ページ送りのたびに端末へ保存する', () async {
      // 「OS にアプリを落とされてもページ送りが残る」という #12 の目的は、この
      // 呼び出しだけで成り立っている。外れても送信側のテストは全部通るので、
      // ここで配線そのものを見る。
      final fixture = build(volume: volumeFixture(currentPage: 1));
      final notifier = fixture.container.read(
        viewerControllerProvider(340).notifier,
      );
      await fixture.container.read(viewerControllerProvider(340).future);

      notifier.goToNextPage();
      notifier.goToNextPage();
      // 巻末オーバーレイ（最終ページ + 1）まで送る。
      notifier.setPage(6);
      await pumpEventQueue();

      expect(
        [for (final save in fixture.recorder.saved) save.currentPage],
        [2, 3, 5],
        reason: '巻末オーバーレイの番号は保存しない',
      );
      expect(fixture.recorder.records, isEmpty, reason: 'ページ送りでは送らない');
    });

    test('シークバーからの移動も丸める', () async {
      final fixture = build();
      final notifier = fixture.container.read(
        viewerControllerProvider(340).notifier,
      );
      await fixture.container.read(viewerControllerProvider(340).future);

      notifier.setPage(100);
      expect(
        fixture.container
            .read(viewerControllerProvider(340))
            .value!
            .currentPage,
        6,
      );
      notifier.setPage(-5);
      expect(
        fixture.container
            .read(viewerControllerProvider(340))
            .value!
            .currentPage,
        1,
      );
    });

    test('メニューの表示を切り替えられる', () async {
      final fixture = build();
      final notifier = fixture.container.read(
        viewerControllerProvider(340).notifier,
      );
      await fixture.container.read(viewerControllerProvider(340).future);

      notifier.toggleMenu();
      expect(
        fixture.container
            .read(viewerControllerProvider(340))
            .value!
            .isMenuVisible,
        isTrue,
      );
      notifier.hideMenu();
      expect(
        fixture.container
            .read(viewerControllerProvider(340))
            .value!
            .isMenuVisible,
        isFalse,
      );
    });
  });

  group('進捗の記録', () {
    test('ページ送りのたびには送らない', () async {
      final fixture = build();
      final notifier = fixture.container.read(
        viewerControllerProvider(340).notifier,
      );
      await fixture.container.read(viewerControllerProvider(340).future);

      notifier.goToNextPage();
      notifier.goToNextPage();
      await pumpEventQueue();

      expect(fixture.recorder.records, isEmpty, reason: 'HDD への書き込みを抑える');
    });

    test('flush でまとめて送る', () async {
      final fixture = build();
      final notifier = fixture.container.read(
        viewerControllerProvider(340).notifier,
      );
      await fixture.container.read(viewerControllerProvider(340).future);

      notifier.goToNextPage();
      notifier.goToNextPage();
      await notifier.flushProgress();

      expect(fixture.recorder.records, hasLength(1));
      expect(fixture.recorder.records.single.currentPage, 3);
      expect(fixture.recorder.records.single.maxPage, 5);
      expect(fixture.recorder.records.single.volumeId, 340);
    });

    test('巻末オーバーレイの番号は保存しない', () async {
      final fixture = build();
      final notifier = fixture.container.read(
        viewerControllerProvider(340).notifier,
      );
      await fixture.container.read(viewerControllerProvider(340).future);

      notifier.setPage(6);
      await notifier.flushProgress();

      expect(fixture.recorder.records.single.currentPage, 5);
    });

    test('同じページを繰り返し送らない', () async {
      final fixture = build();
      final notifier = fixture.container.read(
        viewerControllerProvider(340).notifier,
      );
      await fixture.container.read(viewerControllerProvider(340).future);

      notifier.goToNextPage();
      await notifier.flushProgress();
      await notifier.flushProgress();

      expect(fixture.recorder.records, hasLength(1));
    });

    test('開いたページのままなら送らない', () async {
      final fixture = build(volume: volumeFixture(currentPage: 3));
      final notifier = fixture.container.read(
        viewerControllerProvider(340).notifier,
      );
      await fixture.container.read(viewerControllerProvider(340).future);

      await notifier.flushProgress();

      expect(fixture.recorder.records, isEmpty);
    });

    test('ページ 0 枚の巻は送らない', () async {
      final fixture = build(
        volume: volumeFixture(pageCount: 0, filesVersion: null),
      );
      final notifier = fixture.container.read(
        viewerControllerProvider(340).notifier,
      );
      await fixture.container.read(viewerControllerProvider(340).future);

      notifier.setPage(1);
      await notifier.flushProgress();

      expect(fixture.recorder.records, isEmpty);
    });

    test('送信に失敗したら次の機会に送り直す', () async {
      final fixture = build(recordFails: true);
      final notifier = fixture.container.read(
        viewerControllerProvider(340).notifier,
      );
      await fixture.container.read(viewerControllerProvider(340).future);

      notifier.goToNextPage();
      await notifier.flushProgress();
      await notifier.flushProgress();

      expect(fixture.recorder.records, hasLength(2), reason: '失敗は記録済みにしない');
    });

    test('画面を閉じる（dispose）と送る', () async {
      final recorder = RecordingProgressRecorder();
      final container = ProviderContainer(
        overrides: [
          ...testOverrides(booksApi: FakeBooksApi(readVolume: volumeFixture())),
          progressRecorderProvider.overrideWithValue(recorder),
        ],
      );
      final sub = container.listen(viewerControllerProvider(340), (_, _) {});
      await container.read(viewerControllerProvider(340).future);
      container.read(viewerControllerProvider(340).notifier).setPage(4);

      sub.close();
      container.dispose();
      await pumpEventQueue();

      expect(recorder.records.single.currentPage, 4);
    });
  });

  group('進捗の反映', () {
    test('送信に成功したら表示中の画面を作り直す', () async {
      final fixture = build();
      final notifier = fixture.container.read(
        viewerControllerProvider(340).notifier,
      );
      await fixture.container.read(viewerControllerProvider(340).future);

      // 履歴画面を表示している状態にする
      final historySub = fixture.container.listen(
        historyControllerProvider,
        (_, _) {},
      );
      addTearDown(historySub.close);
      await fixture.container.read(historyControllerProvider.future);

      notifier.setPage(4);
      await notifier.flushProgress();
      await pumpEventQueue();

      // 作り直されるので読み込み直しが走る
      expect(
        fixture.container.read(historyControllerProvider),
        isA<AsyncValue<HistoryState>>(),
      );
    });
  });

  group('次の巻へ', () {
    test('進捗を送ってから巻 ID を返す', () async {
      final fixture = build();
      final notifier = fixture.container.read(
        viewerControllerProvider(340).notifier,
      );
      await fixture.container.read(viewerControllerProvider(340).future);
      notifier.setPage(5);

      final nextVolumeId = await notifier.moveToNextVolume();

      expect(nextVolumeId, 341);
      expect(fixture.recorder.records.single.currentPage, 5);
    });

    test('次の巻が無ければ null', () async {
      final fixture = build(volume: volumeFixture(nextVolumeId: null));
      final notifier = fixture.container.read(
        viewerControllerProvider(340).notifier,
      );
      await fixture.container.read(viewerControllerProvider(340).future);

      expect(await notifier.moveToNextVolume(), isNull);
    });
  });
}
