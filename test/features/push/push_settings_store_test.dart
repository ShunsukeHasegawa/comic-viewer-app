import 'package:comic_laz/core/device/notification_permission_log.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/features/downloads/application/download_settings.dart';
import 'package:comic_laz/features/push/data/push_settings_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// 他のテストは全部 `InMemoryPushSettingsStore` を使うので、drift に置く形
/// （既定値・文字列の表し方・JSON の読み書き・共有のキー）はここでしか確かめられない。
void main() {
  late AppDatabase database;
  late DriftPushSettingsStore store;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = DriftPushSettingsStore(database);
    addTearDown(database.close);
  });

  group('新刊通知の設定', () {
    test('未保存なら ON（入れたばかりの端末でも新刊が届くように）', () async {
      expect(await store.readEnabled(), isTrue);
    });

    test('OFF は作り直した store（= 次の起動）でも OFF のまま', () async {
      await store.writeEnabled(false);

      expect(await DriftPushSettingsStore(database).readEnabled(), isFalse);

      await store.writeEnabled(true);
      expect(await DriftPushSettingsStore(database).readEnabled(), isTrue);
    });
  });

  group('登録の控え', () {
    test('ユーザー・トークン・時刻を読み返せる（読めないと起動のたびに POST してしまう）', () async {
      final registeredAt = DateTime.utc(2026, 10, 1, 12);
      await store.writeRegistration(
        PushRegistration(userId: 7, token: 't', registeredAt: registeredAt),
      );

      final saved = await DriftPushSettingsStore(database).readRegistration();

      expect(saved, isNotNull);
      expect(saved!.userId, 7);
      expect(saved.token, 't');
      expect(saved.registeredAt.isUtc, isTrue);
      expect(saved.registeredAt, registeredAt);
    });

    test('ローカル時刻で書いても同じ瞬間として読み返す（24 時間の判定をずらさない）', () async {
      final local = DateTime(2026, 10, 1, 21, 30);
      await store.writeRegistration(
        PushRegistration(userId: 1, token: 't', registeredAt: local),
      );

      final saved = await store.readRegistration();

      expect(saved!.registeredAt.isAtSameMomentAs(local), isTrue);
    });

    test('消したら読めない', () async {
      await store.writeRegistration(
        PushRegistration(
          userId: 1,
          token: 't',
          registeredAt: DateTime.utc(2026),
        ),
      );

      await store.clearRegistration();

      expect(await store.readRegistration(), isNull);
    });

    test('壊れた控えは投げずに「無い」とみなす（登録し直せば直るので、起動を止めない）', () async {
      await database
          .into(database.settings)
          .insertOnConflictUpdate(
            const SettingRow(
              key: DriftPushSettingsStore.registrationKey,
              value: '{not json',
            ),
          );

      expect(await store.readRegistration(), isNull);
    });
  });

  group('トークンを捨てる予約', () {
    test('立てて下ろせる（下ろしたら行も消え、次の起動で捨て直さない）', () async {
      expect(await store.readTokenDeletionPending(), isFalse);

      await store.writeTokenDeletionPending(true);
      expect(
        await DriftPushSettingsStore(database).readTokenDeletionPending(),
        isTrue,
      );

      await store.writeTokenDeletionPending(false);
      expect(await store.readTokenDeletionPending(), isFalse);
      final row =
          await (database.select(database.settings)..where(
                (t) => t.key.equals(DriftPushSettingsStore.deletionPendingKey),
              ))
              .getSingleOrNull();
      expect(row, isNull);
    });
  });

  group('通知の許可を求めた記録（ダウンロードと共有）', () {
    test('キーを変えない（変えると一度断った人にもう一度ダイアログを出してしまう）', () {
      expect(
        DriftNotificationPermissionLog.requestedKey,
        'downloads.notification_permission_requested',
      );
      expect(
        DownloadSettingsStore.notificationPermissionRequestedKey,
        DriftNotificationPermissionLog.requestedKey,
      );
    });

    test('プッシュ通知が求めたら、ダウンロードからも「求めた」に見える（二重に聞かない）', () async {
      await DriftNotificationPermissionLog(database).markRequested();

      expect(
        await DownloadSettingsStore(database)
            .readNotificationPermissionRequested(),
        isTrue,
      );
    });

    test('ダウンロードが求めたら、プッシュ通知からも「求めた」に見える（二重に聞かない）', () async {
      await DownloadSettingsStore(database)
          .markNotificationPermissionRequested();

      expect(
        await DriftNotificationPermissionLog(database).wasRequested(),
        isTrue,
      );
    });
  });
}
