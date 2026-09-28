import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/models/reading_book.dart';
import 'api_client.dart';

part 'taxonomy_api.g.dart';

/// カテゴリ / タグ（絞り込みチップ用）。
///
/// どちらも静的 JSON として配信され、`data` ラップは無い。
class TaxonomyApi {
  const TaxonomyApi(this._client);

  static const categoryPath = 'api/category';
  static const tagPath = 'api/tag';

  final ApiClient _client;

  Future<List<Taxonomy>> fetchCategories() => _fetch(categoryPath);

  Future<List<Taxonomy>> fetchTags() => _fetch(tagPath);

  Future<List<Taxonomy>> _fetch(String path) async {
    final list = await _client.getObjectList(path);
    return ApiClient.parseList(list, Taxonomy.fromJson, path: path);
  }
}

@Riverpod(keepAlive: true)
TaxonomyApi taxonomyApi(Ref ref) => TaxonomyApi(ref.watch(apiClientProvider));
