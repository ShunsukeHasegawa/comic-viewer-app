import 'dart:async';
import 'dart:typed_data';

import 'package:comic_laz/core/cache/comic_image_loader.dart';
import 'package:comic_laz/core/cache/image_cache_store.dart';
import 'package:comic_laz/core/media/media_urls.dart';
import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/network/dio_provider.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/features/downloads/data/downloaded_page_source.dart';
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
  ImageCacheStore Function(CacheHarness harness)? store,
  DownloadedPageSource? localPages,
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
    loader: ComicImageLoader(
      dio: dio,
      store: store?.call(harness) ?? harness.store,
      localPages: localPages ?? const NoDownloadedPageSource(),
    ),
    harness: harness,
    adapter: adapter,
    urls: container.read(mediaUrlsProvider),
  );
}

/// ダウンロード済みのページをテストから与える。
class _FakeLocalPages implements DownloadedPageSource {
  _FakeLocalPages({this.bytes, this.filesVersion = 1, this.error});

  /// 返すバイト列（`null` は「端末に無い」）。
  Uint8List? bytes;

  /// この世代の要求にだけ応える（食い違いは「更新あり」なので null）。
  int filesVersion;

  /// 読み出しで投げる例外（ZIP が壊れている / ディスクが読めない）。
  Object? error;

  final calls = <({int volumeId, int page, int filesVersion})>[];

  @override
  Future<Uint8List?> readPage({
    required int volumeId,
    required int page,
    required int filesVersion,
  }) async {
    calls.add((volumeId: volumeId, page: page, filesVersion: filesVersion));
    if (error case final error?) throw error;
    return filesVersion == this.filesVersion ? bytes : null;
  }
}

void main() {
  // 解決順は「ダウンロード済みローカル → 一時キャッシュ → ネットワーク」（#11）。
  group('ダウンロード済みローカル優先', () {
    test('ダウンロード済みならネットワークもキャッシュも見ない（機内モード）', () async {
      final local = _FakeLocalPages(bytes: imageBytes(16, fill: 9));
      final fixture = build(localPages: local);
      final request = ComicImageRequest.page(
        fixture.urls,
        volumeId: 340,
        page: 2,
        filesVersion: 1,
      );

      final bytes = await fixture.loader.load(request);

      expect(bytes, imageBytes(16, fill: 9));
      expect(fixture.adapter.requests, isEmpty, reason: '圏外でも表示できること');
      expect(local.calls.single, (volumeId: 340, page: 2, filesVersion: 1));
      expect(
        await fixture.harness.store.read(request.cacheKey),
        isNull,
        reason: 'ZIP から読めるページを一時キャッシュに二重持ちしない',
      );
    });

    test('世代が違えばローカルを使わずネットワークへ（更新あり）', () async {
      final local = _FakeLocalPages(
        bytes: imageBytes(16, fill: 9),
        filesVersion: 100,
      );
      final fixture = build(localPages: local);

      final bytes = await fixture.loader.load(
        ComicImageRequest.page(
          fixture.urls,
          volumeId: 340,
          page: 1,
          filesVersion: 200,
        ),
      );

      expect(bytes, imageBytes(32));
      expect(fixture.adapter.requests, hasLength(1));
    });

    test('ローカルが読めなくてもキャッシュ / ネットワークへ落ちる', () async {
      final local = _FakeLocalPages(error: StateError('ZIP が壊れている'));
      final fixture = build(localPages: local);

      final bytes = await fixture.loader.load(
        ComicImageRequest.page(
          fixture.urls,
          volumeId: 340,
          page: 1,
          filesVersion: 1,
        ),
      );

      expect(bytes, imageBytes(32));
    });

    test('サムネイルはローカル（ZIP）を見に行かない', () async {
      final local = _FakeLocalPages(bytes: imageBytes(16, fill: 9));
      final fixture = build(localPages: local);

      await fixture.loader.load(
        ComicImageRequest.thumbnail(fixture.urls, '/books/thumbnail/340?m=1')!,
      );

      expect(local.calls, isEmpty, reason: 'サムネイルは ZIP に入っていない');
      expect(fixture.adapter.requests, hasLength(1));
    });
  });

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

    // キャッシュの読み出しは掃除 / 手動削除 / OS のキャッシュ削除と競合する。
    // そこで投げると、取り直せば表示できる画像が「読み込めませんでした」になり、
    // しかも `ApiException` ではないので文言も「読み込みに失敗しました。」になる。
    test('キャッシュが読めなくてもネットワークから取り直す', () async {
      final fixture = build(
        store: (harness) => harness.storeLike(UnreadableCacheStore.new),
      );

      final bytes = await fixture.loader.load(
        ComicImageRequest.page(
          fixture.urls,
          volumeId: 340,
          page: 1,
          filesVersion: 1,
        ),
      );

      expect(bytes, imageBytes(32));
      expect(fixture.adapter.requests, hasLength(1));
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

  group('ログアウトとの競合', () {
    // ログアウト時の破棄より後に完了したダウンロードを書き戻すと、別のユーザーで
    // 同じ巻を開いたときに前のユーザー向けに取得した画像が出てしまう（#8 / #15）。
    test('取得中にログアウト（全削除）が入ったら書き戻さない', () async {
      final gate = Completer<void>();
      final fixture = build(
        handler: (options) async {
          await gate.future;
          return _imageResponse(imageBytes(8));
        },
      );
      final request = ComicImageRequest.page(
        fixture.urls,
        volumeId: 340,
        page: 1,
        filesVersion: 1,
      );

      final pending = fixture.loader.load(request);
      await pumpEventQueue();
      await fixture.harness.store.clear();
      gate.complete();

      expect(await pending, imageBytes(8), reason: '表示中の画像まで失敗にはしない');
      expect(await fixture.harness.store.usage(), CacheUsage.empty);
      expect(fixture.harness.fileCount, 0);
    });
  });

  group('タイムアウト', () {
    // JSON API の 8 秒をそのまま当てると、自宅サーバー（HDD）が ZIP をシークして
    // いる間に切れ、再送も重なって「待てば表示できたページ」が失敗になる。
    test('画像は API より長いタイムアウトで取りに行く', () async {
      final fixture = build();

      await fixture.loader.load(
        ComicImageRequest.page(
          fixture.urls,
          volumeId: 340,
          page: 1,
          filesVersion: 1,
        ),
      );

      final options = fixture.adapter.requests.single;
      expect(options.receiveTimeout, imageTimeout);
      expect(imageTimeout, greaterThan(apiTimeout));
    });
  });

  group('キャッシュキー', () {
    test('サムネイルは ?m= の世代まで含め、種別も分ける', () {
      final fixture = build();

      final request = ComicImageRequest.thumbnail(
        fixture.urls,
        '/books/thumbnail/340?m=17',
      );

      expect(request?.cacheKey, 't/books/thumbnail/340/17@$_apiBaseUrl');
      expect(request?.kind, CachedImageKind.thumbnail);
      expect(request?.url.toString(), '$_apiBaseUrl/books/thumbnail/340?m=17');
    });

    test('サムネイル無し（null / 空文字）は取得指定を作らない', () {
      final fixture = build();

      expect(ComicImageRequest.thumbnail(fixture.urls, null), isNull);
      expect(ComicImageRequest.thumbnail(fixture.urls, '  '), isNull);
    });

    // 保存先（キャッシュディレクトリ / DB）は配信元で分かれていないので、
    // キーに配信元が入っていないと開発ビルドで本番の画像を表示しうる。
    test('ページは巻 / 世代 / ページ + 配信元で決まる', () {
      final fixture = build();

      final request = ComicImageRequest.page(
        fixture.urls,
        volumeId: 340,
        page: 7,
        filesVersion: 99,
      );

      expect(request.cacheKey, 'v340/99/7@$_apiBaseUrl');
      expect(request.kind, CachedImageKind.page);
    });
  });
}
