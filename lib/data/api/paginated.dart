import '../../core/network/api_exception.dart';
import 'api_client.dart';

/// Laravel のページネーション応答。
///
/// API Resource コレクション（`{data, links, meta}`）と、
/// `paginate()` をそのまま返した形（`current_page` などが**トップレベル**）の
/// 両方を受ける。後者を取りこぼすと 2 ページ目を読めなくなる。
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) itemFromJson, {
    required String path,
  }) {
    final rawItems = json['data'];
    if (rawItems is! List) {
      throw UnexpectedResponseException(detail: '$path: data 配列が無い応答');
    }
    final meta = json['meta'];
    final metaMap = meta is Map<String, dynamic>
        ? meta
        : const <String, dynamic>{};

    int field(String key, int fallback) =>
        _intOrNull(metaMap[key]) ?? _intOrNull(json[key]) ?? fallback;

    return Paginated(
      items: ApiClient.parseList(
        ApiClient.asObjectList(rawItems, path),
        itemFromJson,
        path: path,
      ),
      currentPage: field('current_page', 1),
      lastPage: field('last_page', 1),
      total: field('total', rawItems.length),
    );
  }

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  static int? _intOrNull(Object? value) => switch (value) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value),
    _ => null,
  };
}
