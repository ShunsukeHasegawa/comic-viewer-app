import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/cache/image_cache_store.dart';
import '../../../core/media/media_urls.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/book_detail.dart';
import '../../../domain/models/read_volume.dart';
import '../../../domain/models/reading_book.dart';
import '../../library/domain/library_snapshot.dart';
import 'offline_metadata_store.dart';

part 'offline_catalog.g.dart';

/// オフライン再生で使うメタ情報の出し入れ（#11）。
///
/// 保存するのは「圏外でも一覧 → 詳細 → ビューアまで辿れる」ために必要な分だけ:
/// - 一覧（`/api/books`）と ETag、未読 / お気に入り
/// - カテゴリ / タグ（絞り込みチップが消えると解除できなくなる）
/// - **ダウンロード済みタイトル**の詳細と、**ダウンロード済み巻**の `ReadVolume`
///
/// 未ダウンロードのタイトルまで溜め込まないのは、消す条件が無くなって端末の容量を
/// 食い続けるため（掃除は [retain] がダウンロード台帳を基準に行う）。
class OfflineCatalog {
  OfflineCatalog({
    required this.store,
    required this.urls,
    required this.imageCache,
  });

  /// 一覧のキー。
  static const libraryKey = 'books';
  static const categoriesKey = 'categories';
  static const tagsKey = 'tags';
  static const bookPrefix = 'book/';
  static const volumePrefix = 'volume/';

  final OfflineMetadataStore store;

  /// サムネイルのキャッシュキーを作るため（URL の組み立ては MediaUrls だけ）。
  final MediaUrls urls;

  /// ログアウトまでキャッシュディレクトリを作らせないため遅延させる。
  final Future<ImageCacheStore> Function() imageCache;

  // ------------------------------------------------------------------ 一覧

  Future<LibrarySnapshot?> readLibrary() async {
    final entry = await store.read(libraryKey);
    if (entry == null) return null;
    try {
      final books = [
        for (final json in _objectList(entry.payload['books']))
          Book.fromJson(json),
      ];
      final status = entry.payload['user_status'];
      return LibrarySnapshot(
        books: books,
        etag: entry.etag,
        fetchedAt: entry.fetchedAt,
        userStatus: status is Map<String, dynamic>
            ? UserStatus.fromJson(status)
            : null,
      );
    } on Object {
      // 形が変わっていたら「無い」とみなす（起動を妨げない）。
      await store.delete([libraryKey]);
      return null;
    }
  }

  Future<void> writeLibrary(LibrarySnapshot snapshot) async {
    await store.write(
      libraryKey,
      payload: {
        'books': [for (final book in snapshot.books) book.toJson()],
        'user_status': snapshot.userStatus?.toJson(),
      },
      etag: snapshot.etag,
      fetchedAt: snapshot.fetchedAt,
    );
  }

  Future<void> deleteLibrary() => store.delete([libraryKey]);

  // ------------------------------------------------------ カテゴリ / タグ

  Future<List<Taxonomy>?> readCategories() => _readTaxonomy(categoriesKey);

  Future<void> writeCategories(List<Taxonomy> items) =>
      _writeTaxonomy(categoriesKey, items);

  Future<List<Taxonomy>?> readTags() => _readTaxonomy(tagsKey);

  Future<void> writeTags(List<Taxonomy> items) =>
      _writeTaxonomy(tagsKey, items);

  Future<List<Taxonomy>?> _readTaxonomy(String key) async {
    final entry = await store.read(key);
    if (entry == null) return null;
    try {
      return [
        for (final json in _objectList(entry.payload['items']))
          Taxonomy.fromJson(json),
      ];
    } on Object {
      await store.delete([key]);
      return null;
    }
  }

  Future<void> _writeTaxonomy(String key, List<Taxonomy> items) => store.write(
    key,
    payload: {
      'items': [for (final item in items) item.toJson()],
    },
  );

  // ------------------------------------------------------------ タイトル詳細

  Future<BookDetail?> readBookDetail(int bookId) async {
    final key = '$bookPrefix$bookId';
    final entry = await store.read(key);
    if (entry == null) return null;
    try {
      return BookDetail.fromJson(entry.payload);
    } on Object {
      await store.delete([key]);
      return null;
    }
  }

  /// タイトル詳細を保存する（**ダウンロード済みタイトルのみ**）。
  ///
  /// 巻のサムネイルには保護印を付ける。一覧のタイル（最新巻のサムネイル）も
  /// 同じ URL なので、これだけで一覧・詳細・巻末オーバーレイの表示が保てる。
  Future<void> writeBookDetail(BookDetail detail) async {
    await store.write('$bookPrefix${detail.id}', payload: detail.toJson());
    await _pin(detail.id, [
      for (final volume in detail.volumes) volume.thumbnail,
    ]);
  }

  // ---------------------------------------------------------------- 巻情報

  Future<ReadVolume?> readVolume(int volumeId) async {
    final key = '$volumePrefix$volumeId';
    final entry = await store.read(key);
    if (entry == null) return null;
    try {
      return ReadVolume.fromJson(entry.payload);
    } on Object {
      await store.delete([key]);
      return null;
    }
  }

  /// 巻情報を保存する（**ダウンロード済みの巻のみ**）。
  ///
  /// 巻末オーバーレイの次巻サムネイルも保護しておく（オフラインで巻末まで
  /// 読んだときに、次巻の表紙だけ欠けるのを防ぐ）。
  Future<void> writeVolume(ReadVolume volume) async {
    await store.write('$volumePrefix${volume.id}', payload: volume.toJson());
    await _pin(volume.book.id, [volume.nextVolumeThumbnail]);
  }

  // ------------------------------------------------------------------ 掃除

  /// ダウンロードが無くなったタイトル / 巻のメタ情報と保護印を捨てる。
  ///
  /// 一覧・カテゴリ・タグは残す（ダウンロードが 1 件も無くても、圏外起動で
  /// 一覧が真っ白になるのは避けたい）。
  Future<void> retain({
    required Set<int> bookIds,
    required Set<int> volumeIds,
  }) async {
    final stale = <String>[
      for (final key in await store.keysWithPrefix(bookPrefix))
        if (!bookIds.contains(_idOf(key, bookPrefix))) key,
      for (final key in await store.keysWithPrefix(volumePrefix))
        if (!volumeIds.contains(_idOf(key, volumePrefix))) key,
    ];
    await store.delete(stale);
    final cache = await imageCache();
    await cache.retainPins(bookIds);
  }

  /// 端末内のオフライン用メタ情報を全部捨てる（ログアウト / ユーザー切り替え）。
  Future<void> clear() async {
    await store.deleteAll();
    final cache = await imageCache();
    // 印だけ残すと、次のユーザーの画像が無関係なタイトルのために守られてしまう。
    await cache.retainPins(const {});
  }

  Future<void> _pin(int bookId, Iterable<String?> apiUrls) async {
    final keys = <String>[
      for (final apiUrl in apiUrls) ?urls.thumbnailCacheKey(apiUrl),
    ];
    if (keys.isEmpty) return;
    final cache = await imageCache();
    await cache.pin(bookId: bookId, keys: keys);
  }

  static int? _idOf(String key, String prefix) =>
      int.tryParse(key.substring(prefix.length));

  static List<Map<String, dynamic>> _objectList(Object? value) => [
    if (value is List)
      for (final item in value)
        if (item is Map<String, dynamic>) item,
  ];
}

@Riverpod(keepAlive: true)
OfflineCatalog offlineCatalog(Ref ref) => OfflineCatalog(
  store: ref.watch(offlineMetadataStoreProvider),
  urls: ref.watch(mediaUrlsProvider),
  imageCache: () => ref.read(imageCacheStoreProvider.future),
);

/// 一覧キャッシュを drift に永続化する（#11）。
///
/// [OfflineCatalog] をそのまま `LibraryCacheStore` として渡さないのは、
/// `clear()` の意味が違うため（一覧だけ消すのと、オフライン用メタ情報を
/// 全部消すのを混ぜない）。
class PersistentLibraryCacheStore implements LibraryCacheStore {
  const PersistentLibraryCacheStore(this._catalog);

  final OfflineCatalog _catalog;

  @override
  Future<LibrarySnapshot?> read() => _catalog.readLibrary();

  @override
  Future<void> write(LibrarySnapshot snapshot) =>
      _catalog.writeLibrary(snapshot);

  @override
  Future<void> clear() => _catalog.deleteLibrary();
}
