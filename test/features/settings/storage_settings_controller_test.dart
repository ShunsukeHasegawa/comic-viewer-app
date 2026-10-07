import 'package:comic_laz/core/cache/image_cache_store.dart';
import 'package:comic_laz/core/cache/memory_image_cache.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/features/settings/application/storage_settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/cache_fakes.dart';
import '../../support/test_scope.dart';

ProviderContainer buildContainer(
  CacheHarness harness, {
  ImageCacheStore? store,
  void Function()? onMemoryClear,
}) {
  return ProviderContainer(
    overrides: [
      ...testOverrides(),
      ...harness.overrides(store: store),
      memoryImageCacheClearerProvider.overrideWithValue(onMemoryClear ?? () {}),
    ],
  );
}

void main() {
  // ディスクのメタ情報だけ消してもメモリの `ImageCache` がヒットするので、
  // 「表紙の一覧を作り直します」と言いながら削除前の表紙が出続ける。
  testWidgets('キャッシュ削除ではデコード済み画像も捨てる', (tester) async {
    final harness = CacheHarness.create();
    var memoryCleared = 0;
    final container = buildContainer(
      harness,
      onMemoryClear: () => memoryCleared++,
    );
    addTearDown(container.dispose);
    container.listen(storageSettingsControllerProvider, (_, _) {});
    await container.read(storageSettingsControllerProvider.future);
    await harness.record('t/a/1', bytes: 32, kind: CachedImageKind.thumbnail);

    // 削除は孤児の掃除でディレクトリを非同期に列挙する（実ファイル I/O）。
    // `testWidgets` の擬似時間ではその完了が進まないので `runAsync` の中で待つ。
    final error = await tester.runAsync(
      () => container
          .read(storageSettingsControllerProvider.notifier)
          .clearCache(kind: CachedImageKind.thumbnail),
    );

    expect(error, isNull);
    expect(memoryCleared, 1);
  });

  // 画面を離れると notifier は破棄される（autoDispose）。破棄後に `state` を
  // 読むと、成功した削除が例外になって「失敗」として返る。
  testWidgets('削除の完了前に画面を離れても失敗として扱わない', (tester) async {
    final harness = CacheHarness.create();
    final gated = harness.storeLike(GatedClearCacheStore.new);
    final container = buildContainer(harness, store: gated);
    container.listen(storageSettingsControllerProvider, (_, _) {});
    await container.read(storageSettingsControllerProvider.future);

    // 削除は孤児の掃除でディレクトリを非同期に列挙する（実ファイル I/O）。
    // `testWidgets` の擬似時間ではその続きが進まないので、削除の開始から
    // 完了までを `runAsync` の中で行う。
    final error = await tester.runAsync(() async {
      final result = container
          .read(storageSettingsControllerProvider.notifier)
          .clearCache();
      // 画面を離れる（notifier が破棄される）→ そのあと削除が終わる。
      container.dispose();
      gated.gate.complete();
      return result;
    });

    expect(error, isNull);
  });
}
