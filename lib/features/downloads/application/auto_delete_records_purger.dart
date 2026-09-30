import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/session_data_purger.dart';
import 'auto_delete_runner.dart';

part 'auto_delete_records_purger.g.dart';

/// ログアウト / セッション失効で自動削除の記録を捨てる（#13 / #15）。
///
/// 「他端末で読了した巻に気づいた時刻」は前のユーザーの読了の跡で、残すと
/// 次のユーザーが同じ巻を落としたときの時計の起点にもなりうる（台帳の確定時刻と
/// 比べて捨てる守りは `planAutoDelete` 側にもあるが、記録そのものも持ち越さない）。
/// 「前回の自動削除」も前のユーザーの削除の結果なので一緒に消す。
/// 期間 / しきい値の設定は端末の設定なので残す。
class AutoDeleteRecordsPurger implements SessionDataPurger {
  const AutoDeleteRecordsPurger(this._clear);

  final ClearAutoDeleteRecords _clear;

  @override
  String get debugLabel => 'auto delete records';

  /// ダウンロード済みの巻と同じ範囲にする。`safe_mode` の変更では巻は残るので、
  /// 記録だけ消すと同じユーザーの保持期間を数え直すことになる。
  @override
  bool get purgesRefetchableOnly => false;

  @override
  Future<void> purgeSessionData() => _clear();
}

@Riverpod(keepAlive: true)
SessionDataPurger autoDeleteRecordsPurger(Ref ref) =>
    AutoDeleteRecordsPurger(() => ref.read(clearAutoDeleteRecordsProvider)());
