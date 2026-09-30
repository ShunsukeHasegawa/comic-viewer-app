import 'dart:io';

import 'package:comic_laz/core/cache/cache_settings.dart';
import 'package:comic_laz/core/cache/image_cache_store.dart';
import 'package:comic_laz/core/router/app_routes.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/features/downloads/application/auto_delete_settings.dart';
import 'package:comic_laz/features/downloads/application/download_queue.dart';
import 'package:comic_laz/features/downloads/application/download_settings.dart';
import 'package:comic_laz/features/downloads/data/free_space_probe.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/progress/data/progress_store.dart';
import 'package:comic_laz/features/progress/domain/reading_progress.dart';
import 'package:comic_laz/features/settings/presentation/storage_settings_screen.dart';
import 'package:comic_laz/features/settings/presentation/widgets/auto_delete_section.dart';
import 'package:comic_laz/features/settings/presentation/widgets/storage_usage_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/cache_fakes.dart';
import '../../support/progress_fakes.dart';
import '../../support/storage_fakes.dart';
import '../../support/test_scope.dart';

const _mb = 1024 * 1024;
const _gb = 1024 * _mb;

Future<CacheHarness> pumpScreen(
  WidgetTester tester, {
  CacheHarness? harness,
  ImageCacheStore? store,
  DownloadQueue Function()? downloadQueue,
  DeviceStorageProbe? deviceStorage,
  ProgressStore? progressStore,
  bool withRouter = false,
}) async {
  final cache = harness ?? CacheHarness.create();
  final container = ProviderContainer(
    overrides: [
      ...testOverrides(
        // 「Wi-Fi 接続時のみ」と自動削除の設定も本物の drift に保存させる。
        downloadWifiOnly: DownloadWifiOnly.new,
        autoDeleteSettings: AutoDeleteSettingsController.new,
        downloadQueue: downloadQueue,
        deviceStorageProbe: deviceStorage,
        progressStore: progressStore,
      ),
      ...cache.overrides(store: store),
    ],
  );
  addTearDown(container.dispose);

  // 設定項目が縦に並ぶので、既定の 800x600 では下半分が画面外になる。
  // スクロール操作をテストの本題にしないため、画面を縦長にしておく。
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: withRouter
          ? MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: AppRoutes.storageSettings,
                routes: [
                  GoRoute(
                    path: AppRoutes.storageSettings,
                    builder: (context, state) => const StorageSettingsScreen(),
                  ),
                  GoRoute(
                    path: AppRoutes.downloadManager,
                    builder: (context, state) =>
                        const Scaffold(body: Text('ダウンロード管理（テスト）')),
                  ),
                ],
              ),
            )
          : const MaterialApp(home: StorageSettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return cache;
}

VolumeDownload _completed(int volumeId, {required int bytes}) => VolumeDownload(
  volumeId: volumeId,
  bookId: 7,
  filesVersion: 5,
  status: VolumeDownloadStatus.completed,
  pageCount: 10,
  receivedBytes: bytes,
  totalBytes: bytes,
);

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(StorageSettingsScreen)),
    );

/// [key] の行に [text] が出ているか。
Finder _inTile(Key key, String text) =>
    find.descendant(of: find.byKey(key), matching: find.text(text));

/// 指定したドロップダウンで選択肢を選ぶ。
Future<void> selectOption(
  WidgetTester tester,
  Key dropdown,
  String label,
) async {
  await tester.tap(find.byKey(dropdown));
  await tester.pumpAndSettle();
  // 閉じた DropdownButton も選択肢を組み立てているので、
  // 実際に押せる（= 開いたメニューの）方を選ぶ。
  await tester.tap(find.text(label).hitTestable().last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('一時キャッシュの使用量を種別ごとに表示する', (tester) async {
    final harness = CacheHarness.create();
    await harness.record('v1/100/1', bytes: 3 * _mb);
    await harness.record('t/a/1', bytes: _mb, kind: CachedImageKind.thumbnail);

    await pumpScreen(tester, harness: harness);

    expect(find.text('3.0 MB'), findsOneWidget);
    expect(find.text('1.0 MB'), findsOneWidget);
    expect(find.text('4.0 MB'), findsOneWidget, reason: '合計も出す');
    // ダウンロードが無くても行は出す（0 B = 何も無いことが分かる）。
    expect(find.text('ダウンロード済み'), findsOneWidget);
  });

  testWidgets('上限を下げると超過分が削除され、使用量の表示も減る', (tester) async {
    final harness = CacheHarness.create();
    // 既定の上限（1GB）では消えない量を、古い順が決まるように積む。
    await harness.record('v1/100/1', bytes: 200 * _mb);
    await harness.record(
      'v1/100/2',
      bytes: 200 * _mb,
      after: const Duration(minutes: 1),
    );

    await pumpScreen(tester, harness: harness);
    expect(find.text('400.0 MB'), findsWidgets);

    await selectOption(tester, StorageSettingsScreen.pageLimitKey, '256 MB');

    expect(
      (await harness.store.usage()).pageBytes,
      200 * _mb,
      reason: '上限を超えた分は最後に使ったのが古い方から消える',
    );
    expect(find.text('200.0 MB'), findsWidgets);
    expect(
      (await harness.settingsStore.read()).pageLimit,
      CacheLimit.mb256,
      reason: '次回起動でも同じ上限で動く必要がある',
    );
  });

  testWidgets('「Wi-Fi 接続時のみダウンロード」は既定で ON、切り替えると保存される', (tester) async {
    final harness = await pumpScreen(tester);
    final store = DownloadSettingsStore(harness.database);

    final tile = find.byKey(StorageSettingsScreen.wifiOnlyKey);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    expect(await store.readWifiOnly(), isFalse, reason: 'アプリを開き直しても OFF のまま');
  });

  testWidgets('保持期間を変えると保存される', (tester) async {
    final harness = await pumpScreen(tester);

    await selectOption(tester, StorageSettingsScreen.retentionKey, '7 日');

    expect(
      (await harness.settingsStore.read()).retention,
      CacheRetention.days7,
    );
  });

  testWidgets('「キャッシュを削除」はダウンロード済みデータを消さない', (tester) async {
    final harness = CacheHarness.create();
    // メタ情報だけ積む（ファイル削除まで含めた検証は image_cache_store_test）。
    await harness.record('v1/100/1', bytes: 64);
    await harness.record('t/a/1', bytes: 32, kind: CachedImageKind.thumbnail);
    final downloaded = harness.createDownloadedFile('volume-1.zip');

    await pumpScreen(tester, harness: harness);
    await tester.tap(find.text('キャッシュを削除'));
    await tester.pumpAndSettle();

    // 取り返せない操作なので確認を挟み、何が消えないかを文言で明示する。
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('ダウンロード済みのコミックは削除されません'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, '削除'));
    await tester.pumpAndSettle();

    expect((await harness.store.usage()).totalCount, 0);
    expect(downloaded.existsSync(), isTrue, reason: 'ダウンロード済みは LRU の対象外');
  });

  // 「更新できませんでした」だと、消えたのか消えていないのかが読み取れない
  // （この画面のエラーは DB / ファイルの失敗で、API の例外ではない）。
  testWidgets('削除に失敗したら「削除できなかった」と分かる文言を出す', (tester) async {
    final harness = CacheHarness.create();
    await harness.record('v1/100/1', bytes: 64);

    await pumpScreen(
      tester,
      harness: harness,
      store: harness.storeLike(FailingClearCacheStore.new),
    );
    await tester.tap(find.text('キャッシュを削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '削除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('キャッシュの削除に失敗しました'), findsOneWidget);
    expect(
      find.textContaining('更新できませんでした'),
      findsNothing,
      reason: '再取得の失敗と削除の失敗を同じ文面にしない',
    );
  });

  testWidgets('「サムネイルだけ削除」ではページ画像が残る', (tester) async {
    final harness = CacheHarness.create();
    await harness.record('v1/100/1', bytes: 64);
    await harness.record('t/a/1', bytes: 32, kind: CachedImageKind.thumbnail);

    await pumpScreen(tester, harness: harness);
    await tester.tap(find.text('サムネイルだけ削除'));
    await tester.pumpAndSettle();

    final usage = await harness.store.usage();
    expect(usage.thumbnailCount, 0);
    expect(usage.pageCount, 1);
  });
  testWidgets('内訳にダウンロード済み・一時キャッシュ・合計・端末の空き容量を 1 画面で出す', (tester) async {
    final harness = CacheHarness.create();
    await harness.record('v1/100/1', bytes: 3 * _mb);
    await harness.record('t/a/1', bytes: _mb, kind: CachedImageKind.thumbnail);

    await pumpScreen(
      tester,
      harness: harness,
      downloadQueue: () => RecordingDownloadQueue(
        initial: {
          1: _completed(1, bytes: 100 * _mb),
          2: _completed(2, bytes: 200 * _mb),
          // 初回の取得中。読めないので「済み」には数えず、途中として出す。
          3: const VolumeDownload(
            volumeId: 3,
            bookId: 7,
            filesVersion: 0,
            status: VolumeDownloadStatus.downloading,
            receivedBytes: 10 * _mb,
            totalBytes: 100 * _mb,
          ),
        },
      ),
      deviceStorage: fixedDeviceStorage(
        const DeviceStorage(freeBytes: 23 * _gb, totalBytes: 128 * _gb),
      ),
    );

    expect(_inTile(StorageUsageSection.downloadedKey, '2 巻'), findsOneWidget);
    expect(
      _inTile(StorageUsageSection.downloadedKey, '300.0 MB'),
      findsOneWidget,
    );
    expect(_inTile(StorageUsageSection.partialKey, '10.0 MB'), findsOneWidget);
    expect(find.text('3.0 MB'), findsOneWidget);
    expect(find.text('1.0 MB'), findsOneWidget);
    expect(
      _inTile(StorageUsageSection.totalKey, '314.0 MB'),
      findsOneWidget,
      reason: '一時キャッシュとダウンロード（途中を含む）の合計',
    );
    expect(
      _inTile(StorageUsageSection.freeSpaceKey, '23.0 GB / 128.0 GB'),
      findsOneWidget,
    );
  });

  testWidgets('ダウンロードを消すと内訳の容量がその場で減り、空き容量も測り直す', (tester) async {
    final queue = RecordingDownloadQueue(
      initial: {
        1: _completed(1, bytes: 100 * _mb),
        2: _completed(2, bytes: 200 * _mb),
      },
    );
    var probes = 0;
    await pumpScreen(
      tester,
      downloadQueue: () => queue,
      deviceStorage: () async {
        probes++;
        return const DeviceStorage(freeBytes: _gb);
      },
    );
    expect(
      _inTile(StorageUsageSection.downloadedKey, '300.0 MB'),
      findsOneWidget,
    );
    final probesBefore = probes;

    // ダウンロード管理画面など、別の経路で消された場合も台帳から集計し直す。
    await _containerOf(tester).read(downloadQueueProvider.notifier).remove(2);
    await tester.pumpAndSettle();

    expect(
      _inTile(StorageUsageSection.downloadedKey, '100.0 MB'),
      findsOneWidget,
    );
    expect(_inTile(StorageUsageSection.downloadedKey, '1 巻'), findsOneWidget);
    expect(probes, greaterThan(probesBefore), reason: '消した分だけ空きが増えている');
  });

  testWidgets('ダウンロードの進捗が届くたびには空き容量を測り直さない（プラットフォームチャネルを叩き続けない）', (
    tester,
  ) async {
    const downloading = VolumeDownload(
      volumeId: 3,
      bookId: 7,
      filesVersion: 0,
      status: VolumeDownloadStatus.downloading,
      receivedBytes: _mb,
      totalBytes: 100 * _mb,
    );
    final queue = RecordingDownloadQueue(
      initial: {
        1: _completed(1, bytes: 100 * _mb),
        3: downloading,
      },
    );
    var probes = 0;
    await pumpScreen(
      tester,
      downloadQueue: () => queue,
      deviceStorage: () async {
        probes++;
        return const DeviceStorage(freeBytes: _gb);
      },
    );
    final probesBefore = probes;

    for (final received in [10, 20, 30]) {
      queue.emit(downloading.copyWith(receivedBytes: received * _mb));
      await tester.pumpAndSettle();
    }
    expect(probes, probesBefore);

    // 途中の巻を消すと一時ファイルの分が空くので測り直す。
    await _containerOf(tester).read(downloadQueueProvider.notifier).remove(3);
    await tester.pumpAndSettle();
    expect(probes, greaterThan(probesBefore));
  });

  testWidgets('空き容量が取れない端末では「不明」と出し、空き容量の自動削除を選べなくする', (tester) async {
    await pumpScreen(tester);

    expect(_inTile(StorageUsageSection.freeSpaceKey, '不明'), findsOneWidget);
    final dropdown = tester.widget<DropdownButton<LowSpaceThreshold>>(
      find.byKey(AutoDeleteSection.lowSpaceKey),
    );
    expect(dropdown.onChanged, isNull, reason: '空き容量が分からなければ判断できない');
    expect(find.text('この端末では空き容量を取得できないため使えません'), findsOneWidget);
    // 読了の自動削除は空き容量に依らないので使える。
    expect(
      tester
          .widget<DropdownButton<FinishedRetention>>(
            find.byKey(AutoDeleteSection.finishedKey),
          )
          .onChanged,
      isNotNull,
    );
  });

  testWidgets('ダウンロード済みはキャッシュの自動削除の対象外であることを明示する', (tester) async {
    await pumpScreen(tester);

    expect(find.textContaining('「上限」「保持期間」による自動削除の対象外です'), findsOneWidget);
    expect(find.textContaining('ダウンロード済みのコミックは対象外です'), findsOneWidget);
  });

  testWidgets('「ダウンロードを管理」からダウンロード管理画面へ行ける', (tester) async {
    await pumpScreen(tester, withRouter: true);

    await tester.tap(find.byKey(StorageSettingsScreen.manageDownloadsKey));
    await tester.pumpAndSettle();

    expect(find.text('ダウンロード管理（テスト）'), findsOneWidget);
  });

  testWidgets('内訳の「ダウンロード済み」からもダウンロード管理画面へ行ける', (tester) async {
    await pumpScreen(tester, withRouter: true);

    await tester.tap(find.byKey(StorageUsageSection.downloadedKey));
    await tester.pumpAndSettle();

    expect(find.text('ダウンロード管理（テスト）'), findsOneWidget);
  });

  testWidgets('自動削除の設定を保存し、その場で適用した結果を SnackBar で知らせる', (tester) async {
    final queue = RecordingDownloadQueue(
      initial: {
        1: _completed(1, bytes: 100 * _mb),
        2: _completed(2, bytes: 50 * _mb),
      },
    );
    final harness = await pumpScreen(
      tester,
      downloadQueue: () => queue,
      progressStore: InMemoryProgressStore([
        // 1 巻目はずっと前に読み終えた。2 巻目は読みかけ。
        ReadingProgress(
          volumeId: 1,
          currentPage: 10,
          maxPage: 10,
          readAt: DateTime.utc(2020),
        ),
        ReadingProgress(
          volumeId: 2,
          currentPage: 3,
          maxPage: 10,
          readAt: DateTime.utc(2020),
        ),
      ]),
    );
    expect(queue.removed, isEmpty, reason: '既定はオフなので、開いただけでは消さない');

    await selectOption(tester, AutoDeleteSection.finishedKey, '7 日後');

    expect(
      (await AutoDeleteSettingsStore(harness.database).read()).finished,
      FinishedRetention.days7,
    );
    expect(queue.removed, [1]);
    expect(find.text('自動削除: 1 巻（100.0 MB）を削除しました'), findsOneWidget);
    expect(
      find.byKey(AutoDeleteSection.lastResultKey),
      findsOneWidget,
      reason: '黙って消さず、後からも何を消したか分かるようにする',
    );
    expect(
      _inTile(StorageUsageSection.downloadedKey, '50.0 MB'),
      findsOneWidget,
    );
  });

  testWidgets('全データ削除は確認してから消し、キャンセルでは何も消さない', (tester) async {
    final harness = CacheHarness.create();
    await harness.record('v1/100/1', bytes: 3 * _mb);
    final queue = RecordingDownloadQueue(
      initial: {1: _completed(1, bytes: 100 * _mb)},
    );
    await pumpScreen(tester, harness: harness, downloadQueue: () => queue);

    await tester.tap(find.byKey(StorageSettingsScreen.clearAllKey));
    await tester.pumpAndSettle();
    // 何が消えて何が残るかを、消す前に数字で見せる。
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('ダウンロード済み 1 巻（100.0 MB）と一時キャッシュ（3.0 MB）'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('読書進捗・設定・ログイン状態は残ります'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(queue.purgeCount, 0);
    expect((await harness.store.usage()).totalCount, 1);

    await tester.tap(find.byKey(StorageSettingsScreen.clearAllKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '削除する'));
    await tester.pumpAndSettle();

    expect(queue.purgeCount, 1);
    expect((await harness.store.usage()).totalCount, 0);
    expect(find.text('すべてのデータを削除しました'), findsOneWidget);
    expect(_inTile(StorageUsageSection.downloadedKey, '0 巻'), findsOneWidget);
  });

  testWidgets('全データ削除に失敗したら SnackBar で知らせる', (tester) async {
    final queue = RecordingDownloadQueue(
      initial: {1: _completed(1, bytes: 100 * _mb)},
    )..purgeError = const FileSystemException('ダウンロードを消せません');
    await pumpScreen(tester, downloadQueue: () => queue);

    await tester.tap(find.byKey(StorageSettingsScreen.clearAllKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '削除する'));
    await tester.pumpAndSettle();

    expect(find.textContaining('データの削除に失敗しました'), findsOneWidget);
    expect(find.text('すべてのデータを削除しました'), findsNothing);
  });
}
