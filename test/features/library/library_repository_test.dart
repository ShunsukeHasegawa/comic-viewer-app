import 'dart:async';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/features/library/data/library_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';

/// 書き込み回数を数え、`read` を 1 回だけ待たせられるキャッシュ。
///
/// キャッシュは drift（非同期）なので、`read` → `write` の間に別の書き込みを
/// 挟み込めるかどうかはゲートで作らないと再現しない（イベントループの順序に
/// 任せたテストは落ち方が安定しない）。
class _GatedCacheStore extends InMemoryLibraryCacheStore {
  int writes = 0;

  /// 次の `read` を待たせる（1 回だけ）。
  Completer<void>? pendingRead;

  @override
  Future<LibrarySnapshot?> read() async {
    final gate = pendingRead;
    pendingRead = null;
    if (gate != null) await gate.future;
    return super.read();
  }

  @override
  Future<void> write(LibrarySnapshot snapshot) async {
    writes++;
    await super.write(snapshot);
  }
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
  // 一覧は全冊 + ETag を 1 行で持つので、読んだ時点の内容で書き戻すと
  // 一覧ごと古いスナップショットへ巻き戻る（圏外起動で古い巻構成が出る）。
  test('お気に入りの書き戻しで新しい一覧を巻き戻さない', () async {
    final gated = _GatedCacheStore();
    final repository = LibraryRepository(api: api, cache: gated);
    await repository.loadBooks();

    // サーバー側の一覧が変わった。
    api
      ..books = [testBook(id: 3, title: 'C')]
      ..etag = '"v2"';

    // お気に入りが控えを読んだ後・書き戻す前に、取り直しの書き込みを挟み込む。
    final gate = Completer<void>();
    gated.pendingRead = gate;
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
