import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/cache/image_cache_store.dart';
import '../../../core/media/media_urls.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/book_detail.dart';
import '../../../domain/models/read_volume.dart';
import '../../../domain/models/reading_book.dart';
import '../../library/domain/library_snapshot.dart';
import 'library_payload_codec.dart';
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

  /// 一覧の本体（全タイトル）のキー。ETag / 取得時刻は同じ行の列に持つ。
  static const libraryKey = 'library/books';

  /// 未読 / お気に入りの控えのキー。
  ///
  /// 本体と分けるのは、お気に入りの切り替えのたびに数 MB の本体を
  /// decode / encode し直さないため（#26）。
  static const libraryUserStatusKey = 'library/user_status';

  /// #26 より前の一覧のキー（本体と `user_status` を 1 つの JSON に持っていた）。
  ///
  /// 見つけたら新しいキーへ移す（[_migrateLegacyLibrary]）。消さずに移すのは、
  /// 更新直後に圏外で起動しても一覧が出るようにするため。
  static const legacyLibraryKey = 'books';
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

  /// 旧形式の移し替えが済んだか（プロセス内で 1 度確かめれば十分）。
  bool _legacyLibraryChecked = false;

  /// 走行中の移し替え（無ければ `null`）。完了済みの future を握り続けないのは
  /// `LibraryRepository._cacheTask` と同じ理由（擬似時間のゾーンに縛られる）。
  Future<void>? _legacyLibraryMigration;

  /// ETag と取得時刻だけを読む（本体は DB から取り出しもしない）。
  Future<LibraryCacheHeader?> readLibraryHeader() async {
    await _migrateLegacyLibrary();
    final header = await store.readHeader(libraryKey);
    if (header == null) return null;
    return LibraryCacheHeader(etag: header.etag, fetchedAt: header.fetchedAt);
  }

  Future<LibrarySnapshot?> readLibrary() async {
    await _migrateLegacyLibrary();
    final entry = await store.readRaw(libraryKey);
    if (entry == null) return null;
    final List<Book> books;
    try {
      books = await LibraryPayloadCodec.decodeBooks(entry.payload);
    } on Object catch (error) {
      if (!_isMalformed(error)) rethrow;
      // 形が変わっていたら「無い」とみなす（起動を妨げない）。未読 / お気に入りは
      // 一覧と組で意味を持つので一緒に捨てる。
      await store.delete([libraryKey, libraryUserStatusKey]);
      return null;
    }
    return LibrarySnapshot(
      books: books,
      etag: entry.etag,
      fetchedAt: entry.fetchedAt,
      userStatus: await readLibraryUserStatus(),
    );
  }

  /// 未読 / お気に入りの控えだけを読む（本体は decode しない）。
  Future<UserStatus?> readLibraryUserStatus() async {
    await _migrateLegacyLibrary();
    final entry = await store.read(libraryUserStatusKey);
    if (entry == null) return null;
    try {
      return UserStatus.fromJson(entry.payload);
    } on Object {
      await store.delete([libraryUserStatusKey]);
      return null;
    }
  }

  /// 本体と ETag / 取得時刻を書く。
  ///
  /// [LibrarySnapshot.userStatus] が `null` なら未読 / お気に入りの控えは残す。
  Future<void> writeLibrary(LibrarySnapshot snapshot) async {
    await _migrateLegacyLibrary();
    final payload = await LibraryPayloadCodec.encodeBooks(snapshot.books);
    await store.writeRaw(
      libraryKey,
      payload: payload,
      etag: snapshot.etag,
      fetchedAt: snapshot.fetchedAt,
    );
    if (snapshot.userStatus case final status?) {
      await writeLibraryUserStatus(status);
    }
  }

  Future<void> writeLibraryUserStatus(UserStatus status) async {
    await _migrateLegacyLibrary();
    await store.write(libraryUserStatusKey, payload: status.toJson());
  }

  /// ETag だけを書き換える（304 で ETag だけ変わったときに本体を書き直さない）。
  Future<void> updateLibraryEtag(String? etag) async {
    await _migrateLegacyLibrary();
    await store.updateEtag(libraryKey, etag);
  }

  Future<void> deleteLibrary() async {
    await _awaitLegacyLibraryMigration();
    await store.delete([libraryKey, libraryUserStatusKey, legacyLibraryKey]);
  }

  /// #26 より前の形式の控えを、本体と未読 / お気に入りの 2 行に移す。
  ///
  /// 更新した端末の控えを捨てない（圏外で起動しても一覧が出るように）ため、
  /// DB のスキーマは変えずに、最初に一覧の控えを触ったときにキーを移す。
  Future<void> _migrateLegacyLibrary() async {
    if (_legacyLibraryChecked) return;
    final running = _legacyLibraryMigration;
    if (running != null) return running;
    final migration = _runLegacyLibraryMigration();
    _legacyLibraryMigration = migration;
    try {
      await migration;
      _legacyLibraryChecked = true;
    } finally {
      _legacyLibraryMigration = null;
    }
  }

  Future<void> _runLegacyLibraryMigration() async {
    final legacy = await store.readRaw(legacyLibraryKey);
    if (legacy == null) return;
    final LegacyLibraryParts parts;
    try {
      parts = await LibraryPayloadCodec.splitLegacy(legacy.payload);
    } on Object catch (error) {
      // isolate を起こせなかった等は「壊れている」ではないので消さずに投げる
      // （次に一覧の控えを触ったときにやり直す）。
      if (!_isMalformed(error)) rethrow;
      // 読めない控えは従来どおり「無い」とみなす。
      await store.delete([legacyLibraryKey]);
      return;
    }
    // 書き込みと旧形式の削除は 1 つのトランザクションで行う。本体だけ書いて
    // 落ちると、次の起動で未読 / お気に入りを移しそびれたまま旧形式を消すため。
    // 新しい行が既にあるキーはそちらが新しいので上書きしない（無いキーだけ移す）。
    await store.moveEntry(legacyLibraryKey, {
      libraryKey: OfflineMetadataRaw(
        payload: parts.books,
        etag: legacy.etag,
        fetchedAt: legacy.fetchedAt,
      ),
      if (parts.userStatus case final status?)
        libraryUserStatusKey: OfflineMetadataRaw(
          payload: status,
          fetchedAt: legacy.fetchedAt,
        ),
    });
  }

  /// 走行中の移し替えを待つ（失敗は問わない）。
  ///
  /// 破棄の前に待つのは、移し替えが読んだ前のユーザーの控えを、破棄の後で
  /// 新しいキーに書き戻させないため（`moveEntry` も旧形式が消えていれば書かない）。
  Future<void> _awaitLegacyLibraryMigration() async {
    final running = _legacyLibraryMigration;
    if (running == null) return;
    try {
      await running;
    } on Object {
      // 失敗した移し替えの続きは破棄で消える。
    }
  }

  /// 控えが壊れている（形が違う）ことを示す失敗か。
  ///
  /// isolate の起動失敗などまで「壊れている」として控えを消さないため。
  static bool _isMalformed(Object error) =>
      error is FormatException || error is TypeError || error is ArgumentError;

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
    await _awaitLegacyLibraryMigration();
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
  Future<LibraryCacheHeader?> readHeader() => _catalog.readLibraryHeader();

  @override
  Future<LibrarySnapshot?> read() => _catalog.readLibrary();

  @override
  Future<UserStatus?> readUserStatus() => _catalog.readLibraryUserStatus();

  @override
  Future<void> write(LibrarySnapshot snapshot) =>
      _catalog.writeLibrary(snapshot);

  @override
  Future<void> writeUserStatus(UserStatus status) =>
      _catalog.writeLibraryUserStatus(status);

  @override
  Future<void> writeEtag(String? etag) => _catalog.updateLibraryEtag(etag);

  @override
  Future<void> clear() => _catalog.deleteLibrary();
}
