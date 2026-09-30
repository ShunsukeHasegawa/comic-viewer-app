import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/features/downloads/application/auto_delete_records_purger.dart';
import 'package:comic_laz/features/downloads/application/auto_delete_settings.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late AutoDeleteSettingsStore store;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = AutoDeleteSettingsStore(database);
  });
  tearDown(() => database.close());

  Future<void> writeRaw(String key, String value) => database
      .into(database.settings)
      .insertOnConflictUpdate(SettingRow(key: key, value: value));

  test('何も保存していなければすべてオフ（ユーザーが選ぶまで勝手に消さない）', () async {
    expect(await store.read(), const AutoDeleteSettings());
    expect((await store.read()).isEnabled, isFalse);
  });

  test('保存した設定を読み戻せる', () async {
    const settings = AutoDeleteSettings(
      finished: FinishedRetention.days14,
      lowSpace: LowSpaceThreshold.gb2,
    );
    await store.write(settings);

    expect(await store.read(), settings);
  });

  test('知らない値はオフとして読む（バージョン違いで勝手に消し始めない）', () async {
    await writeRaw(AutoDeleteSettingsStore.finishedAfterKey, 'days3');
    await writeRaw(AutoDeleteSettingsStore.lowSpaceKey, 'gb10');

    expect(await store.read(), const AutoDeleteSettings());
  });

  test('初めて気づいた時刻と前回の結果を読み戻せる', () async {
    final at = DateTime.utc(2026, 9, 30, 14, 2);
    await store.writeFinishedSeen({12: at});
    await store.writeLastResult(
      AutoDeleteResult(at: at, volumes: 3, bytes: 420),
    );

    expect(await store.readFinishedSeen(), {12: at});
    expect(
      await store.readLastResult(),
      AutoDeleteResult(at: at, volumes: 3, bytes: 420),
    );
  });

  test('壊れた記録は無いものとして読む（早く消しすぎる側に倒さない）', () async {
    await writeRaw(AutoDeleteSettingsStore.finishedSeenKey, '{broken');
    await writeRaw(AutoDeleteSettingsStore.lastResultKey, '[]');

    expect(await store.readFinishedSeen(), isEmpty);
    expect(await store.readLastResult(), isNull);
  });

  test('ログアウトの破棄は記録（気づいた時刻・前回の結果）だけを消し、設定は残す（前のユーザーの跡を持ち越さない）', () async {
    const settings = AutoDeleteSettings(finished: FinishedRetention.days7);
    await store.write(settings);
    await store.writeFinishedSeen({1: DateTime.utc(2026, 9, 1)});
    await store.writeLastResult(
      AutoDeleteResult(at: DateTime.utc(2026, 9, 2), volumes: 1, bytes: 10),
    );
    final purger = AutoDeleteRecordsPurger(store.clearRecords);

    expect(purger.purgesRefetchableOnly, isFalse);
    await purger.purgeSessionData();

    expect(await store.readFinishedSeen(), isEmpty);
    expect(await store.readLastResult(), isNull);
    expect(await store.read(), settings);
  });
}
