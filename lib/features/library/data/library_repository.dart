import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_data_purger.dart';
import '../../../data/api/books_api.dart';
import '../../../domain/models/book.dart';

part 'library_repository.g.dart';

/// 取得済みの一覧とその ETag。
class LibrarySnapshot {
  const LibrarySnapshot({
    required this.books,
    required this.fetchedAt,
    this.etag,
    this.userStatus,
  });

  final List<Book> books;

  /// 次回の `If-None-Match` に使う。
  final String? etag;

  final DateTime fetchedAt;

  /// 圏外でも未読 / お気に入りの表示を保つための控え。
  final UserStatus? userStatus;

  LibrarySnapshot copyWith({String? etag, UserStatus? userStatus}) =>
      LibrarySnapshot(
        books: books,
        fetchedAt: fetchedAt,
        etag: etag ?? this.etag,
        userStatus: userStatus ?? this.userStatus,
      );
}

/// 一覧キャッシュの置き場所。
///
/// #11 で drift による永続化に差し替える（アプリ再起動後もオフラインで一覧が出る）。
/// 現状はプロセス内のみ。
abstract interface class LibraryCacheStore {
  LibrarySnapshot? read();

  void write(LibrarySnapshot snapshot);

  void clear();
}

class InMemoryLibraryCacheStore implements LibraryCacheStore {
  LibrarySnapshot? _snapshot;

  @override
  LibrarySnapshot? read() => _snapshot;

  @override
  void write(LibrarySnapshot snapshot) => _snapshot = snapshot;

  @override
  void clear() => _snapshot = null;
}

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
class LibraryRepository {
  LibraryRepository({required this.api, required this.cache});

  final BooksApi api;
  final LibraryCacheStore cache;

  /// 一覧とユーザー状態を取得する。
  ///
  /// [forceRefresh] が `true` のときは `If-None-Match` を送らず必ず取り直す
  /// （プルリフレッシュ = Web 版の `forceReload`）。
  ///
  /// 通信できないときは手元のキャッシュを `isStale` つきで返す。
  /// キャッシュも無ければ例外を投げる。
  Future<LibraryLoadResult> loadBooks({bool forceRefresh = false}) async {
    final cached = cache.read();

    try {
      final response = await api.fetchBooks(
        ifNoneMatch: forceRefresh ? null : cached?.etag,
      );

      if (response.isNotModified && cached != null) {
        final refreshed = cached.copyWith(etag: response.etag);
        cache.write(refreshed);
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
      cache.write(snapshot);
      final userStatus = await _loadUserStatus(snapshot);
      return LibraryLoadResult(
        books: books,
        userStatus: userStatus,
        fetchedAt: snapshot.fetchedAt,
        isStale: false,
      );
    } on ApiException catch (error) {
      // 認証エラーはそのまま伝える（ログイン画面へ戻す）。
      if (!_isRecoverable(error) || cached == null) rethrow;
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
      cache.write(snapshot.copyWith(userStatus: status));
      return status;
    } on ApiException catch (error) {
      if (!_isRecoverable(error)) rethrow;
      return snapshot.userStatus ?? const UserStatus();
    }
  }

  /// 通信環境やサーバーの一時的な問題か（= 手元の内容で代替してよい）。
  static bool _isRecoverable(ApiException error) =>
      error is NetworkException ||
      error is ApiTimeoutException ||
      error is ServerException ||
      error is TooManyRequestsException;
}

@Riverpod(keepAlive: true)
LibraryCacheStore libraryCacheStore(Ref ref) => InMemoryLibraryCacheStore();

@Riverpod(keepAlive: true)
LibraryRepository libraryRepository(Ref ref) => LibraryRepository(
  api: ref.watch(booksApiProvider),
  cache: ref.watch(libraryCacheStoreProvider),
);

/// ログアウト時に一覧キャッシュを破棄する（#3 / #15）。
class LibraryCachePurger implements SessionDataPurger {
  const LibraryCachePurger(this.cache);

  final LibraryCacheStore cache;

  @override
  String get debugLabel => 'library cache';

  @override
  Future<void> purgeSessionData() async => cache.clear();
}

@Riverpod(keepAlive: true)
SessionDataPurger libraryCachePurger(Ref ref) =>
    LibraryCachePurger(ref.watch(libraryCacheStoreProvider));
