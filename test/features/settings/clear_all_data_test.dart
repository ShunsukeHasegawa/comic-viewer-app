import 'dart:io';

import 'package:comic_laz/core/cache/image_cache_store.dart';
import 'package:comic_laz/core/cache/memory_image_cache.dart';
import 'package:comic_laz/features/downloads/application/auto_delete_runner.dart';
import 'package:comic_laz/features/downloads/application/auto_delete_settings.dart';
import 'package:comic_laz/features/downloads/application/download_queue.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/progress/domain/reading_progress.dart';
import 'package:comic_laz/features/settings/application/clear_all_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/cache_fakes.dart';
import '../../support/progress_fakes.dart';
import '../../support/storage_fakes.dart';
import '../../support/test_scope.dart';

const _download = VolumeDownload(
  volumeId: 1,
  bookId: 7,
  filesVersion: 5,
  status: VolumeDownloadStatus.completed,
  pageCount: 10,
  receivedBytes: 100,
  totalBytes: 100,
);

class _Harness {
  _Harness({ImageCacheStore Function(CacheHarness cache)? store}) {
    cache = CacheHarness.create();
    _store = store?.call(cache);
  }

  late final CacheHarness cache;
  ImageCacheStore? _store;
  final queue = RecordingDownloadQueue(initial: {1: _download});
  final gateway = RecordingOfflineMetadataGateway();
  final authStore = FakeAuthStore(token: 'token-1');
  final progress = InMemoryProgressStore([
    // サーバーへまだ送れていない進捗（失うと戻らない）。
    ReadingProgress(
      volumeId: 1,
      currentPage: 5,
      maxPage: 10,
      readAt: DateTime.utc(2026, 9, 30),
    ),
  ]);
  var memoryClears = 0;

  ProviderContainer container() {
    final container = createContainer(
      authStore: authStore,
      downloadQueue: () => queue,
      offlineMetadata: gateway,
      progressStore: progress,
      overrides: [
        ...cache.overrides(store: _store),
        memoryImageCacheClearerProvider.overrideWithValue(() => memoryClears++),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }
}

void main() {
  test('ダウンロード・一時キャッシュ・メモリ上の画像を消し、未送信の読書進捗は残す（サーバーにも無いため）', () async {
    final harness = _Harness();
    await harness.cache.record('v1/100/1', bytes: 64);
    await AutoDeleteSettingsStore(harness.cache.database)
        .writeFinishedSeen({1: DateTime.utc(2026, 9, 1)});
    final container = harness.container();
    await container.read(downloadQueueProvider.future);

    final error = await container.read(clearAllDataProvider)();

    expect(error, isNull);
    expect(harness.queue.purgeCount, 1);
    expect(container.read(downloadQueueProvider).value, isEmpty);
    expect((await harness.cache.store.usage()).totalCount, 0);
    expect(harness.memoryClears, 1, reason: 'ディスクだけ消すと表示中の画像が残る');
    expect(harness.gateway.pruneCount, 1, reason: 'ダウンロードが無くなったタイトルの控えを捨てる');
    expect(
      await AutoDeleteSettingsStore(harness.cache.database).readFinishedSeen(),
      isEmpty,
    );
    expect(await harness.progress.find(1), isNotNull);
  });

  test('途中の手順が失敗しても残りは実行して、最初のエラーを返す', () async {
    final harness = _Harness(
      store: (cache) => cache.storeLike(FailingClearCacheStore.new),
    );
    const purgeError = FileSystemException('ダウンロードを消せません');
    harness.queue.purgeError = purgeError;
    final container = harness.container();

    final error = await container.read(clearAllDataProvider)();

    expect(error, purgeError);
    expect(harness.memoryClears, 1, reason: 'キャッシュの削除に失敗してもメモリの画像は捨てる');
    expect(harness.gateway.pruneCount, 1);
  });

  test('ログアウトはしない（ログイン状態は残す）', () async {
    final harness = _Harness();
    final container = harness.container();

    await container.read(clearAllDataProvider)();

    expect(harness.authStore.token, 'token-1');
    expect(harness.authStore.clearCount, 0);
  });

  test('自動削除の記録（気づいた時刻・前回の結果）も消し、表示中の「前回の自動削除」も消える', () async {
    final harness = _Harness();
    final records = AutoDeleteSettingsStore(harness.cache.database);
    await records.writeFinishedSeen({1: DateTime.utc(2026, 9, 1)});
    await records.writeLastResult(
      AutoDeleteResult(at: DateTime.utc(2026, 9, 29), volumes: 3, bytes: 300),
    );
    final container = harness.container();
    final subscription = container.listen(
      autoDeleteLastResultProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    expect(
      await container.read(autoDeleteLastResultProvider.future),
      isNotNull,
    );

    await container.read(clearAllDataProvider)();

    expect(await records.readFinishedSeen(), isEmpty);
    expect(await records.readLastResult(), isNull);
    expect(
      await container.read(autoDeleteLastResultProvider.future),
      isNull,
      reason: '0 巻の横に消えたはずの記録を並べない',
    );
  });
}
