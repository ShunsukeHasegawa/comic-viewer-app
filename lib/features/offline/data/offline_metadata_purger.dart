import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/session_data_purger.dart';
import 'offline_catalog.dart';

part 'offline_metadata_purger.g.dart';

/// ログアウト / セッション失効 / ユーザー切り替えでオフライン用メタ情報を捨てる（#11 / #15）。
///
/// セーフモードはサーバー側が正（`is_unsafe` の巻はそもそも配信されない）ので、
/// 端末に残るのは「そのユーザーが見られたもの」だけ。ただし**別のユーザーに
/// 切り替わったあと**は話が別で、一覧や詳細がキャッシュ経由で見えてしまう。
/// セーフモード設定を変えた場合も同じ（前の設定で取った一覧が残る）。
/// どちらの場合も `AuthController` がこの破棄を通す。
class OfflineMetadataPurger implements SessionDataPurger {
  const OfflineMetadataPurger(this._catalog);

  final OfflineCatalog _catalog;

  @override
  String get debugLabel => 'offline metadata';

  @override
  Future<void> purgeSessionData() => _catalog.clear();
}

@Riverpod(keepAlive: true)
SessionDataPurger offlineMetadataPurger(Ref ref) =>
    OfflineMetadataPurger(ref.watch(offlineCatalogProvider));
