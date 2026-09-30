import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/app_database.dart';
import 'session_data_purger.dart';

part 'session_purge_journal.g.dart';

/// 破棄待ちの印（#15）。
///
/// 破棄の**前に**書き、すべての破棄が成功したときだけ消す。途中でアプリが
/// 落ちた / 1 つでも失敗した破棄を、次の起動（またはログイン）でやり直すため。
/// 印が無いと、ログアウトの後はトークンも前のユーザーも残っていないので、
/// 消し損ねたデータが二度と消されない。
///
/// 印は「データを消す」意味しか持たない（トークンは消さない）。
abstract interface class SessionPurgeJournal {
  /// やり直すべき破棄の範囲（無ければ `null`）。
  Future<SessionPurgeScope?> readPending();

  /// [scope] の破棄を始める印を書く。
  ///
  /// 既に [SessionPurgeScope.session] の印があれば、弱い方で上書きしない
  /// （`safe_mode` の変更で、消し損ねたログアウトの印を失わないため）。
  Future<void> markPending(SessionPurgeScope scope);

  /// [scope] の破棄がすべて成功したので印を消す。
  ///
  /// 残っている印が [scope] より強ければ消さない（取り直せるものだけ消した
  /// ことで、前のユーザーのダウンロードを消す印まで消してしまわないため）。
  Future<void> complete(SessionPurgeScope scope);
}

/// drift の Settings テーブルに置く実装。
///
/// トークンと同じセキュアストレージに置かないのは、Keystore の障害で
/// トークンと一緒に読めなくなるため。Settings は purger が消さない（キー単位で
/// しか触らない）ので、破棄の途中でも印は残る。
class DriftSessionPurgeJournal implements SessionPurgeJournal {
  DriftSessionPurgeJournal(this._database);

  static const key = 'session.purge_pending';

  final AppDatabase _database;

  @override
  Future<SessionPurgeScope?> readPending() async {
    final row = await (_database.select(
      _database.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    // 読めない値は強い方（全部消す）に倒す。持ち主を確かめられないデータを残さない。
    return SessionPurgeScope.values.asNameMap()[row.value] ??
        SessionPurgeScope.session;
  }

  @override
  Future<void> markPending(SessionPurgeScope scope) async {
    final current = await readPending();
    if (current == SessionPurgeScope.session) return;
    await _database
        .into(_database.settings)
        .insertOnConflictUpdate(SettingRow(key: key, value: scope.name));
  }

  @override
  Future<void> complete(SessionPurgeScope scope) async {
    final current = await readPending();
    if (current == null || !purgeScopeCovers(scope, current)) return;
    await (_database.delete(
      _database.settings,
    )..where((t) => t.key.equals(key))).go();
  }
}

/// [done] の破棄で [pending] の破棄が済んだことになるか。
bool purgeScopeCovers(SessionPurgeScope done, SessionPurgeScope pending) =>
    done == SessionPurgeScope.session || pending == done;

@Riverpod(keepAlive: true)
SessionPurgeJournal sessionPurgeJournal(Ref ref) =>
    DriftSessionPurgeJournal(ref.watch(appDatabaseProvider));
