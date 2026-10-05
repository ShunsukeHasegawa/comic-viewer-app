import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/features/settings/application/keep_screen_on_setting.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/settings_fakes.dart';
import '../../support/test_scope.dart';

void main() {
  group('DriftKeepScreenOnStore', () {
    late AppDatabase database;
    late DriftKeepScreenOnStore store;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      store = DriftKeepScreenOnStore(database);
    });
    tearDown(() => database.close());

    test('何も保存していなければ ON（設定が入る前と同じく読書中は消灯させない）', () async {
      expect(await store.read(), isTrue);
    });

    test('選んだ値を読み戻せる（次の起動でも同じ挙動にするため）', () async {
      for (final value in [false, true, false]) {
        await store.write(value);
        expect(await store.read(), value);
      }
    });

    test('知らない値は ON として読む（壊れた値で読書中に消灯し始めないように）', () async {
      await database
          .into(database.settings)
          .insertOnConflictUpdate(
            const SettingRow(key: DriftKeepScreenOnStore.key, value: 'maybe'),
          );

      expect(await store.read(), isTrue);
    });
  });

  group('KeepScreenOnSetting', () {
    test('保存できてから反映する', () async {
      final store = InMemoryKeepScreenOnStore();
      final container = createContainer(keepScreenOnStore: store);
      addTearDown(container.dispose);
      expect(await container.read(keepScreenOnSettingProvider.future), isTrue);

      await container.read(keepScreenOnSettingProvider.notifier).set(false);

      expect(store.writes, [false]);
      expect(container.read(keepScreenOnSettingProvider).value, isFalse);
    });

    test('保存に失敗したら表示を変えずに投げる（切り替わったのに次の起動で黙って戻らないように）', () async {
      final store = InMemoryKeepScreenOnStore()
        ..writeError = StateError('disk');
      final container = createContainer(keepScreenOnStore: store);
      addTearDown(container.dispose);
      await container.read(keepScreenOnSettingProvider.future);

      await expectLater(
        container.read(keepScreenOnSettingProvider.notifier).set(false),
        throwsStateError,
      );

      expect(container.read(keepScreenOnSettingProvider).value, isTrue);
    });
  });
}
