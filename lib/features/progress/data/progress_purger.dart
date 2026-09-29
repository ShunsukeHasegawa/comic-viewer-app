import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/session_data_purger.dart';
import 'progress_store.dart';

part 'progress_purger.g.dart';

/// ログアウト / セッション失効で端末の読書進捗を捨てる（#15）。
///
/// 未送信の進捗も一緒に消える。前のユーザーの進捗を次のユーザーの
/// トークンで送ってしまう方が害が大きいため（Web 版の
/// `clearLocalStorageReadingProgress` と同じ判断）。
class ProgressPurger implements SessionDataPurger {
  const ProgressPurger(this._store);

  final ProgressStore _store;

  @override
  String get debugLabel => 'reading progress';

  /// 未送信の進捗はサーバーにも無いので、消したら復旧できない。
  /// ユーザーが変わったときだけ消す（`safe_mode` の変更では消さない）。
  @override
  bool get purgesRefetchableOnly => false;

  @override
  Future<void> purgeSessionData() => _store.deleteAll();
}

@Riverpod(keepAlive: true)
SessionDataPurger progressPurger(Ref ref) =>
    ProgressPurger(ref.watch(progressStoreProvider));
