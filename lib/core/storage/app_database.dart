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

/// オフラインでも失わない読書進捗（#12）。
///
/// ページ送りのたびにここへ書き、オンラインのときに一括同期 API へ送る。
/// 「送信済み（[synced]）」を行ごとに持つのは、**送れなかった進捗を再送しても
/// 他端末の進捗を巻き戻さない**ため。送信できた行だけ `synced` を立て、
/// サーバーの方が新しかった行はサーバー値で上書きする。
///
/// Web 版（localStorage）は未送信 1 件だけだったが、オフラインでは複数巻を
/// 読み進められるので巻ごとに 1 行持つ。
@DataClassName('ReadingProgressRow')
class ReadingProgresses extends Table {
  IntColumn get volumeId => integer()();

  /// 表示していたページ（1 始まり）。`min(page, files.length)` に丸めた値。
  IntColumn get currentPage => integer()();

  /// 巻のページ数。0 ページ（ZIP が無い）の巻は行を作らない。
  IntColumn get maxPage => integer()();

  /// 端末が読んだと申告する時刻。一括同期 API の新旧比較はこの値同士で行う。
  DateTimeColumn get readAt => dateTime()();

  /// サーバーへ反映済みか。`false` の行だけを送る。
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {volumeId};
}

/// オフライン再生のためのメタ情報（#11）。
///
/// 一覧 / タイトル詳細 / 巻情報 / カテゴリ・タグを **JSON のまま**キーで持つ。
/// 列に展開しないのは、オフラインで必要なのが「キーで丸ごと引く」用途だけで、
/// 絞り込みや並び替えは取り出した後にメモリ上で行うため。列に割ると API の形が
/// 変わるたびにマイグレーションが必要になる（読めない payload は捨てればよい）。
@DataClassName('OfflineMetadataRow')
class OfflineMetadataEntries extends Table {
  @override
  String get tableName => 'offline_metadata';

  /// `books` / `categories` / `tags` / `book/{bookId}` / `volume/{volumeId}`。
  TextColumn get key => text()();

  /// モデルの `toJson()` をそのまま入れた JSON。
  TextColumn get payload => text()();

  /// 次回の `If-None-Match` に使う（一覧のみ）。
  TextColumn get etag => text().nullable()();

  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// 一時キャッシュの LRU / 保持期間で消してはいけない画像（#11）。
///
/// ダウンロード済みタイトルのサムネイルは、オフラインで一覧 / 詳細を出すために
/// 必須なので LRU の対象から外す。ページ画像と違い ZIP から作り直せないため、
/// 一度消えるとオンラインに戻るまで復活しない。
///
/// 実体は [CachedImages] 側にあり、この表は「消さない印」だけを持つ。
/// **まだ取得していないキーも印だけ先に置ける**（あとで書かれた実体が守られる）。
@DataClassName('PinnedImageRow')
class PinnedImages extends Table {
  /// キャッシュキー（`MediaUrls.thumbnailCacheKey`）。
  TextColumn get key => text()();

  /// どのタイトルのために保護しているか（ダウンロードを消したら印も消す）。
  IntColumn get bookId => integer()();

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
@DriftDatabase(
  tables: [
    CachedImages,
    Settings,
    DownloadedVolumes,
    ReadingProgresses,
    OfflineMetadataEntries,
    PinnedImages,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'comic_laz'));

  @override
  int get schemaVersion => 4;

  /// 既存の端末を作り直さずに列 / テーブルを足す。
  ///
  /// キャッシュのテーブルは作り直しても実害が無いが、ダウンロード済みの巻は
  /// 端末にしか無いデータなので、DB を消す形の移行はしない。
  /// DB を新しく作ったときにだけ書く目印のキー（`InstallMarker`。#15）。
  static const freshInstallKey = 'install.fresh';

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // 入れ直し直後の目印。iOS の Keychain はアプリの削除で消えないので、
      // 前のインストールのトークンで自動ログインさせないために使う
      // （既存の端末は onUpgrade を通るので書かれない）。
      await into(settings)
          .insert(const SettingRow(key: freshInstallKey, value: '1'));
    },
    onUpgrade: (m, from, to) async {
      // v2: 巻単位のダウンロード管理（#9）。
      if (from < 2) await m.createTable(downloadedVolumes);
      // v3: オフライン進捗のキュー（#12）。未送信の進捗は端末にしか無い。
      if (from < 3) await m.createTable(readingProgresses);
      // v4: オフライン再生のメタ情報とサムネイルの保護（#11）。
      // どちらも取り直せるデータなので、作るだけでよい。
      if (from < 4) {
        await m.createTable(offlineMetadataEntries);
        await m.createTable(pinnedImages);
      }
    },
  );
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
}
