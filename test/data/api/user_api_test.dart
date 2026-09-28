import 'dart:convert';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/data/api/api_client.dart';
import 'package:comic_laz/data/api/taxonomy_api.dart';
import 'package:comic_laz/data/api/user_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fixtures.dart';
import '../../support/fake_http_adapter.dart';

({UserApi api, TaxonomyApi taxonomy, FakeHttpAdapter adapter}) buildApi(
  Future<ResponseBody> Function(RequestOptions options) handler,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://comic.lazgram.com/'));
  final adapter = FakeHttpAdapter(handler);
  dio.httpClientAdapter = adapter;
  final client = ApiClient(dio);
  return (
    api: UserApi(client),
    taxonomy: TaxonomyApi(client),
    adapter: adapter,
  );
}

void main() {
  group('fetchReading', () {
    test('data ラップを外して読む', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(ApiFixtures.reading),
      );

      final reading = await fixture.api.fetchReading();

      expect(reading, hasLength(1));
      expect(reading.single.bookId, 12);
      expect(reading.single.volumeId, 340);
      expect(reading.single.progressPercent, 6);
      expect(fixture.adapter.requests.single.uri.path, '/api/v2/user/reading');
    });

    test('data が無い応答は想定外エラー', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(<String, dynamic>{}),
      );

      await expectLater(
        fixture.api.fetchReading(),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });
  });

  test('fetchStats は月別集計まで読む', () async {
    final fixture = buildApi(
      (options) async => FakeHttpAdapter.jsonResponse(ApiFixtures.stats),
    );

    final stats = await fixture.api.fetchStats();

    expect(stats.titlesCompleted, 3);
    expect(stats.volumesCompleted, 42);
    expect(stats.monthly, hasLength(2));
    expect(stats.monthly.last.month, '2026-09');
    expect(stats.monthly.last.count, 5);
  });

  group('fetchHistory', () {
    test('ページネーション情報つきで読む', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(ApiFixtures.history),
      );

      final history = await fixture.api.fetchHistory(page: 1);

      expect(history.items.single.id, 340);
      expect(history.items.single.bookId, 12);
      expect(history.items.single.isFinished, isTrue);
      expect(
        history.items.single.updatedAt,
        DateTime.utc(2026, 9, 25, 1, 0, 45),
      );
      expect(history.currentPage, 1);
      expect(history.lastPage, 3);
      expect(history.total, 25);
      expect(history.hasMore, isTrue);
      expect(fixture.adapter.requests.single.uri.query, 'page=1');
    });

    test('paginate() をそのまま返す形（トップレベル）でもページ情報を読む', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({
          'data': [(ApiFixtures.history['data']! as List).first],
          'current_page': 2,
          'last_page': 5,
          'total': 47,
        }),
      );

      final history = await fixture.api.fetchHistory(page: 2);

      expect(history.currentPage, 2);
      expect(history.lastPage, 5);
      expect(history.total, 47);
      expect(history.hasMore, isTrue, reason: '2 ページ目以降を読めなくなってはいけない');
    });

    test('ページ情報がどこにも無ければ 1 ページとして扱う', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse({
          'data': [(ApiFixtures.history['data']! as List).first],
        }),
      );

      final history = await fixture.api.fetchHistory();

      expect(history.currentPage, 1);
      expect(history.lastPage, 1);
      expect(history.hasMore, isFalse);
      expect(history.total, 1);
    });
  });

  group('recordVolumeStatus', () {
    test('ページ情報と端末時刻を送る（応答は OK テキスト）', () async {
      final fixture = buildApi(
        (options) async => ResponseBody.fromString('OK', 200),
      );

      await fixture.api.recordVolumeStatus(
        volumeId: 340,
        currentPage: 12,
        maxPage: 190,
        readAt: DateTime.utc(2026, 9, 25, 1, 2, 3),
      );

      final request = fixture.adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/user-volume-status/340');
      expect(request.data, {
        'current_page': 12,
        'max_page': 190,
        'read_at': '2026-09-25T01:02:03.000Z',
      });
    });

    test('read_at は省略できる', () async {
      final fixture = buildApi(
        (options) async => ResponseBody.fromString('OK', 200),
      );

      await fixture.api.recordVolumeStatus(
        volumeId: 340,
        currentPage: 1,
        maxPage: 5,
      );

      expect(
        (fixture.adapter.requests.single.data! as Map).containsKey('read_at'),
        isFalse,
      );
    });

    test('セーフモードで隠れている巻は 404', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse(null, statusCode: 404),
      );

      await expectLater(
        fixture.api.recordVolumeStatus(
          volumeId: 340,
          currentPage: 1,
          maxPage: 5,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('TaxonomyApi', () {
    test('カテゴリとタグを読む（余分なカラムは無視する）', () async {
      final fixture = buildApi(
        (options) async => FakeHttpAdapter.jsonResponse([
          {
            'id': 1,
            'name': '少年',
            'created_at': '2026-01-01T00:00:00.000000Z',
            'updated_at': '2026-01-01T00:00:00.000000Z',
          },
          {'id': 2, 'name': '青年'},
        ]),
      );

      final categories = await fixture.taxonomy.fetchCategories();

      expect(categories.map((c) => c.name), ['少年', '青年']);
      expect(fixture.adapter.requests.single.uri.path, '/api/category');
    });

    test('タグは /api/tag を叩く', () async {
      final fixture = buildApi(
        (options) async => ResponseBody.fromString(
          jsonEncode([
            {'id': 3, 'name': 'アクション'},
          ]),
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );

      final tags = await fixture.taxonomy.fetchTags();

      expect(tags.single.id, 3);
      expect(fixture.adapter.requests.single.uri.path, '/api/tag');
    });
  });
}
