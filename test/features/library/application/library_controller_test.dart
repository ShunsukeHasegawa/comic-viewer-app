import 'dart:async';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/domain/models/reading_book.dart';
import 'package:comic_laz/features/library/application/library_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/api_fakes.dart';
import '../../../support/test_scope.dart';

/// 「続きを読む」の応答を外から止めておける [FakeUserApi]。
class _GatedUserApi extends FakeUserApi {
  final gate = Completer<void>();
  var started = 0;

  @override
  Future<List<ReadingBook>> fetchReading() async {
    started++;
    await gate.future;
    return super.fetchReading();
  }
}

/// カテゴリ / タグの応答を外から止めておける [FakeTaxonomyApi]。
class _GatedTaxonomyApi extends FakeTaxonomyApi {
  _GatedTaxonomyApi({super.categories, super.tags});

  final gate = Completer<void>();
  var categoriesStarted = 0;
  var tagsStarted = 0;

  @override
  Future<List<Taxonomy>> fetchCategories() async {
    categoriesStarted++;
    await gate.future;
    return super.fetchCategories();
  }

  @override
  Future<List<Taxonomy>> fetchTags() async {
    tagsStarted++;
    await gate.future;
    return super.fetchTags();
  }
}

void main() {
  // 互いに独立した 3 つを順に待つと、往復の分だけ一覧の表示が遅れる（#28）。
  test('続きを読む / カテゴリ / タグはどれかの応答を待たずに同時に取りに行く', () async {
    final userApi = _GatedUserApi();
    final taxonomyApi = _GatedTaxonomyApi(
      categories: const [Taxonomy(id: 1, name: '少年')],
      tags: const [Taxonomy(id: 9, name: '完結')],
    );
    final container = createContainer(
      booksApi: FakeBooksApi(books: [testBook(id: 1)]),
      userApi: userApi,
      taxonomyApi: taxonomyApi,
    );
    addTearDown(container.dispose);
    final sub = container.listen(libraryControllerProvider, (_, _) {});
    addTearDown(sub.close);

    await pumpEventQueue();
    expect(userApi.started, 1);
    expect(taxonomyApi.categoriesStarted, 1, reason: '続きを読むの応答を待っていない');
    expect(taxonomyApi.tagsStarted, 1, reason: 'カテゴリの応答を待っていない');

    userApi.gate.complete();
    taxonomyApi.gate.complete();
    final data = await container.read(libraryControllerProvider.future);

    expect(data.categories.single.name, '少年');
    expect(data.tags.single.name, '完結');
  });

  // 同時に始めても、取得ごとの代替（取れなければ空 / 前回 / 端末の控え）は変えない。
  test('カテゴリ / タグが圏外でも一覧は出す', () async {
    final container = createContainer(
      booksApi: FakeBooksApi(books: [testBook(id: 1)]),
      userApi: FakeUserApi(),
      taxonomyApi: FakeTaxonomyApi(error: const NetworkException()),
    );
    addTearDown(container.dispose);
    final sub = container.listen(libraryControllerProvider, (_, _) {});
    addTearDown(sub.close);

    final data = await container.read(libraryControllerProvider.future);

    expect(data.books, hasLength(1));
    expect(data.categories, isEmpty);
    expect(data.tags, isEmpty);
  });

  // セッション失効は包まずにそのまま投げる（ParallelWaitError などに包むと、
  // 401 を見てログイン画面へ戻す側が気づけない）。同時に失敗した他の取得を
  // 未処理のエラーにもしない（テストのゾーンが拾って失敗する）。
  test('続きを読むが 401 なら、他の取得も失敗していても 401 のまま投げる', () async {
    final container = createContainer(
      booksApi: FakeBooksApi(books: [testBook(id: 1)]),
      userApi: FakeUserApi(readingError: const UnauthorizedException()),
      taxonomyApi: FakeTaxonomyApi(error: const UnauthorizedException()),
    );
    addTearDown(container.dispose);
    final sub = container.listen(libraryControllerProvider, (_, _) {});
    addTearDown(sub.close);

    await expectLater(
      container.read(libraryControllerProvider.future),
      throwsA(isA<UnauthorizedException>()),
    );
  });
}
