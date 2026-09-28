import 'dart:io';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException dioError(
  DioExceptionType type, {
  Response<dynamic>? response,
  Object? error,
}) {
  return DioException(
    requestOptions: RequestOptions(path: '/api/books'),
    type: type,
    response: response,
    error: error,
  );
}

Response<dynamic> responseWith(
  int statusCode, {
  Object? data,
  Map<String, List<String>> headers = const {},
}) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: '/api/books'),
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap(headers),
  );
}

void main() {
  test('タイムアウトは種別ごとにまとめる', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      expect(ApiException.from(dioError(type)), isA<ApiTimeoutException>());
    }
  });

  test('接続エラー / SocketException はネットワークエラー', () {
    expect(
      ApiException.from(dioError(DioExceptionType.connectionError)),
      isA<NetworkException>(),
    );
    expect(
      ApiException.from(
        dioError(
          DioExceptionType.unknown,
          error: const SocketException('failed'),
        ),
      ),
      isA<NetworkException>(),
    );
  });

  test('ステータスコードを種別に対応づける', () {
    ApiException mapStatus(int code, {Object? data}) => ApiException.from(
      dioError(
        DioExceptionType.badResponse,
        response: responseWith(code, data: data),
      ),
    );

    expect(mapStatus(401), isA<UnauthorizedException>());
    expect(mapStatus(403), isA<ForbiddenException>());
    expect(mapStatus(404), isA<NotFoundException>());
    expect(mapStatus(422), isA<ValidationException>());
    expect(mapStatus(418), isA<UnexpectedResponseException>());
    expect(mapStatus(500), isA<ServerException>());
    expect(
      mapStatus(503),
      isA<ServerException>().having((e) => e.statusCode, '', 503),
    );
  });

  test('404 と通信エラーは別の型になる（進捗を誤って捨てないため）', () {
    final notFound = ApiException.from(
      dioError(DioExceptionType.badResponse, response: responseWith(404)),
    );
    final offline = ApiException.from(
      dioError(DioExceptionType.connectionError),
    );

    expect(notFound, isA<NotFoundException>());
    expect(offline, isNot(isA<NotFoundException>()));
  });

  test('422 は errors をフィールドごとに読む', () {
    final exception = ApiException.from(
      dioError(
        DioExceptionType.badResponse,
        response: responseWith(
          422,
          data: {
            'message': 'invalid',
            'errors': {
              'email': ['メールアドレスが不正です'],
              'password': 'パスワードが必要です',
            },
          },
        ),
      ),
    ) as ValidationException;

    expect(exception.errors['email'], ['メールアドレスが不正です']);
    expect(exception.errors['password'], ['パスワードが必要です']);
  });

  test('429 は Retry-After を読む', () {
    final exception = ApiException.from(
      dioError(
        DioExceptionType.badResponse,
        response: responseWith(
          429,
          headers: {
            'retry-after': ['30'],
          },
        ),
      ),
    ) as TooManyRequestsException;

    expect(exception.retryAfter, const Duration(seconds: 30));
  });

  test('ApiException はそのまま通す', () {
    const original = NotFoundException();
    expect(ApiException.from(original), same(original));
  });

  test('キャンセルは専用の型になる', () {
    expect(
      ApiException.from(dioError(DioExceptionType.cancel)),
      isA<RequestCancelledException>(),
    );
  });
}
