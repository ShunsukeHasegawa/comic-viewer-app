import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_database.g.dart';

/// キャッシュ / ダウンロードの種別。
enum CachedImageKind {
  /// ビューアのページ画像（大きい・数が多い）。
  page,

  /// サムネイル（小さい・数がとても多い）。
  thumbnail,
}

/// 一時キャッシュに置いた画像のメタ情報。
///
/// 実体はファイルで、ここには LRU と容量計算に必要な情報だけを持つ。
/// ダウンロード済みデータ（#9）は別テーブルで管理し、**LRU の対象にしない**。
@DataClassName('CachedImageRow')
class CachedImages extends Table {
  /// キャッシュキー（`MediaUrls.pageCacheKey` / `thumbnailCacheKey`）。
  TextColumn get key => text()();

  /// 種別（ページ / サムネイル）。上限を別枠で管理する。
  TextColumn get kind => textEnum<CachedImageKind>()();

  /// 保存先のファイル名（キャッシュディレクトリからの相対パス）。
  TextColumn get fileName => text()();

  IntColumn get bytes => integer()();

  /// 画像の Content-Type（表示時のヒント。不明なら null）。
  TextColumn get contentType => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  /// 最後に使った時刻（LRU の基準）。
  DateTimeColumn get lastUsedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// アプリ設定（キャッシュ上限など）の保存先。
///
/// 数が少なく型もばらばらなので、key-value で持つ。
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// ローカル DB。
///
/// #9 以降でダウンロード管理・進捗キュー・一覧キャッシュのテーブルを足す。
@DriftDatabase(tables: [CachedImages, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'comic_laz'));

  @override
  int get schemaVersion => 1;
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
}
