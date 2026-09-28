import 'package:comic_laz/core/config/app_config.dart';
import 'package:comic_laz/core/network/dio_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Dio buildDio(String apiBaseUrl) {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.from(apiBaseUrl: apiBaseUrl, flavor: 'development'),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(dioProvider);
}

void main() {
  test('設定のベース URL とタイムアウトを持つ', () {
    final dio = buildDio('http://localhost:8000');

    expect(dio.options.baseUrl, 'http://localhost:8000/');
    expect(dio.options.connectTimeout, apiTimeout);
    expect(dio.options.receiveTimeout, apiTimeout);
    expect(dio.options.sendTimeout, apiTimeout);
  });

  test('Accept はリクエスト単位で付ける（画像取得で 406 を招かないため）', () {
    final dio = buildDio('http://localhost:8000');

    expect(dio.options.headers[Headers.acceptHeader], isNull);
    expect(jsonAcceptHeaders[Headers.acceptHeader], Headers.jsonContentType);
  });

  test('path の先頭スラッシュの有無で URL が変わらない', () {
    final dio = buildDio('https://comic.lazgram.com');

    for (final path in ['/api/books', 'api/books']) {
      expect(
        RequestOptions(baseUrl: dio.options.baseUrl, path: path).uri.toString(),
        'https://comic.lazgram.com/api/books',
        reason: 'path="$path"',
      );
    }
  });

  test('サブパス付きのベース URL でもパスが消えない', () {
    final dio = buildDio('https://example.com/comic');

    expect(
      RequestOptions(
        baseUrl: dio.options.baseUrl,
        path: '/api/books',
      ).uri.toString(),
      'https://example.com/comic/api/books',
    );
  });
}
