import 'dart:typed_data';

import 'package:comic_laz/core/cache/comic_image_loader.dart';
import 'package:comic_laz/core/media/media_urls.dart';
import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/network/dio_provider.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/cache_fakes.dart';
import '../../support/fake_http_adapter.dart';
import '../../support/test_scope.dart';

const _apiBaseUrl = 'https://comic.lazgram.com';

/// 画像として返す応答。
ResponseBody _imageResponse(
  Uint8List bytes, {
  String contentType = 'image/jpeg',
}) {
  return ResponseBody.fromBytes(
    bytes,
    200,
    headers: {
      Headers.contentTypeHeader: [contentType],
    },
  );
}

({
  ComicImageLoader loader,
  CacheHarness harness,
  FakeHttpAdapter adapter,
  MediaUrls urls,
})
build({
  Future<ResponseBody> Function(RequestOptions options)? handler,
  String? token = 'stored-token',
}) {
  final harness = CacheHarness.create();
  final container = ProviderContainer(
    overrides: [
      ...testOverrides(
        apiBaseUrl: _apiBaseUrl,
        authStore: FakeAuthStore(token: token),
      ),
      ...harness.overrides(),
    ],
  );
  addTearDown(container.dispose);

  final adapter = FakeHttpAdapter(
    handler ?? (options) async => _imageResponse(imageBytes(32)),
  );
  // 認証 / リトライのインターセプタごと本物の Dio を使う
  // （画像へのトークン付与の判定を二重に持たないことを確かめたい）。
  final dio = container.read(dioProvider)..httpClientAdapter = adapter;

  return (
    loader: ComicImageLoader(dio: dio, store: harness.store),
    harness: harness,
    adapter: adapter,
    urls: container.read(mediaUrlsProvider),
  );
}

void main() {
  group('取得の経路', () {
    test('キャッシュに無ければネットワークから取り、キャッシュに残す', () async {
      final fixture = build();
      final request = ComicImageRequest.page(
        fixture.urls,
        volumeId: 340,
        page: 1,
        filesVersion: 1758763245,
      );

      final bytes = await fixture.loader.load(request);

      expect(bytes, imageBytes(32));
      expect(
        fixture.adapter.requests.single.uri.toString(),
        '$_apiBaseUrl/books/view/340/1?v=1758763245',
      );
      final cached = await fixture.harness.store.read(request.cacheKey);
      expect(cached?.contentType, 'image/jpeg');
    });

    test('2 回目はネットワークを叩かない（キャッシュヒット）', () async {
      final fixture = build();
      final request = ComicImageRequest.page(
        fixture.urls,
        volumeId: 340,
        page: 1,
        filesVersion: 1,
      );

      await fixture.loader.load(request);
      final second = await fixture.loader.load(request);

      expect(second, imageBytes(32));
      expect(
        fixture.adapter.requests.length,
        1,
        reason: '自宅サーバー（HDD）に同じ画像を取りに行かない',
      );
    });

    test('同じ画像の同時取得は 1 リクエストにまとめる（表示と先読みが重なる）', () async {
      final fixture = build();
      final request = ComicImageRequest.page(
        fixture.urls,
        volumeId: 340,
        page: 1,
        filesVersion: 1,
      );

      await Future.wait([
        fixture.loader.load(request),
        fixture.loader.load(request),
      ]);

      expect(fixture.adapter.requests.length, 1);
    });

    test('files_version が変わると別エントリになり、取り直す（ZIP 差し替え）', () async {
      var body = imageBytes(8, fill: 1);
      final fixture = build(handler: (options) async => _imageResponse(body));

      final old = await fixture.loader.load(
        ComicImageRequest.page(
          fixture.urls,
          volumeId: 340,
          page: 1,
          filesVersion: 100,
        ),
      );
      body = imageBytes(8, fill: 2);
      final fresh = await fixture.loader.load(
        ComicImageRequest.page(
          fixture.urls,
          volumeId: 340,
          page: 1,
          filesVersion: 200,
        ),
      );

      expect(old, imageBytes(8, fill: 1));
      expect(fresh, imageBytes(8, fill: 2), reason: '差し替え後に古い画像を見せてはいけない');
      expect(fixture.adapter.requests.length, 2);
    });
  });

  group('認証', () {
    test('API と同じオリジンには Bearer を付ける', () async {
      final fixture = build();

      await fixture.loader.load(
        ComicImageRequest.thumbnail(fixture.urls, '/books/thumbnail/340?m=1')!,
      );

      expect(
        fixture.adapter.requests.single.headers['Authorization'],
        'Bearer stored-token',
      );
    });

    test('別オリジン（CDN 等）にはトークンを送らない', () async {
      final fixture = build();

      await fixture.loader.load(
        ComicImageRequest.thumbnail(
          fixture.urls,
          'https://cdn.example.com/1.jpg',
        )!,
      );

      final request = fixture.adapter.requests.single;
      expect(request.uri.host, 'cdn.example.com');
      expect(
        request.headers.containsKey('Authorization'),
        isFalse,
        reason: 'セッショントークンを第三者に渡してはいけない',
      );
    });
  });

  group('失敗', () {
    test('404 は NotFoundException（削除済みの巻と通信エラーを区別する）', () async {
      final fixture = build(
        handler: (options) async => ResponseBody.fromBytes(imageBytes(0), 404),
      );

      await expectLater(
        fixture.loader.load(
          ComicImageRequest.page(
            fixture.urls,
            volumeId: 340,
            page: 1,
            filesVersion: 1,
          ),
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('通信できないときは NetworkException', () async {
      final fixture = build(
        handler: (options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );

      await expectLater(
        fixture.loader.load(
          ComicImageRequest.page(
            fixture.urls,
            volumeId: 340,
            page: 1,
            filesVersion: 1,
          ),
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('中身が空の応答は失敗として扱う（壊れた画像をキャッシュしない）', () async {
      final fixture = build(
        handler: (options) async => _imageResponse(imageBytes(0)),
      );
      final request = ComicImageRequest.page(
        fixture.urls,
        volumeId: 340,
        page: 1,
        filesVersion: 1,
      );

      await expectLater(
        fixture.loader.load(request),
        throwsA(isA<UnexpectedResponseException>()),
      );
      expect(await fixture.harness.store.read(request.cacheKey), isNull);
    });

    test('失敗した直後でも再取得できる（進行中の記録を残さない）', () async {
      var fail = true;
      final fixture = build(
        handler: (options) async {
          if (fail) {
            throw DioException.connectionError(
              requestOptions: options,
              reason: 'offline',
            );
          }
          return _imageResponse(imageBytes(4));
        },
      );
      final request = ComicImageRequest.page(
        fixture.urls,
        volumeId: 340,
        page: 1,
        filesVersion: 1,
      );

      await expectLater(
        fixture.loader.load(request),
        throwsA(isA<ApiException>()),
      );
      fail = false;

      expect(await fixture.loader.load(request), imageBytes(4));
    });
  });

  group('キャッシュキー', () {
    test('サムネイルは ?m= の世代まで含め、種別も分ける', () {
      final fixture = build();

      final request = ComicImageRequest.thumbnail(
        fixture.urls,
        '/books/thumbnail/340?m=17',
      );

      expect(request?.cacheKey, 't/books/thumbnail/340/17');
      expect(request?.kind, CachedImageKind.thumbnail);
      expect(request?.url.toString(), '$_apiBaseUrl/books/thumbnail/340?m=17');
    });

    test('サムネイル無し（null / 空文字）は取得指定を作らない', () {
      final fixture = build();

      expect(ComicImageRequest.thumbnail(fixture.urls, null), isNull);
      expect(ComicImageRequest.thumbnail(fixture.urls, '  '), isNull);
    });

    test('ページはホスト名を含めない（開発 / 本番で混ざらないのは保存先で分ける）', () {
      final fixture = build();

      final request = ComicImageRequest.page(
        fixture.urls,
        volumeId: 340,
        page: 7,
        filesVersion: 99,
      );

      expect(request.cacheKey, 'v340/99/7');
      expect(request.kind, CachedImageKind.page);
    });
  });
}
