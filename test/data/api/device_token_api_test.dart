import 'dart:convert';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/data/api/api_client.dart';
import 'package:comic_laz/data/api/device_token_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

({DeviceTokenApi api, FakeHttpAdapter adapter}) buildApi([
  Future<ResponseBody> Function(RequestOptions options)? handler,
]) {
  final dio = Dio(BaseOptions(baseUrl: 'https://comic.lazgram.com/'));
  final adapter = FakeHttpAdapter(
    handler ??
        (options) async => ResponseBody.fromString(
          '"OK"',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
  );
  dio.httpClientAdapter = adapter;
  return (api: DeviceTokenApi(ApiClient(dio)), adapter: adapter);
}

void main() {
  test('登録はトークン・platform・端末名を POST する（サーバーの DeviceTokenRequest の形）', () async {
    final fixture = buildApi();

    await fixture.api.register(
      token: 'fcm-token',
      platform: DeviceTokenApi.platformAndroid,
      deviceName: 'Pixel 9',
    );

    final request = fixture.adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/api/user/device-token');
    expect(request.data, {
      'token': 'fcm-token',
      'platform': 'android',
      'device_name': 'Pixel 9',
    });
  });

  test('端末名は 100 文字に切り詰め、空なら送らない（サーバーの検証で落とさない）', () async {
    final fixture = buildApi();

    await fixture.api.register(
      token: 't',
      platform: 'android',
      deviceName: 'あ' * 120,
    );
    await fixture.api.register(
      token: 't',
      platform: 'android',
      deviceName: ' ',
    );

    final first = fixture.adapter.requests[0].data as Map<String, dynamic>;
    final second = fixture.adapter.requests[1].data as Map<String, dynamic>;
    expect((first['device_name'] as String).length, 100);
    expect(second.containsKey('device_name'), isFalse);
  });

  test('解除はクエリでトークンを渡す（DELETE の本文を落とす経路があるため）', () async {
    final fixture = buildApi();

    await fixture.api.unregister('fcm/token+1');

    final request = fixture.adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.uri.path, '/api/user/device-token');
    expect(request.uri.queryParameters, {'token': 'fcm/token+1'});
    expect(request.data, isNull);
  });

  test('テスト通知は GET で頼むだけ（応答の null を解釈しない）', () async {
    final fixture = buildApi(
      (options) async => ResponseBody.fromString(jsonEncode(null), 200),
    );

    await fixture.api.sendTest();

    final request = fixture.adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.uri.path, '/api/user/push-notification-test');
  });

  test('サーバーの失敗は ApiException で返す（画面に理由を出せるように）', () async {
    final fixture = buildApi(
      (options) async => FakeHttpAdapter.jsonResponse({
        'message': 'The token field is required.',
      }, statusCode: 422),
    );

    await expectLater(
      fixture.api.register(token: '', platform: 'android'),
      throwsA(isA<ApiException>()),
    );
  });
}
