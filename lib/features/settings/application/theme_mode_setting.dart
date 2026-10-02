import 'dart:developer' as developer;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/app_database.dart';
import '../../library/application/library_controller.dart' show noAutoRetry;

part 'theme_mode_setting.g.dart';

/// 表示テーマ（ライト / ダーク / システムに合わせる）の保存先（#17）。
///
/// 端末ごとの見た目の好みで、ユーザー固有のデータではない。ログアウトしても
/// 残す（`SessionDataPurger` には登録しない）。
abstract interface class ThemeModeStore {
  Future<ThemeMode> read();

  Future<void> write(ThemeMode mode);
}

/// drift の Settings に保存する [ThemeModeStore]。
class DriftThemeModeStore implements ThemeModeStore {
  DriftThemeModeStore(this._database);

  static const key = 'display.theme_mode';

  final AppDatabase _database;

  /// 未保存・知らない値は「システムに合わせる」（既定）として読む。
  /// 新しい版で選択肢を足した後に戻しても、起動できなくならないように。
  @override
  Future<ThemeMode> read() async {
    final row = await (_database.select(
      _database.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return ThemeMode.values.asNameMap()[row?.value] ?? ThemeMode.system;
  }

  @override
  Future<void> write(ThemeMode mode) => _database
      .into(_database.settings)
      .insertOnConflictUpdate(SettingRow(key: key, value: mode.name));
}

@Riverpod(keepAlive: true)
ThemeModeStore themeModeStore(Ref ref) =>
    DriftThemeModeStore(ref.watch(appDatabaseProvider));

/// 表示テーマの設定。
///
/// アプリ全体（`ComicLazApp`）が watch する。起動直後の切り替わりを避けるため、
/// `main` で最初の画面を描く前に [preloadThemeMode] で読み込んでおく。
///
/// 読めなかったときに自動で再試行しない。再試行の間（最大 40 秒ほど）は
/// 読み込み中として切り替えも塞がれ、そのうえ読めた時点で画面全体の色が
/// 前触れなく変わる。端末内の DB が読めないのは一時的なことではまず無いので、
/// 「読み込めなかった」と出して選び直してもらう（保存できればそれで直る）。
@Riverpod(keepAlive: true, retry: noAutoRetry)
class ThemeModeSetting extends _$ThemeModeSetting {
  @override
  Future<ThemeMode> build() => ref.watch(themeModeStoreProvider).read();

  /// 保存してから反映する（保存に失敗したら表示を変えず、例外を返す）。
  ///
  /// 先に反映すると、保存できていないのに切り替わったように見え、次の起動で
  /// 黙って元に戻る。
  Future<void> set(ThemeMode mode) async {
    await ref.read(themeModeStoreProvider).write(mode);
    if (!ref.mounted) return;
    state = AsyncData(mode);
  }
}

/// [preloadThemeMode] が待つ上限。
///
/// この間は OS のスプラッシュが出たまま。DB は直後のセッション復元
/// （入れ直しの目印の確認）でも開くので、ここで先に開いても起動全体は
/// ほとんど遅くならない。ただ移行などで遅いときに起動そのものを待たせないよう、
/// 上限を超えたら「システムに合わせる」で描き始める（読めた時点で切り替わる）。
const themeModePreloadTimeout = Duration(seconds: 1);

/// 最初の画面を描く前に、保存済みの表示テーマを読み込んでおく（#17）。
///
/// 読み込みを待たずに描くと、ダークを選んでいても最初の数フレームが
/// 「システムに合わせる」で描かれ、スプラッシュの後に一瞬切り替わって見える。
/// 読めなくても起動は止めない（テーマのために締め出さない）。そのときは
/// 「システムに合わせる」で表示し、設定画面に読み込めなかったことを出す。
Future<void> preloadThemeMode(
  ProviderContainer container, {
  Duration timeout = themeModePreloadTimeout,
}) async {
  try {
    await container.read(themeModeSettingProvider.future).timeout(timeout);
  } on Object catch (error, stackTrace) {
    developer.log(
      '表示テーマの設定を起動前に読み込めませんでした',
      name: 'ThemeModeSetting',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
