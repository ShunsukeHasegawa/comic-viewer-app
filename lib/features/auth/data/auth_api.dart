import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/dio_provider.dart';
import '../../../domain/models/user.dart';

part 'auth_api.g.dart';

/// トークン発行の結果。
class AuthTokenResult {
  const AuthTokenResult({required this.token, this.user});

  final String token;

  /// サーバーがトークンと一緒にユーザーを返した場合のみ入る。
  final User? user;
}

/// 認証エンドポイント（サーバー側: comic-viewer#6）。
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// `POST /api/auth/token`。
  Future<AuthTokenResult> createToken({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        'api/auth/token',
        data: {'email': email, 'password': password, 'device_name': deviceName},
        options: Options(
          headers: jsonAcceptHeaders,
          // 失効したトークンを付けたまま再ログインできるようにする。
          extra: const {skipAuthExtraKey: true},
        ),
      );
    } on DioException catch (error) {
      final mapped = ApiException.from(error);
      // ログイン時の 401 / 422 は「セッション失効」ではなく「認証情報が違う」。
      if (mapped is UnauthorizedException || mapped is ValidationException) {
        throw const InvalidCredentialsException();
      }
      throw mapped;
    }

    final data = response.data;
    final token = data?['token'];
    if (token is! String || token.isEmpty) {
      throw const UnexpectedResponseException('サーバーからトークンを取得できませんでした。');
    }
    final userJson = data?['user'];
    return AuthTokenResult(
      token: token,
      user: userJson is Map<String, dynamic> ? _parseUser(userJson) : null,
    );
  }

  /// `GET /api/user`。保存済みトークンの検証にも使う。
  Future<User> fetchCurrentUser() async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.get<Map<String, dynamic>>(
        'api/user',
        options: Options(headers: jsonAcceptHeaders),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    }

    final data = response.data;
    if (data == null) {
      throw const UnexpectedResponseException('ユーザー情報を取得できませんでした。');
    }
    return _parseUser(data);
  }

  /// `DELETE /api/auth/token`。
  Future<void> deleteToken() async {
    try {
      await _dio.delete<void>(
        'api/auth/token',
        options: Options(headers: jsonAcceptHeaders),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }

  static User _parseUser(Map<String, dynamic> json) {
    try {
      return User.fromJson(json);
    } on Object catch (error) {
      throw UnexpectedResponseException('ユーザー情報を解釈できませんでした: $error');
    }
  }
}

@Riverpod(keepAlive: true)
AuthApi authApi(Ref ref) => AuthApi(ref.watch(dioProvider));
