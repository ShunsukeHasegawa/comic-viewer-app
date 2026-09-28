import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/models/user.dart';

part 'auth_store.g.dart';

/// 認証情報（Bearer トークンと最後に取得したユーザー）の保管場所。
///
/// ユーザーも保持するのは、圏外起動でトークン検証ができないときに
/// オフライン閲覧（#11）へ進めるようにするため。
abstract interface class AuthStore {
  Future<String?> readToken();

  Future<void> writeToken(String token);

  /// 最後に取得したユーザー。未保存 / 壊れていれば `null`。
  Future<User?> readUser();

  Future<void> writeUser(User user);

  /// トークンとユーザーの両方を破棄する。
  Future<void> clear();
}

/// OS のセキュアストレージ（Android: EncryptedSharedPreferences / iOS: Keychain）。
///
/// リクエストごとに OS を叩かないよう、トークンはメモリにも保持する。
class SecureAuthStore implements AuthStore {
  SecureAuthStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // 既定で AES-GCM + RSA 鍵ラップ（EncryptedSharedPreferences は 11.x で廃止）。
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              // 端末のロック解除後のみ読め、iCloud キーチェーンにも同期しない
              // （トークンを他端末へ持ち出させない / #15）。
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  final FlutterSecureStorage _storage;

  String? _cachedToken;
  bool _tokenLoaded = false;

  @override
  Future<String?> readToken() async {
    if (_tokenLoaded) return _cachedToken;
    _cachedToken = await _storage.read(key: _tokenKey);
    _tokenLoaded = true;
    return _cachedToken;
  }

  @override
  Future<void> writeToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    _cachedToken = token;
    _tokenLoaded = true;
  }

  @override
  Future<User?> readUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return User.fromJson(decoded);
    } on Object {
      // 形式が変わった / 壊れている場合は「無い」とみなす（起動を妨げない）。
      return null;
    }
  }

  @override
  Future<void> writeUser(User user) =>
      _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  @override
  Future<void> clear() async {
    // 先にメモリを消す。OS 側の削除が失敗しても、以降のリクエストに
    // 古いトークンを付けてしまわないようにするため。
    _cachedToken = null;
    _tokenLoaded = true;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}

@Riverpod(keepAlive: true)
AuthStore authStore(Ref ref) => SecureAuthStore();
