import 'package:dio/dio.dart';

import '../../features/auth/data/auth_store.dart';

/// このキーが `true` のリクエストには `Authorization` を付けず、
/// 401 もセッション失効として扱わない（ログイン自体など）。
const skipAuthExtraKey = 'comic_laz.skip_auth';

/// 保存済みトークンを `Authorization: Bearer` として付与し、401 を通知する。
///
/// 付与と 401 の扱いは **API と同じオリジン**のリクエストに限る。
/// 画像やアーカイブが将来 CDN / 署名付き URL に変わったときに、
/// 他ホストへトークンを送ってしまったり、他ホストの 401 でログアウトさせて
/// しまわないため。
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.authStore,
    required this.apiBaseUrl,
    required this.onUnauthorized,
  });

  final AuthStore authStore;

  /// トークンを送ってよい配信元。
  final Uri apiBaseUrl;

  /// 401 を受けたときに呼ぶ（セッション失効の片付け）。
  final Future<void> Function() onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_skipAuth(options) ||
        !_isApiRequest(options) ||
        _hasAuthorizationHeader(options)) {
      handler.next(options);
      return;
    }

    final token = await authStore.readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 401 のみセッション失効として扱う。403 は「認証済みだがこのリソースには
    // 権限が無い」（セーフモードなど）であり、ログアウトさせるのは誤り。
    if (err.response?.statusCode == 401 &&
        !_skipAuth(err.requestOptions) &&
        _isApiRequest(err.requestOptions)) {
      await onUnauthorized();
    }
    handler.next(err);
  }

  /// API と同じ配信元へのリクエストか。
  bool _isApiRequest(RequestOptions options) {
    final uri = options.uri;
    return uri.scheme == apiBaseUrl.scheme &&
        uri.host == apiBaseUrl.host &&
        uri.port == apiBaseUrl.port;
  }

  static bool _skipAuth(RequestOptions options) =>
      options.extra[skipAuthExtraKey] == true;

  static bool _hasAuthorizationHeader(RequestOptions options) =>
      options.headers.keys.any((key) => key.toLowerCase() == 'authorization');
}
