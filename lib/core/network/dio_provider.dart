import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/auth_store.dart';
import '../config/app_config.dart';
import 'auth_interceptor.dart';
import 'retry_interceptor.dart';

part 'dio_provider.g.dart';

/// Web 版 `utils/api.ts` と同じタイムアウト（8 秒）。
const apiTimeout = Duration(seconds: 8);

/// JSON API を叩くリクエストに付けるヘッダ。
///
/// 画像 / アーカイブ取得も同じ [Dio] を通す（Bearer 付与を共有するため）ので、
/// `Accept: application/json` は [BaseOptions] ではなくリクエスト単位で付ける。
/// 画像リクエストに JSON だけを advertise すると、コンテントネゴシエーションする
/// サーバーから 406 が返りうる。
const jsonAcceptHeaders = <String, String>{
  Headers.acceptHeader: Headers.jsonContentType,
};

/// アプリ共通の [Dio]。
///
/// ETag 条件付き GET やリトライ（#4）は追加のインターセプタで足す。
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      // dio は `baseUrl + path` の単純連結（スキーム以降の `//` だけ畳む）なので、
      // 末尾スラッシュを付けておくと path の先頭スラッシュの有無に依らず正しい URL になる。
      baseUrl: '${config.apiBaseUrlString}/',
      connectTimeout: apiTimeout,
      receiveTimeout: apiTimeout,
      sendTimeout: apiTimeout,
    ),
  );
  dio.interceptors.add(
    AuthInterceptor(
      authStore: ref.read(authStoreProvider),
      apiBaseUrl: config.apiBaseUrl,
      // 401 の時点で解決する（ここで読むと循環依存になる）。
      onUnauthorized: () =>
          ref.read(authControllerProvider.notifier).handleSessionExpired(),
    ),
  );
  // 一時的な通信エラーの 1 回だけの再送（GET / HEAD のみ）。
  dio.interceptors.add(RetryInterceptor(dio));
  ref.onDispose(() => dio.close());
  return dio;
}
