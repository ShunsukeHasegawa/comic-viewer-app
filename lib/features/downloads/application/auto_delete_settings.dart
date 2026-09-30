import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/app_database.dart';
import '../domain/auto_delete_plan.dart';

export '../domain/auto_delete_plan.dart'
    show
        AutoDeleteResult,
        AutoDeleteSettings,
        FinishedRetention,
        LowSpaceThreshold;

part 'auto_delete_settings.g.dart';

/// 自動削除の設定と記録の保存先（drift の key-value）。
///
/// 設定（期間 / しきい値）は端末の設定でユーザー固有のデータではないので、
/// ログアウトでは消さない。記録（`finished_seen` / 前回の結果）は前のユーザーの
/// 読了や削除の跡なので、ログアウトで消す（[clearRecords]。
/// `AutoDeleteRecordsPurger`）。`finished_seen` は実行のたびに台帳でも刈り込むが、
/// 実行を待たずに次のユーザーが同じ巻を落とすと、前の記録で消してしまう。
class AutoDeleteSettingsStore {
  AutoDeleteSettingsStore(this._database);

  static const finishedAfterKey = 'downloads.auto_delete.finished_after';
  static const lowSpaceKey = 'downloads.auto_delete.low_space';
  static const finishedSeenKey = 'downloads.auto_delete.finished_seen';
  static const lastResultKey = 'downloads.auto_delete.last_result';

  final AppDatabase _database;

  /// 知らない値はオフとして読む。バージョン間で選択肢が変わったときに、
  /// 勝手に消し始めないため。
  Future<AutoDeleteSettings> read() async {
    final finished = await _read(finishedAfterKey);
    final lowSpace = await _read(lowSpaceKey);
    return AutoDeleteSettings(
      finished:
          FinishedRetention.values.asNameMap()[finished] ??
          FinishedRetention.off,
      lowSpace:
          LowSpaceThreshold.values.asNameMap()[lowSpace] ??
          LowSpaceThreshold.off,
    );
  }

  Future<void> write(AutoDeleteSettings settings) =>
      _database.transaction(() async {
        await _write(finishedAfterKey, settings.finished.name);
        await _write(lowSpaceKey, settings.lowSpace.name);
      });

  /// 他端末で読了した巻に、この端末が初めて気づいた時刻。
  ///
  /// 壊れた値は空として読む（記録が無い = 次の実行で気づき直すだけで、
  /// 早く消しすぎることは無い）。
  Future<Map<int, DateTime>> readFinishedSeen() async {
    final raw = await _read(finishedSeenKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return {
        for (final MapEntry(:key, :value) in decoded.entries)
          if ((int.tryParse(key), value) case (final int id, final int ms))
            id: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> writeFinishedSeen(Map<int, DateTime> seen) => _write(
    finishedSeenKey,
    jsonEncode({
      for (final MapEntry(:key, :value) in seen.entries)
        '$key': value.millisecondsSinceEpoch,
    }),
  );

  /// 前回の自動削除の結果（無ければ / 壊れていれば `null`）。
  Future<AutoDeleteResult?> readLastResult() async {
    final raw = await _read(lastResultKey);
    if (raw == null) return null;
    try {
      return switch (jsonDecode(raw)) {
        {
          'at': final int at,
          'volumes': final int volumes,
          'bytes': final int bytes,
        } =>
          AutoDeleteResult(
            at: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
            volumes: volumes,
            bytes: bytes,
          ),
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  Future<void> writeLastResult(AutoDeleteResult result) => _write(
    lastResultKey,
    jsonEncode({
      'at': result.at.millisecondsSinceEpoch,
      'volumes': result.volumes,
      'bytes': result.bytes,
    }),
  );

  /// 自動削除の記録（気づいた時刻 + 前回の結果）を消す。設定は残す。
  ///
  /// ログアウトと「すべてのデータを削除」で使う。残すと、0 巻の横に消えた
  /// はずの「前回の自動削除」が並び、次のユーザーの巻が前の記録で消えうる。
  Future<void> clearRecords() async {
    await (_database.delete(
      _database.settings,
    )..where((t) => t.key.isIn([finishedSeenKey, lastResultKey]))).go();
  }

  Future<String?> _read(String key) async {
    final row = await (_database.select(
      _database.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _write(String key, String value) => _database
      .into(_database.settings)
      .insertOnConflictUpdate(SettingRow(key: key, value: value));
}

@Riverpod(keepAlive: true)
AutoDeleteSettingsStore autoDeleteSettingsStore(Ref ref) =>
    AutoDeleteSettingsStore(ref.watch(appDatabaseProvider));

/// 自動削除の設定。
@Riverpod(keepAlive: true)
class AutoDeleteSettingsController extends _$AutoDeleteSettingsController {
  @override
  Future<AutoDeleteSettings> build() =>
      ref.watch(autoDeleteSettingsStoreProvider).read();

  /// 保存してから反映する（保存に失敗したら表示を変えず、例外を返す）。
  Future<void> set(AutoDeleteSettings value) async {
    await ref.read(autoDeleteSettingsStoreProvider).write(value);
    if (!ref.mounted) return;
    state = AsyncData(value);
  }
}
