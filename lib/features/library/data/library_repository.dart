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
  /// 別の書き込みが割り込める。一覧スナップショットは**全冊 + ETag を 1 行**で
  /// 持つため、読んだ時点の内容で書き戻すと新しい一覧ごと古い内容に巻き戻る
  /// （プルリフレッシュ中にハートを押す / お気に入りを続けて切り替える）。
  /// 読み書きの組を [_serialized] に載せて、割り込みを起こさないようにする。
  ///
  /// 空いているときは `null` にしておく（完了済みの future を握って `then` を
  /// 繋いでいくと、その future を作ったゾーンに縛られる。`flutter_test` の
  /// 擬似時間で作った future を `runAsync` の中で待つと永久に進まない）。
  Future<void>? _cacheTask;

  /// お気に入りの変更をキャッシュにも反映する。
  ///
  /// オフライン起動時はこのキャッシュの `userStatus` を使うので、ここを
  /// 更新しないと「お気に入りにしたはずなのに消えている」ことになる。
  Future<void> updateCachedFavorite({
    required int bookId,
    required bool isFavorite,
  }) => _serialized(() async {
    final snapshot = await cache.read();
    final status = snapshot?.userStatus;
    if (snapshot == null || status == null) return;

    final favorites = status.favorites.toSet();
    if (isFavorite) {
      favorites.add(bookId);
    } else {
      favorites.remove(bookId);
    }
    await cache.write(
      snapshot.copyWith(
        userStatus: status.copyWith(favorites: favorites.toList()),
      ),
    );
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
  Future<LibraryLoadResult> loadBooks({bool forceRefresh = false}) async {
    final cached = await _serialized(cache.read);

    try {
      final response = await api.fetchBooks(
        ifNoneMatch: forceRefresh ? null : cached?.etag,
      );

      if (response.isNotModified && cached != null) {
        final refreshed = cached.copyWith(etag: response.etag);
        // ETag が同じなら書かない。全冊を `toJson()` + `jsonEncode` し直して
        // 1 行を UPDATE することになり（1500 タイトルで数 MB の文字列生成が
        // UI アイソレートに乗る）、それを起動・プルリフレッシュ・復帰のたびに
        // 払うのは無駄（#11 のレビュー指摘。すぐ下の `_loadUserStatus` が
        // 避けているのと同じコスト）。
        if (refreshed.etag != cached.etag) {
          await _serialized(() => cache.write(refreshed));
        }
        final userStatus = await _loadUserStatus(refreshed);
        return LibraryLoadResult(
          books: refreshed.books,
          userStatus: userStatus,
          fetchedAt: refreshed.fetchedAt,
          isStale: false,
        );
      }

      final books = response.value ?? const <Book>[];
      final snapshot = LibrarySnapshot(
        books: books,
        etag: response.etag,
        fetchedAt: DateTime.now(),
        // 未読 / お気に入りが取れなかったときに備え、前回の控えを引き継ぐ。
        userStatus: cached?.userStatus,
      );
      await _serialized(() => cache.write(snapshot));
      final userStatus = await _loadUserStatus(snapshot);
      return LibraryLoadResult(
        books: books,
        userStatus: userStatus,
        fetchedAt: snapshot.fetchedAt,
        isStale: false,
      );
    } on ApiException catch (error) {
      // 認証エラーはそのまま伝える（ログイン画面へ戻す）。
      if (!error.isTransient || cached == null) rethrow;
      return LibraryLoadResult(
        books: cached.books,
        userStatus: cached.userStatus ?? const UserStatus(),
        fetchedAt: cached.fetchedAt,
        isStale: true,
      );
    }
  }

  /// 未読 / お気に入り。取得できなければ控えを使う（一覧表示は止めない）。
  Future<UserStatus> _loadUserStatus(LibrarySnapshot snapshot) async {
    try {
      final status = await api.fetchUserStatus();
      // 変わっていなければ書き直さない。キャッシュは一覧ごと 1 行なので、
      // 書くたびに数百冊の JSON を作り直すことになる（304 の更新で毎回起きる）。
      if (status != snapshot.userStatus) {
        await _serialized(
          () => cache.write(snapshot.copyWith(userStatus: status)),
        );
      }
      return status;
    } on ApiException catch (error) {
      if (!error.isTransient) rethrow;
      return snapshot.userStatus ?? const UserStatus();
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
