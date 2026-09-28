import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/network/auth_interceptor.dart';
import 'package:comic_laz/features/auth/data/auth_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

({AuthApi api, FakeHttpAdapter adapter}) buildApi(
  Future<ResponseBody> Function(RequestOptions options) handler,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://comic.lazgram.com/'));
  final adapter = FakeHttpAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (api: AuthApi(dio), adapter: adapter);
}

void main() {
  group('createToken', () {
    test('トークンとユーザーを読み、device_name を送る', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({
          'token': 'plain-text-token',
          'user': {
            'id': 7,
            'name': '長谷川',
            'email': 'a@example.com',
            'is_admin': 1,
          },
        }),
      );

      final result = await fixture.api.createToken(
        email: 'a@example.com',
        password: 'secret',
        deviceName: 'Pixel 8',
      );

      expect(result.token, 'plain-text-token');
      expect(result.user?.id, 7);
      expect(result.user?.isAdmin, isTrue);

      final request = fixture.adapter.requests.single;
      expect(
        request.uri.toString(),
        'https://comic.lazgram.com/api/auth/token',
      );
      expect(request.data, {
        'email': 'a@example.com',
        'password': 'secret',
        'device_name': 'Pixel 8',
      });
      // 失効済みトークンを付けて 401 ループに入らないようにする
      expect(request.extra[skipAuthExtraKey], isTrue);
    });

    test('ユーザーを返さないサーバーでもトークンだけ読める', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({'token': 'abc'}),
      );

      final result = await fixture.api.createToken(
        email: 'a@example.com',
        password: 'secret',
        deviceName: 'Pixel 8',
      );

      expect(result.token, 'abc');
      expect(result.user, isNull);
    });

    test('401 / 422 は「認証情報が違う」として扱う（セッション失効ではない）', () async {
      for (final statusCode in [401, 422]) {
        final fixture = buildApi(
          (options) async => FakeHttpAdapter.jsonResponse({
            'message': 'invalid',
          }, statusCode: statusCode),
        );

        await expectLater(
          fixture.api.createToken(
            email: 'a@example.com',
            password: 'x',
            deviceName: 'd',
          ),
          throwsA(isA<InvalidCredentialsException>()),
          reason: 'HTTP $statusCode',
        );
      }
    });

    test('トークンが無い応答は想定外エラー', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({'token': ''}),
      );

      await expectLater(
        fixture.api.createToken(
          email: 'a@example.com',
          password: 'x',
          deviceName: 'd',
        ),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('5xx はサーバーエラーとして伝える', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(null, statusCode: 500),
      );

      await expectLater(
        fixture.api.createToken(
          email: 'a@example.com',
          password: 'x',
          deviceName: 'd',
        ),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('fetchCurrentUser', () {
    test('safe_mode / is_admin が 0 / 1 でも読める', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({
          'id': 3,
          'name': 'admin',
          'is_admin': 0,
          'safe_mode': 1,
        }),
      );

      final user = await fixture.api.fetchCurrentUser();

      expect(user.isAdmin, isFalse);
      expect(user.safeMode, isTrue);
      expect(fixture.adapter.requests.single.uri.path, '/api/user');
    });

    test('401 はセッション失効として伝える', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(null, statusCode: 401),
      );

      await expectLater(
        fixture.api.fetchCurrentUser(),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('必須フィールドが欠けた応答は想定外エラー', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({'name': 'no id'}),
      );

      await expectLater(
        fixture.api.fetchCurrentUser(),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });
  });

  group('deleteToken', () {
    test('DELETE /api/auth/token を叩く', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(null, statusCode: 204),
      );

      await fixture.api.deleteToken();

      final request = fixture.adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.uri.path, '/api/auth/token');
    });

    test('通信エラーは種別つきで投げ直す', () async {
      final fixture = buildApi(
        (options) async => throw DioException(
          requestOptions: RequestOptions(path: '/api/auth/token'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        fixture.api.deleteToken(),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
