import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/api/books_api.dart';
import '../../../domain/models/book.dart';
import '../../offline/data/offline_catalog.dart';
import '../domain/library_snapshot.dart';

export '../domain/library_snapshot.dart';

part 'library_repository.g.dart';

/// 一覧取得の結果。
class LibraryLoadResult {
  const LibraryLoadResult({
    required this.books,
    required this.userStatus,
    required this.fetchedAt,
    required this.isStale,
  });

  final List<Book> books;
  final UserStatus userStatus;

  /// 内容の取得時刻（キャッシュならその時刻）。
  final DateTime fetchedAt;

  /// サーバーに確認できず、手元の内容を表示している（圏外など）。
  final bool isStale;
}

/// ライブラリ一覧の取得（ETag 条件付き GET + キャッシュ）。
///
/// キャッシュは #11 で drift へ永続化した。アプリを再起動してもオフラインで
/// 一覧が出せるようにするため（ETag も一緒に持つので、復帰後は 304 で済む）。
class LibraryRepository {
  LibraryRepository({required this.api, required this.cache});

  final BooksApi api;
  final LibraryCacheStore cache;

  /// 走行中のキャッシュ処理（無ければ `null`）。
  ///
  /// キャッシュは #11 で drift（非同期）になったので、`read` → `write` の間に
  /// 別の書き込みが割り込める。読んだ時点の内容で書き戻すと、割り込んだ新しい
  /// 内容が古い内容に巻き戻る（プルリフレッシュ中にハートを押す / お気に入りを
  /// 続けて切り替える）。読み書きの組を [_serialized] に載せて、割り込みを
  /// 起こさないようにする。
  ///
  /// 空いているときは `null` にしておく（完了済みの future を握って `then` を
  /// 繋いでいくと、その future を作ったゾーンに縛られる。`flutter_test` の
  /// 擬似時間で作った future を `runAsync` の中で待つと永久に進まない）。
  Future<void>? _cacheTask;

  /// お気に入りの変更をキャッシュにも反映する。
  ///
  /// オフライン起動時はこのキャッシュの `userStatus` を使うので、ここを
  /// 更新しないと「お気に入りにしたはずなのに消えている」ことになる。
  /// 一覧の本体（数 MB）は読みも書きもしない（#26）。
  Future<void> updateCachedFavorite({
    required int bookId,
    required bool isFavorite,
  }) => _serialized(() async {
    final status = await cache.readUserStatus();
    if (status == null) return;

    final favorites = status.favorites.toSet();
    if (isFavorite) {
      favorites.add(bookId);
    } else {
      favorites.remove(bookId);
    }
    await cache.writeUserStatus(status.copyWith(favorites: favorites.toList()));
  });

  /// キャッシュを触る処理を 1 本ずつ実行する。
  Future<T> _serialized<T>(Future<T> Function() task) async {
    // 走行中のものが終わるまで待つ。待ち終わった直後に（await を挟まずに）
    // 自分の印を置くので、同時に起きた待ち手が二重に走ることは無い。
    for (var pending = _cacheTask; pending != null; pending = _cacheTask) {
      try {
        await pending;
      } on Object {
        // 前の処理の失敗は引きずらない（自分の読み書きは行う）。
      }
    }
    final done = Completer<void>();
    _cacheTask = done.future;
    try {
      return await task();
    } finally {
      _cacheTask = null;
      done.complete();
    }
  }

  /// 一覧とユーザー状態を取得する。
  ///
  /// [forceRefresh] が `true` のときは `If-None-Match` を送らず必ず取り直す
  /// （プルリフレッシュ = Web 版の `forceReload`）。
  ///
  /// 通信できないときは手元のキャッシュを `isStale` つきで返す。
  /// キャッシュも無ければ例外を投げる。
  ///
  /// 控えの本体（全タイトル）は、手元の内容を表示するとき（304 / 圏外）にだけ
  /// decode する。`If-None-Match` に要るのは ETag だけなので（#26）。
  Future<LibraryLoadResult> loadBooks({bool forceRefresh = false}) async {
    final header = await _serialized(cache.readHeader);

    try {
      var response = await api.fetchBooks(
        ifNoneMatch: forceRefresh ? null : header?.etag,
      );

      if (response.isNotModified) {
        final cached = await _serialized(cache.read);
        if (cached != null) {
          // ETag が同じなら書かない。変わっていても ETag の列だけを書き換え、
          // 本体は encode し直さない（#11 / #26 のレビュー指摘）。
          if (response.etag != cached.etag) {
            await _serialized(() => cache.writeEtag(response.etag));
          }
          final userStatus = await _loadUserStatus();
          return LibraryLoadResult(
            books: cached.books,
            userStatus: userStatus,
            fetchedAt: cached.fetchedAt,
            isStale: false,
          );
        }
        // ETag はあったのに本体が読めなかった（壊れていて捨てた）。304 には
        // 中身が無いので、条件なしで取り直す（空の一覧を正として保存しない）。
        response = await api.fetchBooks();
      }

      final books = response.value ?? const <Book>[];
      // 未読 / お気に入りは別に控えてあるので、ここでは本体だけを書く
      // （取れなかったときは前回の控えがそのまま残る）。
      final snapshot = LibrarySnapshot(
        books: books,
        etag: response.etag,
        fetchedAt: DateTime.now(),
      );
      await _serialized(() => cache.write(snapshot));
      final userStatus = await _loadUserStatus();
      return LibraryLoadResult(
        books: books,
        userStatus: userStatus,
        fetchedAt: snapshot.fetchedAt,
        isStale: false,
      );
    } on ApiException catch (error) {
      // 認証エラーはそのまま伝える（ログイン画面へ戻す）。
      if (!error.isTransient || header == null) rethrow;
      final cached = await _serialized(cache.read);
      // 控えが読めなければ、古い内容の代わりに通信エラーを見せる。
      if (cached == null) rethrow;
      return LibraryLoadResult(
        books: cached.books,
        userStatus: cached.userStatus ?? const UserStatus(),
        fetchedAt: cached.fetchedAt,
        isStale: true,
      );
    }
  }

  /// 未読 / お気に入り。取得できなければ控えを使う（一覧表示は止めない）。
  Future<UserStatus> _loadUserStatus() async {
    try {
      final status = await api.fetchUserStatus();
      // 変わっていなければ書き直さない（304 の更新のたびに書かない）。
      await _serialized(() async {
        if (status != await cache.readUserStatus()) {
          await cache.writeUserStatus(status);
        }
      });
      return status;
    } on ApiException catch (error) {
      if (!error.isTransient) rethrow;
      final cached = await _serialized<UserStatus?>(cache.readUserStatus);
      return cached ?? const UserStatus();
    }
  }
}

@Riverpod(keepAlive: true)
LibraryCacheStore libraryCacheStore(Ref ref) =>
    PersistentLibraryCacheStore(ref.watch(offlineCatalogProvider));

@Riverpod(keepAlive: true)
LibraryRepository libraryRepository(Ref ref) => LibraryRepository(
  api: ref.watch(booksApiProvider),
  cache: ref.watch(libraryCacheStoreProvider),
);
