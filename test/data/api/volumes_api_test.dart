import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/data/api/api_client.dart';
import 'package:comic_laz/data/api/volumes_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

({VolumesApi api, FakeHttpAdapter adapter}) buildApi(
  Future<ResponseBody> Function(RequestOptions options) handler,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://comic.lazgram.com/'));
  final adapter = FakeHttpAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (
    api: HttpVolumesApi(client: ApiClient(dio), dio: dio),
    adapter: adapter,
  );
}

void main() {
  group('fetchManifest', () {
    test('サーバー（VolumeService::getManifest）の形をそのまま読む', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({
          'id': 340,
          'volume': 1.0,
          'book_id': 12,
          'files_version': 1758763245,
          'archive_bytes': 104857600,
          'archive_etag': '68d5a2ed-6400000',
          'page_count': 2,
          'pages': [
            {'index': 0, 'extension': 'jpg', 'bytes': 120},
            {'index': 1, 'extension': 'avif', 'bytes': 130},
          ],
        }),
      );

      final manifest = await fixture.api.fetchManifest(340);

      expect(manifest.id, 340);
      expect(manifest.bookId, 12);
      expect(manifest.filesVersion, 1758763245);
      expect(manifest.archiveBytes, 104857600);
      expect(manifest.archiveEtag, '68d5a2ed-6400000');
      expect(manifest.pageCount, 2);
      expect(manifest.pages.last.extension, 'avif');
      expect(
        manifest.pages.first.index,
        0,
        reason: 'index は ZIP のエントリ番号で /books/view のページ番号と同じ（#11 が使う）',
      );
      expect(
        fixture.adapter.requests.single.uri.toString(),
        'https://comic.lazgram.com/api/v2/volumes/340/manifest',
      );
    });

    test('削除済み / セーフモード外の巻は 404 として型で返す', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({
          'message': 'Not Found',
        }, statusCode: 404),
      );

      await expectLater(
        fixture.api.fetchManifest(340),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('fetchArchiveUrl（#22）', () {
    test('サーバー（VolumeService::buildArchiveSignedUrl）の形をそのまま読む', () async {
      const url =
          'https://comic.lazgram.com/api/v2/volumes/340/archive'
          '?expires=1759924800&t=12&v=1758763245&signature=0f3a';
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({
          'url': url,
          'expires_at': '2026-10-08T21:00:00+09:00',
          'files_version': 1758763245,
        }),
      );

      final archiveUrl = await fixture.api.fetchArchiveUrl(340);

      expect(archiveUrl.url, url, reason: '署名はクエリ全体に掛かるので手を加えない');
      expect(archiveUrl.filesVersion, 1758763245);
      expect(archiveUrl.expiresAt, DateTime.utc(2026, 10, 8, 12));
      expect(
        fixture.adapter.requests.single.uri.toString(),
        'https://comic.lazgram.com/api/v2/volumes/340/archive-url',
      );
    });

    test('スキームとホストは API と同じものに付け替える（パスとクエリはそのまま）', () async {
      // TLS を終端するプロキシの後ろだとサーバーは http:// の URL を作りうる。
      // ネイティブの転送は cleartext を許していないので全部失敗する。署名は
      // パスとクエリにしか掛かっていないので、付け替えても通る。
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({
          'url':
              'http://10.0.0.2/api/v2/volumes/340/archive'
              '?expires=1759924800&t=12&v=1758763245&signature=0f3a',
          'expires_at': '2026-10-08T21:00:00+09:00',
          'files_version': 1758763245,
        }),
      );

      final archiveUrl = await fixture.api.fetchArchiveUrl(340);

      expect(
        archiveUrl.url,
        'https://comic.lazgram.com/api/v2/volumes/340/archive'
        '?expires=1759924800&t=12&v=1758763245&signature=0f3a',
      );
    });

    test('files_version の無い応答は読めない応答として扱う', () async {
      // 0 で読むと、毎回「サーバー側のデータが更新されました」になって理由が分からない。
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({
          'url': 'https://comic.lazgram.com/api/v2/volumes/340/archive',
        }),
      );

      await expectLater(
        fixture.api.fetchArchiveUrl(340),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('配信できない巻は発行時点で 404 として型で返す', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({
          'message': 'Not Found',
        }, statusCode: 404),
      );

      await expectLater(
        fixture.api.fetchArchiveUrl(340),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}
