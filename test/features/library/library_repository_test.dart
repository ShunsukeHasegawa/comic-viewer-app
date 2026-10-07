import 'dart:async';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/features/library/data/library_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';

/// 本体の読み書き回数を数え、`readUserStatus` を 1 回だけ待たせられるキャッシュ。
///
/// キャッシュは drift（非同期）なので、`read` → `write` の間に別の書き込みを
/// 挟み込めるかどうかはゲートで作らないと再現しない（イベントループの順序に
/// 任せたテストは落ち方が安定しない）。
class _GatedCacheStore extends InMemoryLibraryCacheStore {
  /// 本体（全タイトル）の書き込み回数（数 MB の encode が起きる回数）。
  int writes = 0;

  /// 本体（全タイトル）の読み込み回数（数 MB の decode が起きる回数）。
  int reads = 0;

  /// 次の `readUserStatus` を、値を読んだ後・返す前で待たせる（1 回だけ）。
  Completer<void>? pendingUserStatusRead;

  @override
  Future<LibrarySnapshot?> read() async {
    reads++;
    return super.read();
  }

  @override
  Future<UserStatus?> readUserStatus() async {
    final gate = pendingUserStatusRead;
    pendingUserStatusRead = null;
    final status = await super.readUserStatus();
    if (gate != null) await gate.future;
    return status;
  }

  @override
  Future<void> write(LibrarySnapshot snapshot) async {
    writes++;
    await super.write(snapshot);
  }
}

/// ETag だけ残っていて本体が読めない控え（payload が壊れていて捨てた状態）。
class _HeaderOnlyCacheStore extends InMemoryLibraryCacheStore {
  @override
  Future<LibraryCacheHeader?> readHeader() async =>
      LibraryCacheHeader(etag: '"v1"', fetchedAt: DateTime.utc(2026));

  @override
  Future<LibrarySnapshot?> read() async => null;
}

void main() {
  late FakeBooksApi api;
  late InMemoryLibraryCacheStore cache;
  late LibraryRepository repository;

  setUp(() {
    api = FakeBooksApi(
      books: [
        testBook(id: 1, title: 'A'),
        testBook(id: 2, title: 'B'),
      ],
      userStatus: const UserStatus(unreads: [1], favorites: [2]),
      etag: '"v1"',
    );
    cache = InMemoryLibraryCacheStore();
    repository = LibraryRepository(api: api, cache: cache);
  });

  test('初回は ETag 無しで取得し、キャッシュに保存する', () async {
    final result = await repository.loadBooks();

    expect(result.books, hasLength(2));
    expect(result.userStatus.unreads, [1]);
    expect(result.isStale, isFalse);
    expect(api.ifNoneMatchCalls, [null]);
    expect((await cache.read())?.etag, '"v1"');
  });

  test('2 回目は If-None-Match を送る', () async {
    await repository.loadBooks();
    await repository.loadBooks();

    expect(api.ifNoneMatchCalls, [null, '"v1"']);
  });

  test('304 なら手元の一覧を使う（再パースしない）', () async {
    await repository.loadBooks();
    api.respondNotModified = true;
    // サーバー側の内容が変わっていても 304 の間は手元のものを使う
    api.books = [testBook(id: 99, title: '新しい本')];

    final result = await repository.loadBooks();

    expect(result.books.map((b) => b.id), [1, 2]);
    expect(result.isStale, isFalse);
  });

  test('プルリフレッシュでは If-None-Match を送らない', () async {
    await repository.loadBooks();
    api.respondNotModified = true;
    api.books = [testBook(id: 99, title: '新しい本')];

    final result = await repository.loadBooks(forceRefresh: true);

    expect(api.ifNoneMatchCalls, [null, null]);
    expect(result.books.map((b) => b.id), [99]);
  });

  test('圏外ではキャッシュを isStale つきで返す', () async {
    await repository.loadBooks();
    api.error = const NetworkException();

    final result = await repository.loadBooks();

    expect(result.books.map((b) => b.id), [1, 2]);
    expect(result.isStale, isTrue);
    expect(result.userStatus.favorites, [2], reason: '未読 / お気に入りも控えを使う');
  });

  test('キャッシュが無い状態の圏外は例外', () async {
    api.error = const NetworkException();

    await expectLater(repository.loadBooks(), throwsA(isA<NetworkException>()));
  });

  test('認証エラーはキャッシュがあっても伝える（ログイン画面へ戻すため）', () async {
    await repository.loadBooks();
    api.error = const UnauthorizedException();

    await expectLater(
      repository.loadBooks(),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('ユーザー状態だけ取れない場合も一覧は表示する', () async {
    api.userStatusError = const ApiTimeoutException();

    final result = await repository.loadBooks();

    expect(result.books, hasLength(2));
    expect(result.userStatus.unreads, isEmpty);
    expect(result.isStale, isFalse);
  });

  test('ユーザー状態は控えから復元する', () async {
    await repository.loadBooks();
    api.userStatusError = const NetworkException();

    final result = await repository.loadBooks(forceRefresh: true);

    expect(result.userStatus.favorites, [2]);
  });

  test('お気に入りの変更はキャッシュにも反映する（オフラインで消えない）', () async {
    await repository.loadBooks();

    await repository.updateCachedFavorite(bookId: 1, isFavorite: true);

    final cached = await cache.read();
    expect(cached?.userStatus?.favorites, containsAll([1, 2]));
  });

  // #11 のレビュー指摘: キャッシュを drift に移して非同期になったため、
  // お気に入りの read-modify-write の間に取り直しの書き込みが割り込める。
  // 読んだ時点の控えで書き戻すと、取り直したばかりの未読 / お気に入りが
  // 巻き戻る（圏外起動で古い状態が出る）。
  test('お気に入りの書き戻しで取り直した未読 / お気に入りを巻き戻さない', () async {
    final gated = _GatedCacheStore();
    final repository = LibraryRepository(api: api, cache: gated);
    await repository.loadBooks();

    // サーバー側の状態が変わった（別端末で既読にした）。
    api
      ..books = [testBook(id: 3, title: 'C')]
      ..etag = '"v2"'
      ..userStatus = const UserStatus(favorites: [2]);

    // お気に入りが控えを読んだ後・書き戻す前に止め、その間に取り直しを走らせる。
    final gate = Completer<void>();
    gated.pendingUserStatusRead = gate;
    final favoriting = repository.updateCachedFavorite(
      bookId: 1,
      isFavorite: true,
    );
    await pumpEventQueue();
    final refreshing = repository.loadBooks(forceRefresh: true);
    await pumpEventQueue();
    gate.complete();
    await Future.wait([favoriting, refreshing]);

    final cached = await gated.read();
    expect(cached?.books.map((book) => book.id), [3]);
    expect(cached?.etag, '"v2"');
    expect(
      cached?.userStatus?.unreads,
      isEmpty,
      reason: '先に読んだ古い控え（unreads: [1]）で上書きしない',
    );
    expect(cached?.userStatus?.favorites, [2]);
  });

  // #26: 1500 タイトルで数 MB の本体を、ハートを押すたびに decode / encode しない。
  test('お気に入りの変更では一覧の本体を読みも書きもしない', () async {
    final gated = _GatedCacheStore();
    final repository = LibraryRepository(api: api, cache: gated);
    await repository.loadBooks();
    final reads = gated.reads;
    final writes = gated.writes;

    await repository.updateCachedFavorite(bookId: 1, isFavorite: true);

    expect(gated.reads, reads);
    expect(gated.writes, writes);
    expect((await gated.readUserStatus())?.favorites, containsAll([1, 2]));
  });

  // #26: `If-None-Match` に要るのは ETag だけ。200 で取り直すなら手元の本体は使わない。
  test('取り直しが 200 なら手元の本体を decode しない', () async {
    final gated = _GatedCacheStore();
    final repository = LibraryRepository(api: api, cache: gated);
    await repository.loadBooks();
    api
      ..books = [testBook(id: 3, title: 'C')]
      ..etag = '"v2"';

    await repository.loadBooks();

    expect(gated.reads, 0);
  });

  test('304 で ETag だけ変わったら本体を書き直さずに ETag を更新する', () async {
    final gated = _GatedCacheStore();
    final repository = LibraryRepository(api: api, cache: gated);
    await repository.loadBooks();
    final writes = gated.writes;
    api.respondNotModified = true;
    api.notModifiedEtag = '"v1-gzip"';

    final result = await repository.loadBooks();

    expect(result.books, hasLength(2));
    expect(gated.writes, writes);
    expect((await gated.readHeader())?.etag, '"v1-gzip"');
  });

  // 304 には中身が無い。控えが壊れて捨てられていたら、空の一覧を正として
  // 保存・表示せずに条件なしで取り直す。
  test('ETag はあるのに本体が読めないときは条件なしで取り直す', () async {
    final broken = _HeaderOnlyCacheStore();
    final repository = LibraryRepository(api: api, cache: broken);
    api.respondNotModified = true;

    final result = await repository.loadBooks();

    expect(api.ifNoneMatchCalls, ['"v1"', null]);
    expect(result.books.map((book) => book.id), [1, 2]);
    expect(result.isStale, isFalse);
  });

  test('圏外で本体が読めなければ古い内容の代わりに通信エラーを伝える', () async {
    final broken = _HeaderOnlyCacheStore();
    final repository = LibraryRepository(api: api, cache: broken);
    api.error = const NetworkException();

    await expectLater(repository.loadBooks(), throwsA(isA<NetworkException>()));
  });

  test('304 で ETag も変わらないならキャッシュを書き直さない', () async {
    // 1500 タイトルの `toJson()` + `jsonEncode`（数 MB の文字列生成）を、
    // 起動・プルリフレッシュ・復帰のたびに払わない（#11 のレビュー指摘）。
    final gated = _GatedCacheStore();
    final repository = LibraryRepository(api: api, cache: gated);
    await repository.loadBooks();
    final writes = gated.writes;
    api.respondNotModified = true;

    final result = await repository.loadBooks();

    expect(result.books, hasLength(2));
    expect(gated.writes, writes);
  });
}
