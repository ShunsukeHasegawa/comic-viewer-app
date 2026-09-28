import 'dart:io';

import 'package:comic_laz/core/network/retry_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

/// 最初の [failures] 回だけ指定のエラーを投げ、その後は 200 を返すアダプタ。
({Dio dio, FakeHttpAdapter adapter}) buildDio({
  required int failures,
  DioExceptionType type = DioExceptionType.connectionError,
}) {
  var remaining = failures;
  final adapter = FakeHttpAdapter((options) async {
    if (remaining > 0) {
      remaining--;
      throw DioException(requestOptions: options, type: type);
    }
    return FakeHttpAdapter.jsonResponse({'ok': true});
  });
  final dio = Dio(BaseOptions(baseUrl: 'https://comic.lazgram.com/'))
    ..httpClientAdapter = adapter;
  dio.interceptors.add(RetryInterceptor(dio));
  return (dio: dio, adapter: adapter);
}

void main() {
  test('GET は一時的な通信エラーで 1 回だけ再送する', () async {
    final fixture = buildDio(failures: 1);

    final response = await fixture.dio.get<dynamic>('api/books');

    expect(response.statusCode, 200);
    expect(fixture.adapter.requests, hasLength(2));
    expect(fixture.adapter.requests.last.extra[retriedExtraKey], isTrue);
  });

  test('再送しても失敗したら諦める（無限リトライしない）', () async {
    final fixture = buildDio(failures: 5);

    await expectLater(
      fixture.dio.get<dynamic>('api/books'),
      throwsA(isA<DioException>()),
    );

    expect(fixture.adapter.requests, hasLength(2));
  });

  test('タイムアウトも再送対象', () async {
    final fixture = buildDio(
      failures: 1,
      type: DioExceptionType.receiveTimeout,
    );

    await fixture.dio.get<dynamic>('api/books');

    expect(fixture.adapter.requests, hasLength(2));
  });

  test('unknown + SocketException も再送する（回線切断の瞬間）', () async {
    var remaining = 1;
    final adapter = FakeHttpAdapter((options) async {
      if (remaining > 0) {
        remaining--;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: const SocketException('closed'),
        );
      }
      return FakeHttpAdapter.jsonResponse({'ok': true});
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://comic.lazgram.com/'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(RetryInterceptor(dio));

    final response = await dio.get<dynamic>('api/books');

    expect(response.statusCode, 200);
    expect(adapter.requests, hasLength(2));
  });

  test('POST は再送しない（副作用があるため）', () async {
    final fixture = buildDio(failures: 1);

    await expectLater(
      fixture.dio.post<dynamic>('api/user-volume-status/1'),
      throwsA(isA<DioException>()),
    );

    expect(fixture.adapter.requests, hasLength(1));
  });

  test('サーバーエラー（5xx）は再送しない', () async {
    final adapter = FakeHttpAdapter(
      (options) async => FakeHttpAdapter.jsonResponse(null, statusCode: 503),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://comic.lazgram.com/'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(RetryInterceptor(dio));

    await expectLater(
      dio.get<dynamic>('api/books'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.requests, hasLength(1), reason: 'HDD サーバーを叩き直さない');
  });

  test('キャンセルは再送しない', () async {
    final adapter = FakeHttpAdapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      ),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://comic.lazgram.com/'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(RetryInterceptor(dio));

    await expectLater(
      dio.get<dynamic>('api/books'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.requests, hasLength(1));
  });
}
