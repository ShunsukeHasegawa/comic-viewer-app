import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';

part 'install_marker.g.dart';

/// 入れ直し直後かの目印（#15）。
///
/// iOS の Keychain はアプリを削除しても残る（`first_unlock_this_device` でも同じ）。
/// 何もしないと、アプリを消して入れ直した端末が**前の持ち主のトークンで
/// 自動ログイン**してしまう（端末を人に渡す前に「アプリを消せばログアウト
/// できる」と考えるのは自然）。ログアウトを経ていないので、破棄の印も働かない。
///
/// DB はアプリの領域にあり削除で消えるので、DB を**新しく作ったとき**
/// （[AppDatabase] の `onCreate`）にだけ目印を書く。既存の端末は `onUpgrade` を
/// 通るので目印が無く、アップデートでログアウトされることはない。
abstract interface class InstallMarker {
  /// DB を作ってから、前のインストールの認証情報をまだ片付けていないか。
  Future<bool> isFreshInstall();

  /// 片付け終えた（次の起動からは何もしない）。
  Future<void> markHandled();
}

/// drift の Settings テーブルに置く実装。
class DriftInstallMarker implements InstallMarker {
  DriftInstallMarker(this._database);

  final AppDatabase _database;

  @override
  Future<bool> isFreshInstall() async {
    final row =
        await (_database.select(_database.settings)
              ..where((t) => t.key.equals(AppDatabase.freshInstallKey)))
            .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> markHandled() async {
    await (_database.delete(
      _database.settings,
    )..where((t) => t.key.equals(AppDatabase.freshInstallKey))).go();
  }
}

@Riverpod(keepAlive: true)
InstallMarker installMarker(Ref ref) =>
    DriftInstallMarker(ref.watch(appDatabaseProvider));
