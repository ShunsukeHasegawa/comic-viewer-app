import 'package:comic_laz/core/cache/cache_settings.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/cache_fakes.dart';

void main() {
  test('未設定なら既定値（Web 版の Workbox 設定に寄せた値）', () async {
    final harness = CacheHarness.create();

    final settings = await harness.settingsStore.read();

    expect(settings.pageLimit, CacheLimit.gb1);
    expect(settings.thumbnailLimit, CacheLimit.mb256);
    expect(settings.retention, CacheRetention.days30);
  });

  test('保存した設定を読み出せる', () async {
    final harness = CacheHarness.create();

    await harness.settingsStore.write(
      const CacheSettings(
        pageLimit: CacheLimit.mb256,
        thumbnailLimit: CacheLimit.mb512,
        retention: CacheRetention.days7,
      ),
    );

    expect(
      await harness.settingsStore.read(),
      const CacheSettings(
        pageLimit: CacheLimit.mb256,
        thumbnailLimit: CacheLimit.mb512,
        retention: CacheRetention.days7,
      ),
    );
  });

  test('上書きしても行が増えない（key-value の upsert）', () async {
    final harness = CacheHarness.create();

    await harness.settingsStore.write(
      const CacheSettings(pageLimit: CacheLimit.mb256),
    );
    await harness.settingsStore.write(
      const CacheSettings(pageLimit: CacheLimit.gb2),
    );

    final rows = await harness.database.select(harness.database.settings).get();
    expect(rows.length, 3);
    expect((await harness.settingsStore.read()).pageLimit, CacheLimit.gb2);
  });

  test('知らない値（アプリ更新で enum が変わった場合）は既定値に倒す', () async {
    final harness = CacheHarness.create();
    await harness.database
        .into(harness.database.settings)
        .insertOnConflictUpdate(
          SettingRow(key: CacheSettingsStore.pageLimitKey, value: 'tb999'),
        );

    // 不正な値で落ちたり、意図せず無制限になってはいけない。
    expect((await harness.settingsStore.read()).pageLimit, CacheLimit.gb1);
  });

  test('無制限 / 無期限は null で表す（上限なしの判定を 1 箇所にする）', () {
    expect(CacheLimit.unlimited.bytes, isNull);
    expect(CacheRetention.forever.duration, isNull);
    expect(CacheLimit.gb1.bytes, 1024 * 1024 * 1024);
  });
}
