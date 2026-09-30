import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/session_data_purger.dart';
import '../../../core/storage/app_database.dart';

part 'safe_mode_revalidation_store.g.dart';

/// 「セーフモードが ON になったので、ダウンロード済みの巻を確かめ直す」予約（#15）。
///
/// `AuthController` がセーフモードの OFF → ON を見つけたとき、保存済みの
/// ユーザーを書き換える**前に**立てる。途中でアプリが落ちても、次の起動で
/// 同じ差分を見つけて立て直せる。確かめ終えたら `SafeModeRevalidator` が消す。
abstract interface class SafeModeRevalidationStore {
  Future<bool> isPending();

  Future<void> schedule();

  Future<void> clear();
}

/// drift の Settings テーブルに置く実装（端末の状態。ログアウトで [SafeModeRevalidationPurger] が消す）。
class DriftSafeModeRevalidationStore implements SafeModeRevalidationStore {
  DriftSafeModeRevalidationStore(this._database);

  static const key = 'safe_mode.revalidate_pending';

  final AppDatabase _database;

  @override
  Future<bool> isPending() async {
    final row = await (_database.select(
      _database.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> schedule() => _database
      .into(_database.settings)
      .insertOnConflictUpdate(const SettingRow(key: key, value: 'true'));

  @override
  Future<void> clear() => (_database.delete(
    _database.settings,
  )..where((t) => t.key.equals(key))).go();
}

@Riverpod(keepAlive: true)
SafeModeRevalidationStore safeModeRevalidationStore(Ref ref) =>
    DriftSafeModeRevalidationStore(ref.watch(appDatabaseProvider));

/// セッションが終わったら予約も捨てる（次のユーザーに持ち越さない）。
///
/// `purgesRefetchableOnly = false` にしているのは、取り直せるものだけの破棄は
/// `safe_mode` の変更そのものだから。そこで消すと、立てたばかりの予約が
/// その場で消えてしまう。
class SafeModeRevalidationPurger implements SessionDataPurger {
  const SafeModeRevalidationPurger(this._store);

  final SafeModeRevalidationStore Function() _store;

  @override
  String get debugLabel => 'safe mode revalidation';

  @override
  bool get purgesRefetchableOnly => false;

  @override
  Future<void> purgeSessionData() => _store().clear();
}

@Riverpod(keepAlive: true)
SessionDataPurger safeModeRevalidationPurger(Ref ref) =>
    SafeModeRevalidationPurger(
      () => ref.read(safeModeRevalidationStoreProvider),
    );
