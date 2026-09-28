import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/data/api/api_client.dart';
import 'package:comic_laz/data/api/books_api.dart';
import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/domain/models/read_volume.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fixtures.dart';
import '../../support/fake_http_adapter.dart';

({BooksApi api, FakeHttpAdapter adapter}) buildApi(
  Future<ResponseBody> Function(RequestOptions options) handler,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://comic.lazgram.com/'));
  final adapter = FakeHttpAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (api: BooksApi(ApiClient(dio)), adapter: adapter);
}

void main() {
  group('fetchBooks', () {
    test('data ラップ無しの配列を読み、ETag を返す', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(
          [ApiFixtures.book],
          headers: {
            'etag': ['"abc123"'],
          },
        ),
      );

      final result = await fixture.api.fetchBooks();

      expect(result.isNotModified, isFalse);
      expect(result.etag, '"abc123"');
      final book = result.value!.single;
      expect(book.id, 12);
      expect(book.title, '進撃の巨人');
      expect(book.kana, 'しんげきのきょじん');
      expect(book.isComplete, isTrue, reason: '1 / 0 でも真偽値として読む');
      expect(book.isUnsafe, isFalse);
      expect(book.author, ['諫山創']);
      expect(book.tags, [3, 7]);
      expect(book.categories, [1]);
      expect(book.latestVolume, 34);
      expect(book.thumbnail, '/books/thumbnail/340?m=1758763245');
      expect(
        book.volumeAddedAt,
        DateTime.utc(2026, 9, 20, 12, 34, 56),
        reason: 'タイムゾーン無しの日時も読む',
      );
      expect(
        fixture.adapter.requests.single.uri.toString(),
        'https://comic.lazgram.com/api/books',
      );
    });

    test('If-None-Match を送り、304 なら手元のキャッシュを使う', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(null, statusCode: 304),
      );

      final result = await fixture.api.fetchBooks(ifNoneMatch: '"abc123"');

      expect(result.isNotModified, isTrue);
      expect(result.value, isNull);
      expect(result.etag, '"abc123"', reason: '304 でも次回用に ETag を保つ');
      expect(
        fixture.adapter.requests.single.headers['If-None-Match'],
        '"abc123"',
      );
    });

    test('強制再取得では If-None-Match を送らず、304 も許容しない', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(null, statusCode: 304),
      );

      // プルリフレッシュ相当。304 が返ってきたらエラーとして扱う（想定外）。
      await expectLater(fixture.api.fetchBooks(), throwsA(isA<ApiException>()));
      expect(
        fixture.adapter.requests.single.headers.containsKey('If-None-Match'),
        isFalse,
      );
    });

    test('必須フィールドが null でも ApiException として届く', () async {
      // 生成された fromJson はハードキャストするため、素の TypeError が
      // 漏れると呼び出し側の種別分岐（404 だけ進捗を捨てる等）が壊れる
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse([
          {...ApiFixtures.book, 'id': null},
        ]),
      );

      await expectLater(
        fixture.api.fetchBooks(),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('配列でない応答は想定外エラー', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({'data': <Object>[]}),
      );

      await expectLater(
        fixture.api.fetchBooks(),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('Content-Type が JSON でない静的ファイル配信でも読める', () async {
      final fixture = buildApi(
        (options) async => ResponseBody.fromString(
          '[{"id":1,"title":"x"}]',
          200,
          headers: {
            'content-type': ['text/plain'],
          },
        ),
      );

      final result = await fixture.api.fetchBooks();

      expect(result.value!.single.id, 1);
    });
  });

  group('fetchUserStatus', () {
    test('unreads / favorites を読む', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({
          'unreads': [1, 2],
          'favorites': [3],
        }),
      );

      final status = await fixture.api.fetchUserStatus();

      expect(status.unreads, [1, 2]);
      expect(status.favorites, [3]);
      expect(
        fixture.adapter.requests.single.uri.path,
        '/api/books/user_status',
      );
    });

    test('キーが欠けていても空配列になる', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(<String, dynamic>{}),
      );

      final status = await fixture.api.fetchUserStatus();

      expect(status.unreads, isEmpty);
      expect(status.favorites, isEmpty);
    });
  });

  group('fetchReadVolume', () {
    test('ページ一覧と次巻情報を読む', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(ApiFixtures.readVolume),
      );

      final volume = await fixture.api.fetchReadVolume(340);

      expect(volume.id, 340);
      expect(volume.volume, 34);
      expect(volume.currentPage, 12);
      expect(volume.files, [1, 2, 3, 4, 5]);
      expect(volume.filesVersion, 1758763245);
      expect(volume.nextVolumeId, 341);
      expect(volume.book.title, '進撃の巨人');
      expect(
        fixture.adapter.requests.single.uri.path,
        '/api/books/read/volume/340',
      );
    });

    test('ZIP が無い巻は空として扱える', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({
          ...ApiFixtures.readVolume,
          'files': <int>[],
          'files_version': null,
        }),
      );

      final volume = await fixture.api.fetchReadVolume(340);

      expect(volume.isEmpty, isTrue);
      expect(volume.pageCount, 0);
      expect(volume.clampPage(5), 0);
    });

    test('削除済みの巻（404）と通信エラーを型で区別する', () async {
      final notFound = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(null, statusCode: 404),
      );
      await expectLater(
        notFound.api.fetchReadVolume(340),
        throwsA(isA<NotFoundException>()),
      );

      final offline = buildApi(
        (options) async => throw DioException(
          requestOptions: RequestOptions(path: '/api/books/read/volume/340'),
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        offline.api.fetchReadVolume(340),
        throwsA(isA<NetworkException>()),
      );
    });

    test('ページ番号は巻末オーバーレイを含めずに丸める', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(ApiFixtures.readVolume),
      );

      final volume = await fixture.api.fetchReadVolume(340);

      expect(volume.clampPage(6), 5, reason: 'files.length + 1 は保存しない');
      expect(volume.clampPage(3), 3);
      expect(volume.clampPage(0), 1);
    });
  });

  group('fetchBookDetail', () {
    test('巻一覧・進捗・ダウンロード情報を読む', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(ApiFixtures.bookDetail),
      );

      final detail = await fixture.api.fetchBookDetail(12);

      expect(detail.title, '進撃の巨人');
      expect(detail.authors, ['諫山創']);
      expect(detail.publisher, '講談社');
      expect(detail.tags, ['アクション', 'ダーク']);
      expect(detail.categories.single.name, '少年');
      expect(detail.totalArchiveBytes, 104857600);
      expect(detail.readingProgress?.currentVolume, 1);
      expect(detail.volumes, hasLength(2));

      final first = detail.volumes.first;
      expect(first.isDownloadable, isTrue);
      expect(first.isInProgress, isTrue);
      expect(first.userStatus?.maxPage, 190);

      final second = detail.volumes.last;
      expect(second.isDownloadable, isFalse, reason: 'ZIP が無い巻は落とせない');
      expect(second.thumbnail, isNull);
      expect(second.userStatus, isNull);
      expect(fixture.adapter.requests.single.uri.path, '/api/v2/books/12');
    });
  });

  group('favorites', () {
    test('取得・追加・削除が真偽値を返す', () async {
      for (final body in [true, 1, 'true']) {
        final fixture = buildApi(
          (options) async => FakeHttpAdapter.jsonResponse(body),
        );
        expect(await fixture.api.isFavorite(12), isTrue, reason: 'body=$body');
      }

      final add = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(true),
      );
      expect(await add.api.addFavorite(12), isTrue);
      expect(add.adapter.requests.single.method, 'POST');

      final remove = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(false),
      );
      expect(await remove.api.removeFavorite(12), isFalse);
      expect(remove.adapter.requests.single.method, 'DELETE');
      expect(remove.adapter.requests.single.uri.path, '/api/favorites/12');
    });

    test('真偽値でない応答はエラー（書き込み成功を false に倒さない）', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({'favorite': true}),
      );

      await expectLater(
        fixture.api.addFavorite(12),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('前後の空白つきの真偽値も読む', () async {
      final fixture = buildApi(
        (options) async => ResponseBody.fromString('true\n', 200),
      );

      expect(await fixture.api.isFavorite(12), isTrue);
    });

    test('存在しない書籍は 404', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({
          'message': 'Book not found',
        }, statusCode: 404),
      );

      await expectLater(
        fixture.api.addFavorite(999),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}
