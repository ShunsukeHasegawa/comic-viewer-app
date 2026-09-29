import 'dart:io';

import 'package:dio/dio.dart';

/// API 呼び出しの失敗を種別ごとに表す。
///
/// 「通信できなかった」と「サーバーが 404 を返した」を呼び出し側で区別できることが重要。
/// 例えば Web 版の `bookReadVolume` は、通信エラーでは手元の進捗を捨てず、
/// 404（削除済みの巻）のときだけ捨てている。
sealed class ApiException implements Exception {
  const ApiException(this.message);

  /// [DioException] などを種別つきの例外に変換する。
  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) {
      return UnexpectedResponseException(detail: '$error');
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiTimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badCertificate:
        return const NetworkException('サーバーの証明書を検証できませんでした。');
      case DioExceptionType.cancel:
        return const RequestCancelledException();
      case DioExceptionType.badResponse:
        return _fromStatusCode(error.response?.statusCode, error.response);
      case DioExceptionType.unknown:
        if (error.error is SocketException) return const NetworkException();
        return UnexpectedResponseException(detail: '${error.message ?? error}');
    }
  }

  static ApiException _fromStatusCode(
    int? statusCode,
    Response<dynamic>? response,
  ) {
    return switch (statusCode) {
      401 => const UnauthorizedException(),
      403 => const ForbiddenException(),
      404 => const NotFoundException(),
      422 => ValidationException(errors: _validationErrors(response)),
      429 => TooManyRequestsException(retryAfter: _retryAfter(response)),
      final int code when code >= 500 => ServerException(statusCode: code),
      final int code => UnexpectedResponseException(
        detail: 'HTTP $code',
        statusCode: code,
      ),
      null => const UnexpectedResponseException(),
    };
  }

  static Map<String, List<String>> _validationErrors(
    Response<dynamic>? response,
  ) {
    final data = response?.data;
    if (data is! Map) return const {};
    final errors = data['errors'];
    if (errors is! Map) return const {};
    return {
      for (final entry in errors.entries)
        entry.key.toString(): switch (entry.value) {
          final List<dynamic> messages =>
            messages.map((m) => m.toString()).toList(),
          final Object value => [value.toString()],
          null => const <String>[],
        },
    };
  }

  static Duration? _retryAfter(Response<dynamic>? response) {
    final raw = response?.headers.value('retry-after');
    final seconds = raw == null ? null : int.tryParse(raw.trim());
    return seconds == null ? null : Duration(seconds: seconds);
  }

  /// ユーザーに見せられる日本語メッセージ。
  final String message;

  /// 通信環境やサーバーの一時的な問題か。
  ///
  /// `true` なら「手元にある内容で代替してよい」（圏外表示 / オフライン再生）。
  /// 認証エラーや 404 をここに含めてはいけない。ログイン画面へ戻す / 削除済みと
  /// 分かっている状況で古い内容を見せ続けることになる。
  bool get isTransient => switch (this) {
    NetworkException() => true,
    ApiTimeoutException() => true,
    ServerException() => true,
    TooManyRequestsException() => true,
    _ => false,
  };

  @override
  String toString() => '$runtimeType: $message';
}

/// 通信できなかった（オフライン・接続失敗）。
final class NetworkException extends ApiException {
  const NetworkException([super.message = 'ネットワークに接続できませんでした。']);
}

/// タイムアウト。
final class ApiTimeoutException extends ApiException {
  const ApiTimeoutException([super.message = '通信がタイムアウトしました。']);
}

/// 401。トークンが無効 / 失効している。
final class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'ログインの有効期限が切れました。']);
}

/// 403。認証はできているが権限が無い（セーフモードなど）。
final class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'この操作は許可されていません。']);
}

/// 404。リソースが存在しない（削除済みの巻など）。
final class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'お探しのデータは見つかりませんでした。']);
}

/// 429。レート制限。
final class TooManyRequestsException extends ApiException {
  const TooManyRequestsException({
    this.retryAfter,
    String message = 'アクセスが集中しています。しばらく待ってからお試しください。',
  }) : super(message);

  /// `Retry-After` ヘッダの値。
  final Duration? retryAfter;
}

/// 5xx。
final class ServerException extends ApiException {
  const ServerException({
    required this.statusCode,
    String message = 'サーバーでエラーが発生しました。',
  }) : super(message);

  final int statusCode;
}

/// リクエストがキャンセルされた。
final class RequestCancelledException extends ApiException {
  const RequestCancelledException([super.message = 'リクエストはキャンセルされました。']);
}

/// 想定外の応答 / パース失敗。
///
/// [message] はそのまま画面に出せる文言にとどめ、原因（エンドポイントやパーサの
/// 詳細）は [detail] に入れる。ユーザーに内部事情を見せないため。
final class UnexpectedResponseException extends ApiException {
  const UnexpectedResponseException({
    String message = 'サーバーから予期しない応答が返りました。',
    this.detail,
    this.statusCode,
  }) : super(message);

  /// ログ / デバッグ用の詳細（エンドポイントやパースエラーの内容）。
  final String? detail;

  final int? statusCode;

  @override
  String toString() =>
      'UnexpectedResponseException: $message${detail == null ? '' : ' ($detail)'}';
}

/// 422。入力値の検証エラー（Laravel の `errors`）。
final class ValidationException extends ApiException {
  const ValidationException({
    this.errors = const {},
    String message = '入力内容を確認してください。',
  }) : super(message);

  /// フィールド名 → エラーメッセージ。
  final Map<String, List<String>> errors;
}

/// ログイン時にメールアドレス / パスワードが正しくない。
///
/// セッション失効（[UnauthorizedException]）とは意味が違うため型で分ける。
final class InvalidCredentialsException extends ApiException {
  const InvalidCredentialsException([
    super.message = 'メールアドレスまたはパスワードが正しくありません。',
  ]);
}
