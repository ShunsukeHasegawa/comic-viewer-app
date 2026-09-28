import 'dart:io';

import 'package:dio/dio.dart';

/// 再送済みのリクエストを示すキー（無限リトライを防ぐ）。
const retriedExtraKey = 'comic_laz.retried';

/// 一時的な通信エラーのときだけ 1 回だけ再送する。
///
/// Web 版 `utils/api.ts` と同じ方針:
/// - 対象は **GET / HEAD のみ**（副作用のあるリクエストは再送しない）
/// - 再送は 1 回だけ
/// - タイムアウトと接続エラーのみ（4xx / 5xx は再送しない。5xx を叩き直しても
///   自宅サーバー（HDD）に負荷をかけるだけなので、呼び出し側でハンドリングする）
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this.dio);

  final Dio dio;

  static const _retryableMethods = {'GET', 'HEAD'};

  static const _retryableTypes = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  };

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (!_shouldRetry(err, options)) {
      handler.next(err);
      return;
    }

    try {
      final response = await dio.fetch<dynamic>(
        options..extra = {...options.extra, retriedExtraKey: true},
      );
      handler.resolve(response);
    } on DioException catch (error) {
      handler.next(error);
    }
  }

  static bool _shouldRetry(DioException err, RequestOptions options) {
    if (options.extra[retriedExtraKey] == true) return false;
    if (!_retryableMethods.contains(options.method.toUpperCase())) return false;
    if (_retryableTypes.contains(err.type)) return true;
    // 回線が切れた瞬間の失敗は `unknown` + SocketException として届くことがある。
    return err.type == DioExceptionType.unknown && err.error is SocketException;
  }
}
