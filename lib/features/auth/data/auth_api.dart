import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/api/api_client.dart';
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
  const AuthApi(this._client);

  static const tokenPath = 'api/auth/token';
  static const userPath = 'api/user';

  final ApiClient _client;

  /// `POST /api/auth/token`。
  ///
  /// 応答は `{token, user, expires_at}`（201）。`expires_at` は現状使わない
  /// （失効は 401 を受けてから扱う）。
  Future<AuthTokenResult> createToken({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final Map<String, dynamic> json;
    try {
      final response = await _client.send(
        tokenPath,
        method: 'POST',
        data: {'email': email, 'password': password, 'device_name': deviceName},
        // 失効したトークンを付けたまま再ログインできるようにする。
        skipAuth: true,
      );
      json = ApiClient.asObject(response.data, tokenPath);
    } on UnauthorizedException {
      // ログイン時の 401 は「セッション失効」ではなく「認証情報が違う」。
      throw const InvalidCredentialsException();
    } on ValidationException {
      throw const InvalidCredentialsException();
    }

    final token = json['token'];
    if (token is! String || token.isEmpty) {
      throw const UnexpectedResponseException(
        message: 'ログインに失敗しました。もう一度お試しください。',
        detail: 'api/auth/token: token が無い応答',
      );
    }
    final userJson = json['user'];
    return AuthTokenResult(
      token: token,
      user: userJson is Map<String, dynamic> ? _parseUser(userJson) : null,
    );
  }

  /// `GET /api/user`。保存済みトークンの検証にも使う。
  Future<User> fetchCurrentUser() async {
    final json = await _client.getObject(userPath);
    return _parseUser(json);
  }

  /// `DELETE /api/auth/token`。
  Future<void> deleteToken() async {
    await _client.send(tokenPath, method: 'DELETE');
  }

  static User _parseUser(Map<String, dynamic> json) =>
      ApiClient.parse(json, User.fromJson, path: userPath);
}

@Riverpod(keepAlive: true)
AuthApi authApi(Ref ref) => AuthApi(ref.watch(apiClientProvider));
