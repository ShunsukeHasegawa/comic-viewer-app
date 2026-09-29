import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/app_directories.dart';
import '../../../domain/models/volume_manifest.dart';
import '../domain/volume_download.dart';

part 'download_store.g.dart';

/// ダウンロード済みデータの置き場と台帳。
///
/// **ZIP のまま保持する**（展開して 1 ページ 1 ファイルにはしない）。理由:
/// - 1 巻 = 1 ファイルなので「一時ファイル → rename」で完了を原子的に切り替えられる。
///   展開方式だと数百ファイルの書き込み途中で落ちたときに「半分だけ展開済み」を
///   自分で片付ける必要がある。
/// - 展開中は ZIP と展開後が両方ディスクに載るため、一時的に容量が約 2 倍必要になる。
/// - 削除が 1 ディレクトリの削除で済む。
/// - 検証（サイズ / ZIP として開けるか / ページ数）が取得直後にそのまま行える。
/// ページを読むときの展開コストは #11 で計測し、遅ければ読んだページだけ
/// 一時キャッシュ（#8）へ逃がす。
///
/// ファイル構成（アプリ専用領域の `downloads/` 配下）:
/// ```
/// downloads/{volumeId}/{filesVersion}.zip       完了したアーカイブ
/// downloads/{volumeId}/{filesVersion}.zip.part  取得中（再開の起点）
/// downloads/{volumeId}/{filesVersion}.json      マニフェスト（#11 のページ解決用）
/// ```
class DownloadStore {
  DownloadStore({
    required this.database,
    required this.directories,
    this.now = DateTime.now,
  });

  final AppDatabase database;
  final AppDirectories directories;

  /// 現在時刻（テストから決められるようにする）。
  final DateTime Function() now;

  Directory volumeDirectory(int volumeId) =>
      Directory(p.join(directories.downloads.path, '$volumeId'));

  /// 完了済みアーカイブ（#11 はこのファイルからページを取り出す）。
  File archiveFile({required int volumeId, required int filesVersion}) =>
      File(p.join(volumeDirectory(volumeId).path, '$filesVersion.zip'));

  /// 取得中の一時ファイル。**完了するまで拡張子を変えない**ので、
  /// 途中のデータが「ダウンロード済み」と誤認されることがない。
  File partFile({required int volumeId, required int filesVersion}) =>
      File(p.join(volumeDirectory(volumeId).path, '$filesVersion.zip.part'));

  File manifestFile({required int volumeId, required int filesVersion}) =>
      File(p.join(volumeDirectory(volumeId).path, '$filesVersion.json'));

  /// 台帳の全件（巻 ID をキーにした表）。
  Future<Map<int, VolumeDownload>> loadAll() async {
    final rows = await database.select(database.downloadedVolumes).get();
    return {for (final row in rows) row.volumeId: VolumeDownload.fromRow(row)};
  }

  Future<VolumeDownload?> find(int volumeId) async {
    final row = await (database.select(
      database.downloadedVolumes,
    )..where((table) => table.volumeId.equals(volumeId))).getSingleOrNull();
    return row == null ? null : VolumeDownload.fromRow(row);
  }

  /// 台帳を書く（新規 / 更新）。
  Future<void> save(VolumeDownload download) async {
    final timestamp = now();
    await database
        .into(database.downloadedVolumes)
        .insertOnConflictUpdate(
          DownloadedVolumeRow(
            volumeId: download.volumeId,
            bookId: download.bookId,
            filesVersion: download.filesVersion,
            status: download.status,
            receivedBytes: download.receivedBytes,
            totalBytes: download.totalBytes,
            pageCount: download.pageCount,
            archiveEtag: download.archiveEtag,
            failureReason: download.failureReason,
            updatedAt: timestamp,
            completedAt: download.isCompleted ? timestamp : null,
          ),
        );
  }

  /// 台帳から消す（実体は [deleteFiles] で消す）。
  Future<void> deleteRow(int volumeId) async {
    await (database.delete(
      database.downloadedVolumes,
    )..where((table) => table.volumeId.equals(volumeId))).go();
  }

  Future<void> deleteAllRows() async {
    await database.delete(database.downloadedVolumes).go();
  }

  /// 巻のディレクトリごと消す。
  Future<void> deleteFiles(int volumeId) async {
    final directory = volumeDirectory(volumeId);
    if (!directory.existsSync()) return;
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      // 実体を消せなくても台帳は消す（次の取得で上書きされる）。
      // ここで投げると「削除できません」になり、ユーザーは何もできなくなる。
    }
  }

  /// ダウンロード領域を丸ごと空にする（ログアウト時）。
  Future<void> deleteAllFiles() async {
    final directory = directories.downloads;
    if (!directory.existsSync()) return;
    for (final entity in directory.listSync()) {
      try {
        await entity.delete(recursive: true);
      } on FileSystemException {
        // 1 件消せなくても残りは消す。
      }
    }
  }

  /// 保存先を用意する。
  Future<void> ensureVolumeDirectory(int volumeId) async {
    final directory = volumeDirectory(volumeId);
    if (!directory.existsSync()) await directory.create(recursive: true);
  }

  /// 同じ巻の**別世代**のファイルを消す（更新を落とし直したあとの掃除）。
  Future<void> deleteOtherVersions({
    required int volumeId,
    required int keepFilesVersion,
  }) async {
    final directory = volumeDirectory(volumeId);
    if (!directory.existsSync()) return;
    final keep = {
      '$keepFilesVersion.zip',
      '$keepFilesVersion.zip.part',
      '$keepFilesVersion.json',
    };
    for (final entity in directory.listSync()) {
      if (entity is! File) continue;
      if (keep.contains(p.basename(entity.path))) continue;
      try {
        await entity.delete();
      } on FileSystemException {
        // 消せなくても次の取得の邪魔はしない。
      }
    }
  }

  /// マニフェストを保存する（#11 がページ番号と拡張子の対応に使う）。
  Future<void> writeManifest(VolumeManifest manifest) async {
    final file = manifestFile(
      volumeId: manifest.id,
      filesVersion: manifest.filesVersion,
    );
    await file.writeAsString(jsonEncode(manifest.toJson()));
  }

  /// 保存済みマニフェスト。読めなければ `null`（ZIP は読めるので致命ではない）。
  Future<VolumeManifest?> readManifest({
    required int volumeId,
    required int filesVersion,
  }) async {
    final file = manifestFile(volumeId: volumeId, filesVersion: filesVersion);
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return null;
      return VolumeManifest.fromJson(json);
    } on Object {
      return null;
    }
  }

  /// ダウンロード済みの合計バイト数（設定画面の可視化は #13）。
  Future<int> totalBytes() async {
    final rows =
        await (database.select(database.downloadedVolumes)..where(
              (table) =>
                  table.status.equalsValue(VolumeDownloadStatus.completed),
            ))
            .get();
    return rows.fold<int>(0, (sum, row) => sum + row.totalBytes);
  }
}

@Riverpod(keepAlive: true)
Future<DownloadStore> downloadStore(Ref ref) async {
  return DownloadStore(
    database: ref.watch(appDatabaseProvider),
    directories: await ref.watch(appDirectoriesProvider.future),
  );
}
