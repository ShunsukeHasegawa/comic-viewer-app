import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show InsertMode;
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
/// ページを読むときの展開コストは #11 で計測し、**一時キャッシュへ写さない**
/// ことにした（`ZipDownloadedPageSource` のコメント参照。セントラルディレクトリと
/// 対象エントリだけを読むので数ミリ秒で済み、二重にディスクを使う方が損）。
///
/// ファイル構成（アプリ専用領域の `downloads/` 配下）:
/// ```
/// downloads/{volumeId}/{filesVersion}.zip           完了したアーカイブ
/// downloads/{volumeId}/{filesVersion}.zip.download  OS の転送が書いている途中（#10）
/// downloads/{volumeId}/{filesVersion}.json          マニフェスト（#11 のページ解決用）
/// downloads/{volumeId}/{filesVersion}.zip.part      旧 Dio 経路の途中ファイル（[sweep] で消す）
/// ```
///
/// 取得中のファイルを `.part` ではなく `.zip.download` にしたのは、旧 Dio 経路の
/// 部分ファイル（Range で続きを足せる前提のもの）と、OS の転送が握っている
/// ファイルを名前だけで区別するため。混ざると「どちらの続きか」が分からない。
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

  /// ログインセッションごとのタグ（転送タスク ID に埋め込む）の保存キー。
  static const sessionTagKey = 'downloads.session_tag';

  static const _sessionTagLength = 12;
  static const _sessionTagAlphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static final _sessionTagPattern = RegExp(r'^[A-Za-z0-9]+$');

  static const _stagingSuffix = '.zip.download';
  static const _legacyPartSuffix = '.zip.part';

  Directory volumeDirectory(int volumeId) =>
      Directory(p.join(directories.downloads.path, '$volumeId'));

  /// 完了済みアーカイブ（#11 はこのファイルからページを取り出す）。
  File archiveFile({required int volumeId, required int filesVersion}) =>
      File(p.join(volumeDirectory(volumeId).path, '$filesVersion.zip'));

  /// OS の転送（background_downloader）が書き込む一時ファイル。
  ///
  /// 完了して検証が通るまでは `.zip` にしないので、途中のデータが
  /// 「ダウンロード済み」と誤認されることがない。
  File stagingFile({required int volumeId, required int filesVersion}) => File(
    p.join(volumeDirectory(volumeId).path, stagingFilename(filesVersion)),
  );

  /// [stagingFile] のファイル名（転送の依頼にはディレクトリと分けて渡す）。
  static String stagingFilename(int filesVersion) =>
      '$filesVersion$_stagingSuffix';

  /// [stagingFile] の置き場を、application support からの相対パスで返す。
  ///
  /// 転送の依頼に絶対パスを渡さないのは、iOS ではアプリの更新でコンテナの
  /// パスが変わり、アプリが死んでいる間に完了した転送の保存先がずれるため。
  /// OS 側は同じ相対パスを application support から解決するので、
  /// [AppDirectories.downloads] が `support/downloads` であることが前提になる
  /// （変えるとここで作る相対パスと実際の置き場が食い違う）。区切りは OS に
  /// かかわらず `/`（Android / iOS のネイティブ側がそのまま解釈する）。
  String stagingDirectoryRelative(int volumeId) {
    assert(
      p.equals(
        directories.downloads.path,
        p.join(directories.support.path, 'downloads'),
      ),
      'downloads は application support 直下でなければならない',
    );
    return 'downloads/$volumeId';
  }

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
            // 確定時刻は世代ごとに 1 回だけ決める（キューが確定時に入れる）。
            // 同じ完了行を書き直すたびに進めると、自動削除の時計が進まない。
            // 入っていない完了行は今を使う（早く消す側には倒れない）。
            completedAt: download.isCompleted
                ? (download.completedAt ?? timestamp)
                : null,
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
  ///
  /// 1 件消せなくても残りは消し、最後に最初の失敗を投げる。黙って成功扱いに
  /// すると、破棄の印（`SessionPurgeJournal`）が消えて前のユーザーの ZIP が
  /// 端末に残り続ける（#15）。
  Future<void> deleteAllFiles() async {
    final directory = directories.downloads;
    if (!directory.existsSync()) return;
    FileSystemException? firstError;
    for (final entity in directory.listSync()) {
      try {
        await entity.delete(recursive: true);
      } on FileSystemException catch (error) {
        firstError ??= error;
      }
    }
    if (firstError != null) throw firstError;
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
      stagingFilename(keepFilesVersion),
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

  /// 今のログインセッションのタグ。無ければ作って保存する。
  ///
  /// タグは転送タスクの ID に入り、アプリの再起動を跨いで「自分のセッションの
  /// 転送か」を見分ける材料になる。そのため**毎回作り直さず**永続化する
  /// （再起動のたびに変わると、アプリが死んでいる間に終わった転送を
  /// 取り込めなくなる）。
  Future<String> readSessionTag() async {
    final stored = await _readSessionTagRow();
    if (stored != null && _sessionTagPattern.hasMatch(stored)) return stored;

    final generated = _generateSessionTag();
    if (stored == null) {
      // 同時に呼ばれても 1 つのタグに揃うよう、先に書いた方を正とする。
      await database
          .into(database.settings)
          .insert(
            SettingRow(key: sessionTagKey, value: generated),
            mode: InsertMode.insertOrIgnore,
          );
      return await _readSessionTagRow() ?? generated;
    }
    // 壊れた値はタスク ID に埋め込めない（parse できない）ので上書きする。
    await _writeSessionTag(generated);
    return generated;
  }

  /// タグを作り直す（ログアウト時）。前のユーザーの転送の完了が後から
  /// 届いても、タグが違うので取り込まれない（#15）。
  Future<String> rotateSessionTag() async {
    final generated = _generateSessionTag();
    await _writeSessionTag(generated);
    return generated;
  }

  Future<String?> _readSessionTagRow() async {
    final row = await (database.select(
      database.settings,
    )..where((table) => table.key.equals(sessionTagKey))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _writeSessionTag(String value) => database
      .into(database.settings)
      .insertOnConflictUpdate(SettingRow(key: sessionTagKey, value: value));

  /// 暗号論的な乱数にする。タスク ID は OS 側の記録に残るので、前の
  /// セッションのタグと偶然一致しない（= 前のユーザーの転送を取り込まない）
  /// ことが重要。
  static String _generateSessionTag() {
    final random = Random.secure();
    return String.fromCharCodes([
      for (var i = 0; i < _sessionTagLength; i++)
        _sessionTagAlphabet.codeUnitAt(
          random.nextInt(_sessionTagAlphabet.length),
        ),
    ]);
  }

  /// 台帳とも生きている転送とも結びつかないファイルを片付ける（起動時の
  /// 突き合わせの最後に呼ぶ）。
  ///
  /// 消すもの:
  /// - 台帳に無い巻のディレクトリ（削除の途中で落ちた・ログアウト後の残り）
  /// - [liveStagingPaths]（絶対パス）に無い `.zip.download`（OS 側のタスクが
  ///   消えた転送の残り）
  /// - 旧 Dio 経路の `.zip.part`（新しい経路では続きに使えない）
  /// - 台帳の世代でも、生きている転送の世代でもない `{v}.json`
  ///
  /// 台帳の世代の `{v}.zip` は消さない（オフラインで読める実体そのもの）。
  /// それ以外の世代の `.zip` は、取り直しの完了時に [deleteOtherVersions] が
  /// 片付けるのでここでは触らない（判断材料が少ない場面で ZIP を消さない）。
  ///
  /// 掃除は最善努力で、**例外は投げない**。消せなかったものは次の起動で
  /// もう一度試せばよく、ここで失敗させると起動時の復元が止まってしまう。
  Future<void> sweep({
    required Map<int, VolumeDownload> ledger,
    required Set<String> liveStagingPaths,
  }) async {
    final root = directories.downloads;
    try {
      if (!root.existsSync()) return;
      final live = {for (final path in liveStagingPaths) p.normalize(path)};
      for (final entity in root.listSync()) {
        if (entity is! Directory) continue;
        final volumeId = int.tryParse(p.basename(entity.path));
        // 数字でない名前は巻のディレクトリではないので触らない。
        if (volumeId == null) continue;
        await _sweepVolume(entity, ledger[volumeId], live);
      }
    } on FileSystemException {
      // 一覧すら取れない場合も、次の起動で試し直せばよい。
    }
  }

  Future<void> _sweepVolume(
    Directory directory,
    VolumeDownload? row,
    Set<String> live,
  ) async {
    try {
      final liveHere = <String>{};
      final liveVersions = <int>{};
      for (final path in live) {
        if (!p.equals(p.dirname(path), directory.path)) continue;
        final name = p.basename(path);
        liveHere.add(name);
        if (_versionOf(name, _stagingSuffix) case final version?) {
          liveVersions.add(version);
        }
      }

      // 台帳に無く、生きている転送も無い巻は丸ごと要らない。生きている転送が
      // あれば残す（突き合わせで取り消し損ねても、書き込み先を消さない）。
      if (row == null && liveHere.isEmpty) {
        await directory.delete(recursive: true);
        return;
      }

      for (final entity in directory.listSync()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!_isSweepable(name, row, liveHere, liveVersions)) continue;
        try {
          await entity.delete();
        } on FileSystemException {
          // 1 件消せなくても残りは消す。
        }
      }
    } on FileSystemException {
      // 途中で消えた・読めないディレクトリは次の起動に回す。
    }
  }

  static bool _isSweepable(
    String name,
    VolumeDownload? row,
    Set<String> liveHere,
    Set<int> liveVersions,
  ) {
    if (name.endsWith(_legacyPartSuffix)) return true;
    if (name.endsWith(_stagingSuffix)) return !liveHere.contains(name);
    final version = _versionOf(name, '.json');
    if (version == null) return false;
    // 転送中の世代の json は投入前に書いてある（アプリが死んでいる間に
    // 完了しても、オフラインでページを解決できるように）ので残す。
    return version != row?.filesVersion && !liveVersions.contains(version);
  }

  /// `{filesVersion}{suffix}` の形なら filesVersion、違えば `null`。
  static int? _versionOf(String name, String suffix) {
    if (!name.endsWith(suffix)) return null;
    return int.tryParse(name.substring(0, name.length - suffix.length));
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
