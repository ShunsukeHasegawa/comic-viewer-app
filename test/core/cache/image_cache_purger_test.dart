import 'dart:io';

import 'package:comic_laz/core/cache/image_cache_purger.dart';
import 'package:comic_laz/core/cache/image_cache_store.dart';
import 'package:comic_laz/core/cache/memory_image_cache.dart';
import 'package:comic_laz/core/session/session_data_purger.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/cache_fakes.dart';
import '../../support/test_scope.dart';

void main() {
  // ログアウト後に前のユーザーの画像が端末へ残らないことが #8 / #15 の要（かなめ）。
  // ここが静かに壊れると「別のユーザーに前のユーザーの画像を見せる」。
  test('ログアウトでページもサムネイルも実体ごと捨てる', () async {
    final harness = CacheHarness.create();
    var memoryCleared = 0;
    final container = ProviderContainer(
      overrides: [
        ...testOverrides(),
        ...harness.overrides(),
        memoryImageCacheClearerProvider.overrideWithValue(
          () => memoryCleared++,
        ),
      ],
    );
    addTearDown(container.dispose);

    await harness.write('v1/100/1', bytes: 64);
    await harness.write('t/a/1', bytes: 16, kind: CachedImageKind.thumbnail);
    final downloaded = harness.createDownloadedFile('keep.bin');

    await container.read(imageCachePurgerProvider).purgeSessionData();

    expect(await harness.store.usage(), CacheUsage.empty);
    expect(harness.fileCount, 0);
    expect(memoryCleared, 1, reason: 'デコード済み画像を残すと、次のユーザーに前の表紙が見える');
    expect(
      downloaded.existsSync(),
      isTrue,
      reason: '明示的にダウンロードしたデータ（#9）は別領域なので消さない',
    );
  });

  test('ディスクの削除に失敗しても、メモリ上の画像は捨てる（次のユーザーに前の表紙を見せないため）', () async {
    var memoryCleared = 0;
    final purger = ImageCachePurger(
      () async => throw const FileSystemException('disk broken'),
      () => memoryCleared++,
    );

    // 失敗は呼び出し元へ返す（破棄の印を残して、次の起動でやり直させるため）。
    await expectLater(
      purger.purgeSessionData(),
      throwsA(isA<FileSystemException>()),
    );
    expect(memoryCleared, 1);
  });

  test('ログアウトの破棄対象として登録されている', () {
    final harness = CacheHarness.create();
    final container = ProviderContainer(
      overrides: [
        ...harness.overrides(),
        memoryImageCacheClearerProvider.overrideWithValue(() {}),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(sessionDataPurgersProvider),
      contains(isA<ImageCachePurger>()),
    );
  });
}
