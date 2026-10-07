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
}

/// 一覧の控えのうち、本体（全タイトル）を除いた部分。
///
/// `If-None-Match` を組むだけのために数 MB の本体を decode しないため（#26）。
class LibraryCacheHeader {
  const LibraryCacheHeader({required this.fetchedAt, this.etag});

  final String? etag;

  final DateTime fetchedAt;
}

/// 一覧キャッシュの置き場所。
///
/// 実体は #11 で drift（`OfflineCatalog`）に移した。アプリを再起動しても
/// オフラインで一覧が出るようにするため、**プロセス内に持たない**のが既定。
/// 非同期なのはそのため（テストや単体検証では [InMemoryLibraryCacheStore]）。
///
/// 本体（全タイトル）と未読 / お気に入り・ETag は別々に読み書きできる（#26）。
/// 1500 タイトルで数 MB になる本体を、お気に入りの切り替えや 304 のたびに
/// decode / encode し直さないため。
abstract interface class LibraryCacheStore {
  /// ETag と取得時刻だけ（本体を decode しない）。本体が無ければ `null`。
  Future<LibraryCacheHeader?> readHeader();

  /// 本体 + ETag + 未読 / お気に入り。本体が無い / 読めなければ `null`。
  Future<LibrarySnapshot?> read();

  /// 未読 / お気に入りの控えだけ（本体を decode しない）。
  Future<UserStatus?> readUserStatus();

  /// 本体と ETag / 取得時刻を書く。
  ///
  /// [LibrarySnapshot.userStatus] が `null` なら未読 / お気に入りの控えは
  /// そのまま残す（一覧だけ取れて user_status が取れなかったときに消さない）。
  Future<void> write(LibrarySnapshot snapshot);

  /// 未読 / お気に入りの控えだけを書く。
  Future<void> writeUserStatus(UserStatus status);

  /// ETag だけを書き換える（本体が無ければ何もしない）。
  Future<void> writeEtag(String? etag);

  Future<void> clear();
}

/// プロセス内だけに持つ実装（テスト用 / 永続化を使わない経路用）。
class InMemoryLibraryCacheStore implements LibraryCacheStore {
  LibrarySnapshot? _snapshot;
  UserStatus? _userStatus;

  @override
  Future<LibraryCacheHeader?> readHeader() async => switch (_snapshot) {
    final snapshot? => LibraryCacheHeader(
      etag: snapshot.etag,
      fetchedAt: snapshot.fetchedAt,
    ),
    null => null,
  };

  @override
  Future<LibrarySnapshot?> read() async => switch (_snapshot) {
    final snapshot? => LibrarySnapshot(
      books: snapshot.books,
      etag: snapshot.etag,
      fetchedAt: snapshot.fetchedAt,
      userStatus: _userStatus,
    ),
    null => null,
  };

  @override
  Future<UserStatus?> readUserStatus() async => _userStatus;

  @override
  Future<void> write(LibrarySnapshot snapshot) async {
    _snapshot = snapshot;
    if (snapshot.userStatus case final status?) _userStatus = status;
  }

  @override
  Future<void> writeUserStatus(UserStatus status) async => _userStatus = status;

  @override
  Future<void> writeEtag(String? etag) async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    _snapshot = LibrarySnapshot(
      books: snapshot.books,
      etag: etag,
      fetchedAt: snapshot.fetchedAt,
    );
  }

  @override
  Future<void> clear() async {
    _snapshot = null;
    _userStatus = null;
  }
}
