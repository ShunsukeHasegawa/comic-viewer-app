import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_config.dart';

part 'media_urls.g.dart';

/// 画像 URL の組み立てを 1 箇所に集約する（Web 版 `viewerPageUrl` 相当）。
///
/// キャッシュ（#8）やダウンロード（#9）はこのキーで内容を突き合わせるため、
/// URL を各所で組み立ててはいけない。
class MediaUrls {
  const MediaUrls(this._config);

  final AppConfig _config;

  /// ページ画像の URL。
  ///
  /// `?v={filesVersion}` は **必ず**付ける。ZIP を差し替えても URL が変わらないため、
  /// これが無いと古いキャッシュを読み続けてしまう。
  Uri page({
    required int volumeId,
    required int page,
    required int filesVersion,
  }) {
    return _config.resolvePath(
      '/books/view/$volumeId/$page',
      queryParameters: {'v': '$filesVersion'},
    );
  }

  /// サムネイルの URL。
  ///
  /// API が返す `?m=updated_at` 付きの相対 URL をそのまま絶対 URL にするだけ。
  /// `null` は「サムネイル無し」なので URL を組み立て直さない。
  Uri? thumbnail(String? apiUrl) {
    if (apiUrl == null) return null;
    final trimmed = apiUrl.trim();
    if (trimmed.isEmpty) return null;
    return _config.resolveRelative(trimmed);
  }

  /// キャッシュキーに付ける配信元。
  ///
  /// 保存先（`AppDirectories.imageCache` / drift の `comic_laz`）は配信元で
  /// 分かれていない。同じ端末・同じ applicationId で本番ビルドと
  /// `--dart-define=API_BASE_URL=...` の開発ビルドを行き来すると、巻 ID と
  /// `files_version` が一致した瞬間に別サーバーの画像が表示されてしまうため、
  /// **キー側で分ける**。
  ///
  /// 巻の接頭辞（`v{id}/`）で古い世代を掃除する `ImageCacheStore` を壊さないよう、
  /// 配信元は必ず**末尾**に付ける。
  String get _origin => '@${_config.apiBaseUrlString}';

  /// ページ画像のキャッシュキー（#8 のディスクキャッシュ / ダウンロードで使う）。
  String pageCacheKey({
    required int volumeId,
    required int page,
    required int filesVersion,
  }) => 'v$volumeId/$filesVersion/$page$_origin';

  /// サムネイルのキャッシュキー。`?m=` の値までを含めて世代を区別する。
  ///
  /// [thumbnail] と同じ正規化（trim / 空文字は「サムネイル無し」）を行う。
  /// キーと実際に取得する URL がずれないようにするため。
  String? thumbnailCacheKey(String? apiUrl) {
    final normalized = apiUrl?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    final uri = Uri.parse(normalized);
    final version = uri.queryParameters['m'] ?? '0';
    return 't${uri.path}/$version$_origin';
  }
}

@Riverpod(keepAlive: true)
MediaUrls mediaUrls(Ref ref) => MediaUrls(ref.watch(appConfigProvider));
