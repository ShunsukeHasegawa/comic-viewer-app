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

  /// 最後に取得したユーザー。未保存なら `null`。
  ///
  /// 保存はされているが読み解けない（アプリの更新で形式が変わった / 壊れている）
  /// ときは [StoredUserUnreadableException] を投げる。「無い」と区別しないと、
  /// ログイン時に前のユーザーが居なかったことになり、前のユーザーのデータを
  /// 次のユーザーに見せてしまう（#15）。
  Future<User?> readUser();

  Future<void> writeUser(User user);

  /// トークンとユーザーの両方を破棄する。
  Future<void> clear();
}

/// 保存済みのユーザーを読み解けない（[AuthStore.readUser]）。
///
/// セキュアストレージ自体の障害（`PlatformException`）とは別の型にする。
/// 起動時は同じユーザーのトークンの検証で持ち主が分かるので上書きしてよいが、
/// ストレージの障害はロック解除前の一時的なものがあり扱いが違うため。
class StoredUserUnreadableException implements Exception {
  const StoredUserUnreadableException(this.cause);

  final Object cause;

  @override
  String toString() => 'StoredUserUnreadableException: $cause';
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
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw StoredUserUnreadableException(error);
    }
    if (decoded is! Map<String, dynamic>) {
      throw StoredUserUnreadableException('not an object');
    }
    try {
      return User.fromJson(decoded);
    } on Object catch (error) {
      // 必須項目が増えた / 型が変わった。起動側は「無い」と同じに扱い、
      // ログイン側は「持ち主不明」として扱う（AuthController）。
      throw StoredUserUnreadableException(error);
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
