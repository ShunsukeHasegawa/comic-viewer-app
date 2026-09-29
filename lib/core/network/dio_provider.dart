import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/auth_store.dart';
import '../config/app_config.dart';
import 'auth_interceptor.dart';
import 'retry_interceptor.dart';

part 'dio_provider.g.dart';

/// Web 版 `utils/api.ts` と同じタイムアウト（8 秒）。
const apiTimeout = Duration(seconds: 8);

/// 画像 / アーカイブ取得のタイムアウト。
///
/// 同じ [Dio] を通すが、JSON API の 8 秒をそのまま当てると落ちる。自宅サーバー
/// （HDD）は久しく触っていない ZIP をシークするのに時間がかかり、応答が始まる前に
/// `receiveTimeout` で切れる → `RetryInterceptor` がもう一度大きい画像を取りに行き、
/// 待っていれば表示できたページが約 2 倍の時間のあと失敗になる。
const imageTimeout = Duration(seconds: 60);

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
      config: config,
      // 401 の時点で解決する（ここで読むと循環依存になる）。
      onUnauthorized: () =>
          ref.read(authControllerProvider.notifier).handleSessionExpired(),
    ),
  );
  // 一時的な通信エラーの 1 回だけの再送（GET / HEAD のみ）。
  dio.interceptors.add(RetryInterceptor(dio));
  if (kDebugMode) dio.interceptors.add(FailedRequestLogger());
  ref.onDispose(() => dio.close());
  return dio;
}

/// 失敗したリクエストだけを `logcat` / コンソールへ出す（デバッグビルド限定）。
///
/// 画面に出せるのは利用者向けの文言だけなので、実機で「どの URL が何で失敗したか」
/// が分からない。成功したリクエストは出さない（ページ画像で数百行流れる）。
class FailedRequestLogger extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    debugPrint(
      '[api] ${err.requestOptions.method} '
      '${err.requestOptions.uri} -> ${status ?? err.type.name}',
    );
    handler.next(err);
  }
}
