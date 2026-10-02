import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/downloads/application/auto_delete_records_purger.dart';
import '../../features/downloads/data/downloaded_volume_purger.dart';
import '../../features/downloads/data/safe_mode_revalidation_store.dart';
import '../../features/offline/data/offline_metadata_purger.dart';
import '../../features/progress/data/progress_purger.dart';
import '../../features/push/application/push_token_eraser.dart';
import '../cache/image_cache_purger.dart';

part 'session_data_purger.g.dart';

/// 破棄の範囲。
///
/// 「見せてはいけないものを隠す」目的（`safe_mode` の変更）で、端末にしか無い
/// データまで消してしまうのは行き過ぎ（#11 のレビュー指摘）。ダウンロード済みの
/// 巻は数 GB を予告なく消すことになり、未送信の読書進捗はサーバーにも無いので
/// **永久に失われる**。範囲を分けて、取り直せるものだけ消せるようにする。
enum SessionPurgeScope {
  /// セッションが終わった / 別のユーザーになった。端末内のユーザー固有データを全部捨てる。
  session,

  /// 同じユーザーのまま「見せてよい範囲」が変わった（`safe_mode`）。
  /// サーバーから取り直せるものだけ捨てる。
  refetchable,
}

/// ログアウト / トークン失効時に端末内のデータを破棄する処理。
///
/// Web 版の `purgeMediaCaches` / `clearLocalStorageReadingProgress` 相当。
/// 詳細は #15。
abstract interface class SessionDataPurger {
  /// 何を消すかの説明（ログ用）。
  String get debugLabel;

  /// サーバーから取り直せるデータだけを消す破棄か。
  ///
  /// `true` のものは [SessionPurgeScope.refetchable]（`safe_mode` の変更）でも
  /// 走る。端末にしか無いデータ（ダウンロード済みの ZIP / 未送信の進捗）を消す
  /// ものは `false` にして、セッションの終わり・ユーザー切り替えだけに限る。
  bool get purgesRefetchableOnly;

  Future<void> purgeSessionData();
}

/// [scope] で走らせる破棄だけを選ぶ。
Iterable<SessionDataPurger> purgersInScope(
  Iterable<SessionDataPurger> purgers,
  SessionPurgeScope scope,
) => switch (scope) {
  SessionPurgeScope.session => purgers,
  SessionPurgeScope.refetchable => purgers.where(
    (purger) => purger.purgesRefetchableOnly,
  ),
};

/// 登録済みの破棄処理。
///
/// 端末内にユーザー固有のデータを持つ機能は、ここに実装を足す。
@Riverpod(keepAlive: true)
List<SessionDataPurger> sessionDataPurgers(Ref ref) => [
  // オフライン用のメタ情報（一覧 / 詳細 / 巻情報 / サムネイルの保護印。#11）。
  ref.watch(offlineMetadataPurgerProvider),
  ref.watch(imageCachePurgerProvider),
  ref.watch(downloadedVolumePurgerProvider),
  // 自動削除の記録（前のユーザーの読了に気づいた時刻 / 前回の結果。#13）。
  ref.watch(autoDeleteRecordsPurgerProvider),
  ref.watch(progressPurgerProvider),
  // セーフモードの再検証の予約（次のユーザーに持ち越さない。#15）。
  ref.watch(safeModeRevalidationPurgerProvider),
  // この端末の FCM トークン（#14）。失効でサーバーの登録を消せなくても、
  // 前のユーザーの通知がこの端末に届き続けないように捨てる。
  ref.watch(pushRegistrationPurgerProvider),
];
