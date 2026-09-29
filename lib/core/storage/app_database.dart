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

/// 巻ダウンロードの状態（#9）。
enum VolumeDownloadStatus {
  /// 順番待ち（同時実行数の制限で待っている）。
  queued,

  /// 取得中。
  downloading,

  /// 中断（ユーザー操作 / アプリの終了）。一時ファイルは残す。
  paused,

  /// 失敗（通信・検証）。理由は `failureReason`。
  failed,

  /// 検証まで通って保存済み。
  completed,
}

/// ダウンロード済み（と、その途中）の巻。
///
/// 一時キャッシュ（[CachedImages]）とは**別テーブル・別ディレクトリ**で管理する。
/// LRU や保持期間で勝手に消さないため（明示的に落としたものは明示的にしか消えない）。
@DataClassName('DownloadedVolumeRow')
class DownloadedVolumes extends Table {
  IntColumn get volumeId => integer()();

  /// タイトル単位の一括操作（#10 / #13）で使う。
  IntColumn get bookId => integer()();

  /// 取得した内容のバージョン（ZIP の mtime）。
  ///
  /// サーバー側の `files_version` と食い違ったら「更新あり」。
  IntColumn get filesVersion => integer()();

  TextColumn get status => textEnum<VolumeDownloadStatus>()();

  /// 取得済みバイト数（表示用。再開位置は一時ファイルの実サイズを正とする）。
  IntColumn get receivedBytes => integer().withDefault(const Constant(0))();

  /// ZIP 全体のバイト数（マニフェストの `archive_bytes`）。
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();

  /// マニフェストのページ数（検証と #11 のページ解決に使う）。
  IntColumn get pageCount => integer().withDefault(const Constant(0))();

  /// アーカイブの検証子。再開時の `If-Range` に使う。
  TextColumn get archiveEtag => text().nullable()();

  /// 失敗理由（ユーザーに見せる日本語）。
  TextColumn get failureReason => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {volumeId};
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
/// #12 以降で進捗キュー・一覧キャッシュのテーブルを足す。
@DriftDatabase(tables: [CachedImages, Settings, DownloadedVolumes])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'comic_laz'));

  @override
  int get schemaVersion => 2;

  /// 既存の端末を作り直さずに列 / テーブルを足す。
  ///
  /// キャッシュのテーブルは作り直しても実害が無いが、ダウンロード済みの巻は
  /// 端末にしか無いデータなので、DB を消す形の移行はしない。
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2: 巻単位のダウンロード管理（#9）。
      if (from < 2) await m.createTable(downloadedVolumes);
    },
  );
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
}
