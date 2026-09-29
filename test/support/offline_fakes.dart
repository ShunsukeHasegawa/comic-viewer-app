import 'package:comic_laz/core/config/app_config.dart';
import 'package:comic_laz/core/media/media_urls.dart';
import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/domain/models/read_volume.dart';
import 'package:comic_laz/domain/models/reading_book.dart';
import 'package:comic_laz/features/offline/application/offline_metadata_gateway.dart';
import 'package:comic_laz/features/offline/data/offline_catalog.dart';
import 'package:comic_laz/features/offline/data/offline_metadata_store.dart';

import 'cache_fakes.dart';

/// 端末に控えてあるメタ情報をテストから与える [OfflineMetadataGateway]。
///
/// drift もダウンロード領域も作らずに「圏外で控えを使う / 控えが無ければ開けない」
/// 分岐だけを確かめるために使う。
class FakeOfflineMetadataGateway implements OfflineMetadataGateway {
  FakeOfflineMetadataGateway({
    Map<int, ReadVolume> volumes = const {},
    Map<int, BookDetail> details = const {},
    this.categories,
    this.tags,
  }) : volumes = {...volumes},
       details = {...details};

  /// 控えてあるカテゴリ / タグ（`null` = 控えが無い）。
  List<Taxonomy>? categories;
  List<Taxonomy>? tags;

  /// ダウンロード済みとして控えてある巻。
  final Map<int, ReadVolume> volumes;

  /// ダウンロード済みタイトルとして控えてある詳細。
  final Map<int, BookDetail> details;

  final savedVolumes = <int>[];
  final savedDetails = <int>[];

  /// `prune()` が呼ばれた回数（掃除の契機の検証に使う）。
  int pruneCount = 0;

  @override
  Future<ReadVolume?> readVolume(int volumeId) async => volumes[volumeId];

  @override
  Future<void> saveVolume(ReadVolume volume) async =>
      savedVolumes.add(volume.id);

  @override
  Future<BookDetail?> readBookDetail(int bookId) async => details[bookId];

  @override
  Future<void> saveBookDetail(BookDetail detail) async =>
      savedDetails.add(detail.id);

  @override
  Future<List<Taxonomy>?> readCategories() async => categories;

  @override
  Future<void> saveCategories(List<Taxonomy> items) async => categories = items;

  @override
  Future<List<Taxonomy>?> readTags() async => tags;

  @override
  Future<void> saveTags(List<Taxonomy> items) async => tags = items;

  @override
  Future<void> prune() async => pruneCount++;
}

/// メモリ DB + 一時ディレクトリで動く [OfflineCatalog]。
///
/// サムネイルの保護印は本物の `ImageCacheStore` に書くので、LRU から守れている
/// ことまで同じ仕組みで確かめられる。
({
  OfflineCatalog catalog,
  OfflineMetadataStore store,
  CacheHarness cache,
  MediaUrls urls,
})
createOfflineCatalog({
  CacheHarness? cache,
  String apiBaseUrl = 'http://localhost:8000',
}) {
  final harness = cache ?? CacheHarness.create();
  final store = OfflineMetadataStore(
    database: harness.database,
    now: harness.clock.now,
  );
  final urls = MediaUrls(
    AppConfig.from(apiBaseUrl: apiBaseUrl, flavor: 'development'),
  );
  return (
    catalog: OfflineCatalog(
      store: store,
      urls: urls,
      imageCache: () async => harness.store,
    ),
    store: store,
    cache: harness,
    urls: urls,
  );
}
