import 'dart:async';

import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/features/downloads/application/auto_delete_runner.dart';
import 'package:comic_laz/features/downloads/application/auto_delete_settings.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/progress/domain/reading_progress.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/cache_fakes.dart';
import '../../support/progress_fakes.dart';
import '../../support/storage_fakes.dart';
import '../../support/test_scope.dart';

VolumeDownload _completed(int volumeId, {int bookId = 7, int bytes = 100}) =>
    VolumeDownload(
      volumeId: volumeId,
      bookId: bookId,
      filesVersion: 5,
      status: VolumeDownloadStatus.completed,
      pageCount: 10,
      receivedBytes: bytes,
      totalBytes: bytes,
    );

const _finished7 = AutoDeleteSettings(finished: FinishedRetention.days7);

/// 自動削除を動かす一式（台帳・進捗・控え・時計・前面復帰はすべてフェイク）。
class _Harness {
  _Harness({
    Map<int, VolumeDownload> ledger = const {},
    this.settings = _finished7,
    Iterable<ReadingProgress> progress = const [],
    Set<int> failingRemovals = const {},
  }) : queue = RecordingDownloadQueue(
         initial: ledger,
         failingRemovals: failingRemovals,
       ),
       progress = InMemoryProgressStore(progress) {
    database = AppDatabase(NativeDatabase.memory());
    store = AutoDeleteSettingsStore(database);
    addTearDown(database.close);
  }

  final AutoDeleteSettings settings;
  final RecordingDownloadQueue queue;
  final InMemoryProgressStore progress;
  final gateway = RecordingOfflineMetadataGateway();
  final lifecycle = FakeAppResumeMonitor();
  final clock = TestClock(DateTime.utc(2026, 9, 30, 12));
  final open = <int>{};
  late final AppDatabase database;
  late final AutoDeleteSettingsStore store;

  ProviderContainer container() {
    final container = createContainer(
      downloadQueue: () => queue,
      progressStore: progress,
      offlineMetadata: gateway,
      autoDeleteSettings: () => StubAutoDeleteSettingsController(settings),
      openVolumeCheck: open.contains,
      appResumeMonitor: lifecycle,
      overrides: [
        autoDeleteClockProvider.overrideWithValue(clock.now),
        autoDeleteSettingsStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// 読み終えた（最後のページまで進んだ）進捗。
  static ReadingProgress finishedAt(int volumeId, DateTime readAt) =>
      ReadingProgress(
        volumeId: volumeId,
        currentPage: 10,
        maxPage: 10,
        readAt: readAt,
      );
}

final _longAgo = DateTime.utc(2026, 1, 1);

void main() {
  test('起動時は台帳を読み終えてから 1 回走る（読み込み中に「空」と判断しない）', () async {
    final harness = _Harness(
      ledger: {1: _completed(1)},
      progress: [_Harness.finishedAt(1, _longAgo)],
    );
    harness.queue.buildGate = Completer<void>();
    final container = harness.container();

    container.read(autoDeleteRunnerProvider);
    await pumpEventQueue();
    expect(harness.queue.removed, isEmpty);
    expect(harness.gateway.readDetails, isEmpty);

    harness.queue.buildGate!.complete();
    await pumpEventQueue();

    expect(harness.queue.removed, [1]);
    expect(harness.gateway.readDetails, [7], reason: '起動時の 1 回だけ');
  });

  // 取り直しの中断は台帳を旧世代の完了に戻すので、完了行だけを見ると
  // 候補に入る。消すと取り直しの続き（再開データ）と旧世代がまとめて失われる。
  test('「更新あり」の取り直しを中断した巻は期限切れでも消さない', () async {
    final harness = _Harness(
      ledger: {1: _completed(1), 2: _completed(2)},
      progress: [
        _Harness.finishedAt(1, _longAgo),
        _Harness.finishedAt(2, _longAgo),
      ],
    );
    harness.queue.pendingTransfers.add(1);
    final container = harness.container();

    container.read(autoDeleteRunnerProvider);
    await pumpEventQueue();

    expect(harness.queue.removed, [2]);
  });

  test('設定がすべてオフなら台帳も控えも読まない', () async {
    final harness = _Harness(
      ledger: {1: _completed(1)},
      settings: const AutoDeleteSettings(),
      progress: [_Harness.finishedAt(1, _longAgo)],
    );
    final container = harness.container();

    container.read(autoDeleteRunnerProvider);
    await pumpEventQueue();

    expect(harness.queue.builds, 0);
    expect(harness.gateway.readDetails, isEmpty);
    expect(harness.queue.removed, isEmpty);
  });

  test('前面復帰で走るが、1 時間以内には走り直さない（復帰のたびに全タイトルの控えを読まない）', () async {
    // 一度も開いていない巻なので消えない（読んだ回数だけを見る）。
    final harness = _Harness(ledger: {1: _completed(1)});
    final container = harness.container();
    container.read(autoDeleteRunnerProvider);
    await pumpEventQueue();
    expect(harness.gateway.readDetails, hasLength(1));

    harness.clock.advance(const Duration(minutes: 59));
    harness.lifecycle.resume();
    await pumpEventQueue();
    expect(harness.gateway.readDetails, hasLength(1));

    harness.clock.advance(const Duration(minutes: 1));
    harness.lifecycle.resume();
    await pumpEventQueue();
    expect(harness.gateway.readDetails, hasLength(2));
  });

  test('設定を変えた直後は間引かずに走る', () async {
    final harness = _Harness(ledger: {1: _completed(1)});
    final container = harness.container();
    container.read(autoDeleteRunnerProvider);
    await pumpEventQueue();

    await container
        .read(autoDeleteRunnerProvider.notifier)
        .run(AutoDeleteTrigger.settingsChanged);

    expect(harness.gateway.readDetails, hasLength(2));
  });

  test('削除の直前にビューアで開かれた巻は消さない', () async {
    final harness = _Harness(
      ledger: {1: _completed(1), 2: _completed(2)},
      progress: [
        _Harness.finishedAt(1, _longAgo),
        _Harness.finishedAt(2, _longAgo),
      ],
    );
    // 1 巻目を消している間に 2 巻目がビューアで開かれる。
    harness.queue.beforeRemove = (volumeId) async {
      if (volumeId == 1) harness.open.add(2);
    };
    final container = harness.container();

    container.read(autoDeleteRunnerProvider);
    await pumpEventQueue();

    expect(harness.queue.removed, [1]);
    expect(container.read(autoDeleteRunnerProvider)?.volumes, 1);
  });

  test('消したら控えの掃除と結果の記録をする（設定画面で「前回の自動削除」として見せる）', () async {
    final harness = _Harness(
      ledger: {1: _completed(1, bytes: 300), 2: _completed(2, bytes: 200)},
      progress: [
        _Harness.finishedAt(1, _longAgo),
        _Harness.finishedAt(2, _longAgo),
      ],
    );
    final container = harness.container();

    container.read(autoDeleteRunnerProvider);
    await pumpEventQueue();

    final expected = AutoDeleteResult(
      at: harness.clock.now(),
      volumes: 2,
      bytes: 500,
    );
    expect(harness.gateway.pruneCount, 1);
    expect(await harness.store.readLastResult(), expected);
    expect(container.read(autoDeleteRunnerProvider), expected);
    expect(await container.read(autoDeleteLastResultProvider.future), expected);
  });

  test('何も消さなければ控えの掃除も結果の記録もしない', () async {
    final harness = _Harness(ledger: {1: _completed(1)});
    final container = harness.container();

    container.read(autoDeleteRunnerProvider);
    await pumpEventQueue();

    expect(harness.gateway.pruneCount, 0);
    expect(await harness.store.readLastResult(), isNull);
  });

  test('1 巻の削除に失敗しても残りは続け、消せた分だけ記録する', () async {
    final harness = _Harness(
      ledger: {1: _completed(1), 2: _completed(2)},
      progress: [
        _Harness.finishedAt(1, _longAgo),
        _Harness.finishedAt(2, _longAgo),
      ],
      failingRemovals: {1},
    );
    final container = harness.container();

    container.read(autoDeleteRunnerProvider);
    await pumpEventQueue();

    expect(harness.queue.removed, [2]);
    expect((await harness.store.readLastResult())?.volumes, 1);
  });

  test('他端末で読了した巻は初めて気づいた時刻を保存し、その回は消さない', () async {
    final harness = _Harness(ledger: {1: _completed(1)});
    harness.gateway.details[7] = finishedDetail(7, volumes: {1: true});
    final container = harness.container();

    container.read(autoDeleteRunnerProvider);
    await pumpEventQueue();

    expect(harness.queue.removed, isEmpty);
    expect(await harness.store.readFinishedSeen(), {1: harness.clock.now()});
  });
}
