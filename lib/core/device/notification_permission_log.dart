import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/app_database.dart';

part 'notification_permission_log.g.dart';

/// 通知の許可（Android 13 以上の `POST_NOTIFICATIONS`）を**アプリとして**もう
/// 求めたかの記録。
///
/// 許可を求める機能が 2 つある（巻のダウンロードの進捗通知 #10 と、新刊の
/// プッシュ通知 #14）。それぞれが「一度だけ求める」を別々に覚えると、片方で
/// 断られた後にもう片方がまたダイアログを出す（Android は 2 回断られると以降は
/// 黙って拒否するので、2 回目のダイアログは断られた意思を押し切るだけになる）。
/// 記録を 1 つにして、どちらが先に求めても二度目は出さない。
///
/// 許可そのものは OS が持つ。ここは「自動で聞いてよいか」だけを決める
/// （ユーザーが設定画面で通知を ON にし直したときは、記録に関わらず聞き直す）。
abstract interface class NotificationPermissionLog {
  Future<bool> wasRequested();

  Future<void> markRequested();
}

/// drift の Settings に置く実装。
class DriftNotificationPermissionLog implements NotificationPermissionLog {
  DriftNotificationPermissionLog(this._database);

  /// キーはダウンロード（#10）が先に使っていたものをそのまま使う。変えると
  /// 既存の端末で「まだ求めていない」に戻り、一度断った人にもう一度聞いてしまう。
  static const requestedKey = 'downloads.notification_permission_requested';

  final AppDatabase _database;

  @override
  Future<bool> wasRequested() async {
    final row = await (_database.select(
      _database.settings,
    )..where((t) => t.key.equals(requestedKey))).getSingleOrNull();
    return row?.value == 'true';
  }

  @override
  Future<void> markRequested() => _database
      .into(_database.settings)
      .insertOnConflictUpdate(
        const SettingRow(key: requestedKey, value: 'true'),
      );
}

@Riverpod(keepAlive: true)
NotificationPermissionLog notificationPermissionLog(Ref ref) =>
    DriftNotificationPermissionLog(ref.watch(appDatabaseProvider));
