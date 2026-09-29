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

  group('archiveUri', () {
    // OS の転送は dio を通らないので、dio と同じ規則で組み立てないと
    // 別のパス（サブパスの抜け落ち）へ取りに行ってしまう。
    test('ベース URL のサブパスを保ったまま ZIP の URL を組み立てる', () {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/comic/'));
      final api = HttpVolumesApi(client: ApiClient(dio), dio: dio);

      expect(
        api.archiveUri(340).toString(),
        'https://example.com/comic/api/v2/volumes/340/archive',
      );
    });
  });
}
