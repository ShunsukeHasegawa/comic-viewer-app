import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/downloads/data/downloaded_volume_purger.dart';
import '../../features/library/data/library_repository.dart';
import '../cache/image_cache_purger.dart';

part 'session_data_purger.g.dart';

/// ログアウト / トークン失効時に端末内のデータを破棄する処理。
///
/// Web 版の `purgeMediaCaches` / `clearLocalStorageReadingProgress` 相当。
/// 詳細は #15。
abstract interface class SessionDataPurger {
  /// 何を消すかの説明（ログ用）。
  String get debugLabel;

  Future<void> purgeSessionData();
}

/// 登録済みの破棄処理。
///
/// 端末内にユーザー固有のデータを持つ機能は、ここに実装を足す（進捗 #12）。
@Riverpod(keepAlive: true)
List<SessionDataPurger> sessionDataPurgers(Ref ref) => [
  ref.watch(libraryCachePurgerProvider),
  ref.watch(imageCachePurgerProvider),
  ref.watch(downloadedVolumePurgerProvider),
];
