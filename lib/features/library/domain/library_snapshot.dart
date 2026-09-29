import '../../../domain/models/book.dart';

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
/// 実体は #11 で drift（`OfflineCatalog`）に移した。アプリを再起動しても
/// オフラインで一覧が出るようにするため、**プロセス内に持たない**のが既定。
/// 非同期なのはそのため（テストや単体検証では [InMemoryLibraryCacheStore]）。
abstract interface class LibraryCacheStore {
  Future<LibrarySnapshot?> read();

  Future<void> write(LibrarySnapshot snapshot);

  Future<void> clear();
}

/// プロセス内だけに持つ実装（テスト用 / 永続化を使わない経路用）。
class InMemoryLibraryCacheStore implements LibraryCacheStore {
  LibrarySnapshot? _snapshot;

  @override
  Future<LibrarySnapshot?> read() async => _snapshot;

  @override
  Future<void> write(LibrarySnapshot snapshot) async => _snapshot = snapshot;

  @override
  Future<void> clear() async => _snapshot = null;
}
