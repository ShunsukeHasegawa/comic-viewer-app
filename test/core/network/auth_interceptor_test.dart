import 'package:comic_laz/core/network/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/fake_http_adapter.dart';

void main() {
  late FakeAuthStore store;
  late int unauthorizedCalls;
  late Dio dio;
  late FakeHttpAdapter adapter;

  void setUpDio({int statusCode = 200}) {
    adapter = FakeHttpAdapter(
      (options) async =>
          FakeHttpAdapter.jsonResponse({}, statusCode: statusCode),
    );
    dio = Dio(BaseOptions(baseUrl: 'https://comic.lazgram.com/'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(
          authStore: store,
          apiBaseUrl: Uri.parse('https://comic.lazgram.com'),
          onUnauthorized: () async => unauthorizedCalls++,
        ),
      );
  }

  setUp(() {
    store = FakeAuthStore(token: 'stored-token');
    unauthorizedCalls = 0;
  });

  test('保存済みトークンを Bearer として付与する', () async {
    setUpDio();

    await dio.get<void>('api/books');

    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer stored-token',
    );
  });

  test('トークンが無ければヘッダを付けない', () async {
    store.token = null;
    setUpDio();

    await dio.get<void>('api/books');

    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test('skipAuth のリクエストにはヘッダを付けない', () async {
    setUpDio();

    await dio.get<void>(
      'api/auth/token',
      options: Options(extra: const {skipAuthExtraKey: true}),
    );

    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test('呼び出し側が指定した Authorization を上書きしない', () async {
    setUpDio();

    await dio.get<void>(
      'api/books',
      options: Options(headers: {'authorization': 'Bearer explicit'}),
    );

    // dio のヘッダマップは大文字小文字を区別しないため、値が保たれていることで判定する。
    expect(adapter.requests.single.headers['authorization'], 'Bearer explicit');
  });

  test('API 以外のホストにはトークンを送らない', () async {
    setUpDio();

    await dio.get<void>('https://cdn.example.com/pages/1.jpg');

    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
      reason: '別ホストにトークンを渡してはいけない',
    );
  });

  test('API 以外のホストの 401 ではログアウトさせない', () async {
    setUpDio(statusCode: 401);

    await expectLater(
      dio.get<void>('https://cdn.example.com/pages/1.jpg'),
      throwsA(isA<DioException>()),
    );

    expect(unauthorizedCalls, 0);
  });

  test('401 はセッション失効として通知する', () async {
    setUpDio(statusCode: 401);

    await expectLater(dio.get<void>('api/books'), throwsA(isA<DioException>()));

    expect(unauthorizedCalls, 1);
  });

  test('403 は通知しない（リソース単位の権限エラーでログアウトさせない）', () async {
    setUpDio(statusCode: 403);

    await expectLater(dio.get<void>('api/books'), throwsA(isA<DioException>()));

    expect(unauthorizedCalls, 0);
  });

  test('ログイン要求の 401 は通知しない', () async {
    setUpDio(statusCode: 401);

    await expectLater(
      dio.post<void>(
        'api/auth/token',
        options: Options(extra: const {skipAuthExtraKey: true}),
      ),
      throwsA(isA<DioException>()),
    );

    expect(unauthorizedCalls, 0);
  });
}
