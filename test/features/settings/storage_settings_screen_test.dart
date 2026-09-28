import 'package:comic_laz/core/cache/cache_settings.dart';
import 'package:comic_laz/core/cache/image_cache_store.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/features/settings/presentation/storage_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/cache_fakes.dart';
import '../../support/test_scope.dart';

const _mb = 1024 * 1024;

Future<CacheHarness> pumpScreen(
  WidgetTester tester, {
  CacheHarness? harness,
  ImageCacheStore? store,
}) async {
  final cache = harness ?? CacheHarness.create();
  final container = ProviderContainer(
    overrides: [
      ...testOverrides(),
      ...cache.overrides(store: store),
    ],
  );
  addTearDown(container.dispose);

  // 設定項目が縦に並ぶので、既定の 800x600 では下半分が画面外になる。
  // スクロール操作をテストの本題にしないため、画面を縦長にしておく。
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: StorageSettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return cache;
}

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
    // ダウンロード済みの集計は #9 / #13。枠だけ用意してあることを確かめる。
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
}
