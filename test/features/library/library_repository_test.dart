import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/features/library/data/library_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';

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
}
