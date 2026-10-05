import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/app_database.dart';
import '../../library/application/library_controller.dart' show noAutoRetry;

part 'keep_screen_on_setting.g.dart';

/// 「読書中は画面を消さない」の保存先（#19）。
///
/// 端末ごとの好み（その端末の消灯時間や使い方に依る）で、ユーザー固有の
/// データではない。ログアウトしても残す（`SessionDataPurger` には登録しない）。
abstract interface class KeepScreenOnStore {
  Future<bool> read();

  Future<void> write(bool keepScreenOn);
}

/// drift の Settings に保存する [KeepScreenOnStore]。
class DriftKeepScreenOnStore implements KeepScreenOnStore {
  DriftKeepScreenOnStore(this._database);

  static const key = 'reading.keep_screen_on';

  final AppDatabase _database;

  /// 未保存・知らない値は ON（既定）として読む。設定が入る前と同じ挙動を
  /// 既定にして、更新しただけで読書中に消灯し始めないように。
  @override
  Future<bool> read() async {
    final row = await (_database.select(
      _database.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value != 'false';
  }

  @override
  Future<void> write(bool keepScreenOn) => _database
      .into(_database.settings)
      .insertOnConflictUpdate(SettingRow(key: key, value: '$keepScreenOn'));
}

@Riverpod(keepAlive: true)
KeepScreenOnStore keepScreenOnStore(Ref ref) =>
    DriftKeepScreenOnStore(ref.watch(appDatabaseProvider));

/// 読書中（ビューア表示中）に画面のスリープを抑止するか（#19）。
///
/// `ReadingScreenMode` がこれを見てスリープ抑止だけを切り替える（全画面表示は
/// 設定に関わらず続ける）。読めなかったときの扱い（ON とみなす）はそちらで決める。
///
/// テーマと同じく自動で再試行しない。端末内の DB が読めないのは一時的なことでは
/// まず無く、再試行の間は切り替えも塞がれる。保存し直せばそれで直る。
@Riverpod(keepAlive: true, retry: noAutoRetry)
class KeepScreenOnSetting extends _$KeepScreenOnSetting {
  @override
  Future<bool> build() => ref.watch(keepScreenOnStoreProvider).read();

  /// 保存してから反映する（保存に失敗したら表示を変えず、例外を返す）。
  ///
  /// 先に反映すると、保存できていないのに切り替わったように見え、次の起動で
  /// 黙って元に戻る。
  Future<void> set(bool keepScreenOn) async {
    await ref.read(keepScreenOnStoreProvider).write(keepScreenOn);
    if (!ref.mounted) return;
    state = AsyncData(keepScreenOn);
  }
}
