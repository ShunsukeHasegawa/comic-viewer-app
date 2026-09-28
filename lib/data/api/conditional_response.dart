/// 条件付き GET（`If-None-Match`）の結果。
///
/// `/api/books` は `private, max-age=0, must-revalidate` + ETag で配信されるので、
/// 手元に前回の ETag があれば 304 を狙える（数百 byte で済む）。
class ConditionalResponse<T> {
  /// 内容が返ってきた（200）。
  const ConditionalResponse.modified(T this.value, {this.etag})
    : isNotModified = false;

  /// 変更が無かった（304）。手元のキャッシュをそのまま使う。
  const ConditionalResponse.notModified({this.etag})
    : value = null,
      isNotModified = true;

  /// 304 のときは `null`。
  final T? value;

  /// 次回のリクエストで `If-None-Match` に渡す値。
  final String? etag;

  final bool isNotModified;

  @override
  String toString() =>
      'ConditionalResponse(isNotModified: $isNotModified, etag: $etag)';
}
