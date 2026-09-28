import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_data_purger.g.dart';

/// ログアウト / トークン失効時に端末内のデータを破棄する処理。
///
/// Web 版の `purgeMediaCaches` / `clearLocalStorageReadingProgress` 相当。
/// 画像キャッシュ（#8）・ダウンロード済みデータ（#9）・進捗（#12）などが
/// それぞれ実装を [sessionDataPurgersProvider] に登録する。詳細は #15。
abstract interface class SessionDataPurger {
  /// 何を消すかの説明（ログ用）。
  String get debugLabel;

  Future<void> purgeSessionData();
}

/// 登録済みの破棄処理。各機能の Issue で override して追加する。
@Riverpod(keepAlive: true)
List<SessionDataPurger> sessionDataPurgers(Ref ref) => const [];
