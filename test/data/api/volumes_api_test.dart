import 'dart:io';
import 'dart:typed_data';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/data/api/api_client.dart';
import 'package:comic_laz/data/api/volumes_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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

/// ZIP 本文を返す応答（`dio` にストリームとして渡す）。
ResponseBody archiveResponse(
  List<int> bytes, {
  int statusCode = 200,
  Map<String, List<String>>? headers,
}) => ResponseBody.fromBytes(
  bytes,
  statusCode,
  headers: {
    Headers.contentTypeHeader: ['application/zip'],
    Headers.contentLengthHeader: ['${bytes.length}'],
    ...?headers,
  },
);

/// 使い捨ての保存先。
File tempTarget(String name) {
  final root = Directory.systemTemp.createTempSync('comic_laz_archive');
  addTearDown(() {
    try {
      if (root.existsSync()) root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows では掴まれていることがある。一時領域なので OS に任せる。
    }
  });
  return File(p.join(root.path, name));
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

  group('downloadArchive', () {
    test('保存先が無ければ Range を付けずに取り、そのまま書く', () async {
      final bytes = Uint8List.fromList(List.generate(64, (i) => i));
      final fixture = buildApi((options) async => archiveResponse(bytes));
      final target = tempTarget('1.zip.part');

      final progress = <int>[];
      final result = await fixture.api.downloadArchive(
        volumeId: 340,
        target: target,
        onProgress: (received, total) => progress.add(received),
      );

      expect(result.resumed, isFalse);
      expect(result.receivedBytes, 64);
      expect(result.contentLength, 64);
      expect(target.readAsBytesSync(), bytes);
      expect(progress.last, 64);
      final request = fixture.adapter.requests.single;
      expect(request.headers.containsKey('range'), isFalse);
      expect(
        request.uri.toString(),
        'https://comic.lazgram.com/api/v2/volumes/340/archive',
      );
    });

    test('途中まである保存先は Range と If-Range を付けて続きから取る', () async {
      final bytes = Uint8List.fromList(List.generate(64, (i) => i));
      final fixture = buildApi(
        (options) async => archiveResponse(
          bytes.sublist(40),
          statusCode: 206,
          headers: {
            'content-range': ['bytes 40-63/64'],
          },
        ),
      );
      final target = tempTarget('1.zip.part')
        ..writeAsBytesSync(bytes.sublist(0, 40));

      final result = await fixture.api.downloadArchive(
        volumeId: 340,
        target: target,
        ifRangeEtag: '68d5a2ed-40',
      );

      expect(result.resumed, isTrue);
      expect(result.receivedBytes, 64, reason: '再開時の受信量は既存分を含む全体のバイト数');
      expect(
        result.contentLength,
        64,
        reason: '206 の Content-Length は応答分だけなので Content-Range の全体長を見る',
      );
      expect(target.readAsBytesSync(), bytes, reason: '続きが追記されて元通りになる');

      final request = fixture.adapter.requests.single;
      expect(request.headers['range'], 'bytes=40-');
      expect(
        request.headers['if-range'],
        '"68d5a2ed-40"',
        reason: 'Symfony / nginx の ETag は引用符付きなので同じ形にして送る',
      );
    });

    test('Range を無視して 200 が返ったら先頭から書き直す（別世代を継ぎ足さない）', () async {
      // ZIP が差し替わって If-Range が外れた状況。サーバーは全体を 200 で返す。
      final fresh = Uint8List.fromList(List.filled(20, 0x39));
      final fixture = buildApi((options) async => archiveResponse(fresh));
      final target = tempTarget('1.zip.part')
        ..writeAsBytesSync(Uint8List.fromList(List.filled(40, 0x41)));

      final result = await fixture.api.downloadArchive(
        volumeId: 340,
        target: target,
        ifRangeEtag: '68d5a2ed-40',
      );

      expect(result.resumed, isFalse);
      expect(result.receivedBytes, 20);
      expect(
        target.readAsBytesSync(),
        fresh,
        reason: '古い 40 バイトが残ると壊れた ZIP になる（切り詰めて書き直す）',
      );
    });

    test('416 などは ApiException にする（成功として扱わない）', () async {
      final fixture = buildApi(
        (options) async => archiveResponse(const [], statusCode: 416),
      );
      final target = tempTarget('1.zip.part')
        ..writeAsBytesSync(Uint8List.fromList(List.filled(8, 0x41)));

      await expectLater(
        fixture.api.downloadArchive(volumeId: 340, target: target),
        throwsA(isA<ApiException>()),
      );
    });

    test('キャンセルは型で分かる（書けた分は再開の起点として残す）', () async {
      final bytes = Uint8List.fromList(List.filled(32, 0x42));
      final token = CancelToken();
      final fixture = buildApi((options) async {
        token.cancel('paused');
        return archiveResponse(bytes);
      });
      final target = tempTarget('1.zip.part');

      await expectLater(
        fixture.api.downloadArchive(
          volumeId: 340,
          target: target,
          cancelToken: token,
        ),
        throwsA(isA<RequestCancelledException>()),
      );
    });

    test('429 は Retry-After を持った例外にする（キューがバックオフに使う）', () async {
      final fixture = buildApi(
        (options) async => archiveResponse(
          const [],
          statusCode: 429,
          headers: {
            'retry-after': ['7'],
          },
        ),
      );
      final target = tempTarget('1.zip.part');

      await expectLater(
        fixture.api.downloadArchive(volumeId: 340, target: target),
        throwsA(
          isA<TooManyRequestsException>().having(
            (error) => error.retryAfter,
            'retryAfter',
            const Duration(seconds: 7),
          ),
        ),
      );
    });
  });
}
