import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// テスト用の [HttpClientAdapter]。リクエストを記録し、任意の応答を返す。
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  /// 常に同じ JSON を返すアダプタ。
  factory FakeHttpAdapter.json(
    Object? body, {
    int statusCode = 200,
    Map<String, List<String>>? headers,
  }) {
    return FakeHttpAdapter(
      (options) async =>
          jsonResponse(body, statusCode: statusCode, headers: headers),
    );
  }

  static ResponseBody jsonResponse(
    Object? body, {
    int statusCode = 200,
    Map<String, List<String>>? headers,
  }) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...?headers,
      },
    );
  }

  final Future<ResponseBody> Function(RequestOptions options) handler;

  /// 実際に届いたリクエスト。
  final requests = <RequestOptions>[];

  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) => closed = true;
}
