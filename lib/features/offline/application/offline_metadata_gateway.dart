import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/models/book_detail.dart';
import '../../../domain/models/read_volume.dart';
import '../../../domain/models/reading_book.dart';
import '../../downloads/data/download_store.dart';
import '../../downloads/domain/volume_download.dart';
import '../data/offline_catalog.dart';
import '../domain/offline_read_volume.dart';

part 'offline_metadata_gateway.g.dart';

/// 画面（コントローラ）から使うオフライン用メタ情報の口（#11）。
///
/// drift とダウンロード台帳の両方を触るので、画面側からは 1 つの抽象に見せる。
/// **オフライン保持に触る経路をここ 1 本にまとめる**ことで、テストでは 1 つ
/// 差し替えるだけで済む（DB もキャッシュディレクトリも作らずに、圏外の分岐だけを
/// 確かめられる）。
abstract interface class OfflineMetadataGateway {
  /// 端末にある巻情報。ダウンロード済みでなければ `null`（= 開けない）。
  Future<ReadVolume?> readVolume(int volumeId);

  /// 巻情報を控える。**ダウンロード済みの巻だけ**保存する。
  Future<void> saveVolume(ReadVolume volume);

  /// 端末にあるタイトル詳細。
  Future<BookDetail?> readBookDetail(int bookId);

  /// タイトル詳細を控える。**ダウンロード済みの巻を持つタイトルだけ**保存する。
  Future<void> saveBookDetail(BookDetail detail);

  /// 控えてあるカテゴリ（絞り込みチップ）。無ければ `null`。
  Future<List<Taxonomy>?> readCategories();

  Future<void> saveCategories(List<Taxonomy> items);

  /// 控えてあるタグ。無ければ `null`。
  Future<List<Taxonomy>?> readTags();

  Future<void> saveTags(List<Taxonomy> items);

  /// ダウンロードが無くなったタイトル / 巻の控えを捨てる。
  Future<void> prune();
}

/// 何も控えない実装（オフライン保持を使わない経路 / テストの既定）。
class NoOfflineMetadataGateway implements OfflineMetadataGateway {
  const NoOfflineMetadataGateway();

  @override
  Future<ReadVolume?> readVolume(int volumeId) async => null;

  @override
  Future<void> saveVolume(ReadVolume volume) async {}

  @override
  Future<BookDetail?> readBookDetail(int bookId) async => null;

  @override
  Future<void> saveBookDetail(BookDetail detail) async {}

  @override
  Future<List<Taxonomy>?> readCategories() async => null;

  @override
  Future<void> saveCategories(List<Taxonomy> items) async {}

  @override
  Future<List<Taxonomy>?> readTags() async => null;

  @override
  Future<void> saveTags(List<Taxonomy> items) async {}

  @override
  Future<void> prune() async {}
}

/// drift（[OfflineCatalog]）とダウンロード台帳（[DownloadStore]）を使う実装。
class CatalogOfflineMetadataGateway implements OfflineMetadataGateway {
  CatalogOfflineMetadataGateway({
    required this.catalog,
    required this.downloads,
  });

  final OfflineCatalog catalog;

  /// ダウンロード領域を使うまで DB / ディレクトリを作らせないため遅延させる。
  final Future<DownloadStore> Function() downloads;

  @override
  Future<ReadVolume?> readVolume(int volumeId) async {
    final store = await downloads();
    final download = await store.find(volumeId);
    // 「completed か」ではなく「台帳の世代の実体があるか」で判断する。
    // 「更新あり」の取り直し中（queued / downloading）やその途中でアプリが
    // 落ちた後（paused）も、台帳は旧世代を指したままで ZIP も残っている。
    // status で弾くと、手元に完全な ZIP があるのに開けなくなる（#11 のレビュー指摘）。
    if (download == null || !download.hasInstalledArchive) return null;
    if (!store
        .archiveFile(volumeId: volumeId, filesVersion: download.filesVersion)
        .existsSync()) {
      // 台帳は指しているのに実体が無い（外部から消された）。開いても真っ黒に
      // なるだけなので開かせない。
      return null;
    }

    final stored = await catalog.readVolume(volumeId);
    // 控えが手元の ZIP と同じ世代なら、それだけで開ける。マニフェスト（ファイル
    // 読み出し）と詳細まで引くのは、組み立て直しが必要なときだけにする。
    final needsRebuild =
        stored == null ||
        stored.files.isEmpty ||
        stored.filesVersion != download.filesVersion;

    return buildOfflineReadVolume(
      volumeId: volumeId,
      download: download,
      stored: stored,
      detail: needsRebuild
          ? await catalog.readBookDetail(download.bookId)
          : null,
      manifest: needsRebuild
          ? await store.readManifest(
              volumeId: volumeId,
              filesVersion: download.filesVersion,
            )
          : null,
    );
  }

  @override
  Future<void> saveVolume(ReadVolume volume) async {
    final store = await downloads();
    final download = await store.find(volume.id);
    // 端末に無い巻を控えても、ページが出せないので意味が無い（容量だけ食う）。
    if (download == null || !download.hasInstalledArchive) return;
    await catalog.writeVolume(volume);
  }

  @override
  Future<BookDetail?> readBookDetail(int bookId) =>
      catalog.readBookDetail(bookId);

  @override
  Future<void> saveBookDetail(BookDetail detail) async {
    final store = await downloads();
    final ledger = await store.loadAll();
    final hasDownload = ledger.values.any(
      (download) =>
          download.bookId == detail.id && download.hasInstalledArchive,
    );
    if (!hasDownload) return;
    await catalog.writeBookDetail(detail);
  }

  @override
  Future<List<Taxonomy>?> readCategories() => catalog.readCategories();

  @override
  Future<void> saveCategories(List<Taxonomy> items) =>
      catalog.writeCategories(items);

  @override
  Future<List<Taxonomy>?> readTags() => catalog.readTags();

  @override
  Future<void> saveTags(List<Taxonomy> items) => catalog.writeTags(items);

  /// 台帳（DB）を基準に掃除する。
  ///
  /// キュー（メモリ上の状態）ではなく台帳を見るのは、まだキューを組み立てて
  /// いない起動直後にも掃除できるようにするため。
  ///
  /// 残す条件は「**台帳に行があるか**」で、完了しているかは見ない（#11 の
  /// レビュー指摘）。「更新あり」の取り直し中に一覧を読み込むと、行が完了では
  /// ないせいで詳細・巻情報・サムネイルの保護印まで消えてしまう。取り直しが
  /// 失敗して台帳が旧世代（completed）へ戻っても控えは戻らないので、読める
  /// ZIP があるのに圏外で詳細が開けなくなる。ユーザーが削除すれば行ごと
  /// 消えるので、「行がある」を条件にしても溜め込みは起きない。
  @override
  Future<void> prune() async {
    final store = await downloads();
    final ledger = await store.loadAll();
    await catalog.retain(
      bookIds: ledgerBookIds(ledger),
      volumeIds: ledger.keys.toSet(),
    );
  }
}

@Riverpod(keepAlive: true)
OfflineMetadataGateway offlineMetadataGateway(Ref ref) =>
    CatalogOfflineMetadataGateway(
      catalog: ref.watch(offlineCatalogProvider),
      downloads: () => ref.read(downloadStoreProvider.future),
    );
