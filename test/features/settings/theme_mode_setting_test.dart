import 'dart:async';

import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/features/settings/application/theme_mode_setting.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/settings_fakes.dart';
import '../../support/test_scope.dart';

void main() {
  group('DriftThemeModeStore', () {
    late AppDatabase database;
    late DriftThemeModeStore store;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      store = DriftThemeModeStore(database);
    });
    tearDown(() => database.close());

    test('何も保存していなければ「システムに合わせる」（既定は OS の表示に従う）', () async {
      expect(await store.read(), ThemeMode.system);
    });

    test('選んだテーマを読み戻せる（次の起動でも同じ表示にするため）', () async {
      for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
        await store.write(mode);
        expect(await store.read(), mode);
      }
    });

    test('知らない値は「システムに合わせる」として読む（版を戻しても起動できるように）', () async {
      await database
          .into(database.settings)
          .insertOnConflictUpdate(
            const SettingRow(key: DriftThemeModeStore.key, value: 'sepia'),
          );

      expect(await store.read(), ThemeMode.system);
    });
  });

  group('ThemeModeSetting', () {
    test('保存できてから反映する', () async {
      final store = InMemoryThemeModeStore();
      final container = createContainer(themeModeStore: store);
      addTearDown(container.dispose);
      expect(
        await container.read(themeModeSettingProvider.future),
        ThemeMode.system,
      );

      await container
          .read(themeModeSettingProvider.notifier)
          .set(ThemeMode.dark);

      expect(store.writes, [ThemeMode.dark]);
      expect(container.read(themeModeSettingProvider).value, ThemeMode.dark);
    });

    test('保存に失敗したら表示を変えずに投げる（切り替わったのに次の起動で黙って戻らないように）', () async {
      final store = InMemoryThemeModeStore()..writeError = StateError('disk');
      final container = createContainer(themeModeStore: store);
      addTearDown(container.dispose);
      await container.read(themeModeSettingProvider.future);

      await expectLater(
        container.read(themeModeSettingProvider.notifier).set(ThemeMode.dark),
        throwsStateError,
      );

      expect(container.read(themeModeSettingProvider).value, ThemeMode.system);
    });
  });

  group('preloadThemeMode', () {
    test('読み終えてから戻る（最初のフレームから保存済みのテーマで描けるように）', () async {
      final container = createContainer(
        themeModeStore: InMemoryThemeModeStore(ThemeMode.dark),
      );
      addTearDown(container.dispose);

      await preloadThemeMode(container);

      // 待たずに同期で読めること（MaterialApp の最初の build がこれを見る）。
      expect(container.read(themeModeSettingProvider).value, ThemeMode.dark);
    });

    test('読めなくても投げない（テーマのために起動を止めない）', () async {
      final container = createContainer(
        themeModeStore: InMemoryThemeModeStore()..readError = Exception('db'),
      );
      addTearDown(container.dispose);

      await preloadThemeMode(container);

      expect(container.read(themeModeSettingProvider).hasError, isTrue);
    });

    test('時間切れなら待つのをやめる（DB が遅いときに起動そのものを待たせない）', () async {
      final gate = Completer<void>();
      final store = InMemoryThemeModeStore(ThemeMode.dark)..readGate = gate;
      final container = createContainer(themeModeStore: store);
      addTearDown(container.dispose);

      await preloadThemeMode(
        container,
        timeout: const Duration(milliseconds: 10),
      );
      expect(container.read(themeModeSettingProvider).isLoading, isTrue);

      // 読めた時点で反映される（以降は保存済みのテーマになる）。
      gate.complete();
      await container.read(themeModeSettingProvider.future);
      expect(container.read(themeModeSettingProvider).value, ThemeMode.dark);
    });
  });
}
