import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/auth_interceptor.dart';
import '../../core/network/dio_provider.dart';

part 'api_client.g.dart';

/// JSON API を叩くための薄いラッパ。
///
/// - `Accept: application/json` の付与
/// - [DioException] から [ApiException] への変換（種別が呼び出し側で判定できる）
/// - 条件付き GET（304 を成功として扱う）
///
/// を 1 箇所に集約する。
class ApiClient {
  const ApiClient(this.dio);

  final Dio dio;

  /// 生の応答を返す（ステータスコードやヘッダを見たい場合）。
  Future<Response<dynamic>> send(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String> headers = const {},
    bool allowNotModified = false,
    bool skipAuth = false,
    ResponseType responseType = ResponseType.json,
  }) async {
    try {
      return await dio.request<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          responseType: responseType,
          headers: {...jsonAcceptHeaders, ...headers},
          extra: skipAuth ? const {skipAuthExtraKey: true} : null,
          validateStatus: allowNotModified ? _acceptNotModified : null,
        ),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }

  /// オブジェクトを返すエンドポイント。
  Future<Map<String, dynamic>> getObject(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String> headers = const {},
  }) async {
    final response = await send(
      path,
      queryParameters: queryParameters,
      headers: headers,
    );
    return asObject(response.data, path);
  }

  /// 配列を返すエンドポイント（`data` ラップ無し）。
  Future<List<Map<String, dynamic>>> getObjectList(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String> headers = const {},
  }) async {
    final response = await send(
      path,
      queryParameters: queryParameters,
      headers: headers,
    );
    return asObjectList(response.data, path);
  }

  /// 応答をオブジェクトとして解釈する。
  static Map<String, dynamic> asObject(Object? data, String path) {
    final decoded = _decodeIfString(data);
    if (decoded is Map<String, dynamic>) return decoded;
    throw UnexpectedResponseException(detail: '$path: オブジェクトではない応答');
  }

  /// 応答をオブジェクトの配列として解釈する。
  static List<Map<String, dynamic>> asObjectList(Object? data, String path) {
    final decoded = _decodeIfString(data);
    if (decoded is! List) {
      throw UnexpectedResponseException(detail: '$path: 配列ではない応答');
    }
    return [
      for (final element in decoded)
        if (element is Map<String, dynamic>)
          element
        else
          throw UnexpectedResponseException(detail: '$path: 配列要素がオブジェクトではない'),
    ];
  }

  /// モデルへの変換を [ApiException] の枠内に閉じ込める。
  ///
  /// 生成された `fromJson` は必須フィールドをハードキャストするため、
  /// サーバーが `null` を返すと素の [TypeError] が飛ぶ。呼び出し側は
  /// 例外の種別（404 / 通信エラー / 想定外）で分岐するので、ここで型を揃える。
  static T parse<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) fromJson, {
    required String path,
  }) {
    try {
      return fromJson(json);
    } on ApiException {
      rethrow;
    } on Object catch (error) {
      throw UnexpectedResponseException(detail: '$path: $error');
    }
  }

  /// [parse] のリスト版。
  static List<T> parseList<T>(
    List<Map<String, dynamic>> jsonList,
    T Function(Map<String, dynamic> json) fromJson, {
    required String path,
  }) => [for (final json in jsonList) parse(json, fromJson, path: path)];

  /// `Content-Type` が JSON でない場合（静的ファイル配信など）に備えて文字列も解釈する。
  static Object? _decodeIfString(Object? data) {
    if (data is! String) return data;
    final raw = data.trim();
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException catch (error) {
      throw UnexpectedResponseException(
        detail: 'JSON として解釈できない応答: ${error.message}',
      );
    }
  }

  static bool _acceptNotModified(int? status) =>
      status == 304 || (status != null && status >= 200 && status < 300);
}

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) => ApiClient(ref.watch(dioProvider));
