import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/app_database.dart';

part 'push_settings_store.g.dart';

/// サーバーへ登録したトークンの控え（#14）。
///
/// 同じトークンを毎回 POST しないために持つ（サーバーは `last_used_at` を
/// 更新するだけなので、1 日 1 回で足りる）。ユーザーを含めるのは、別の
/// ユーザーでログインし直したときに「登録済み」と取り違えないため
/// （持ち主を移す POST が要る）。
@immutable
class PushRegistration {
  const PushRegistration({
    required this.userId,
    required this.token,
    required this.registeredAt,
  });

  final int userId;
  final String token;
  final DateTime registeredAt;

  Map<String, Object> toJson() => {
    'user_id': userId,
    'token': token,
    'registered_at': registeredAt.toUtc().toIso8601String(),
  };

  /// 読めなければ `null`（控えが無いのと同じ = 登録し直すだけ）。
  static PushRegistration? tryParse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final userId = json['user_id'];
      final token = json['token'];
      final at = json['registered_at'];
      if (userId is! int || token is! String || at is! String) return null;
      final registeredAt = DateTime.tryParse(at);
      if (registeredAt == null) return null;
      return PushRegistration(
        userId: userId,
        token: token,
        registeredAt: registeredAt,
      );
    } on FormatException {
      return null;
    }
  }
}

/// プッシュ通知の端末内の設定と控え。
abstract interface class PushSettingsStore {
  /// 「新刊通知」の設定。未保存は ON（既定）。
  ///
  /// 端末の好みでユーザー固有のデータではないので、ログアウトしても残す。
  Future<bool> readEnabled();

  Future<void> writeEnabled(bool enabled);

  Future<PushRegistration?> readRegistration();

  Future<void> writeRegistration(PushRegistration registration);

  Future<void> clearRegistration();

  /// この端末の FCM トークンを捨てる予約が残っているか。
  ///
  /// ログアウト / 失効 / OFF のときに立て、`deleteToken` が通ったら下ろす。
  /// 圏外で消せなかったトークンを次の起動で消し直すため（消さないと前の
  /// ユーザーの通知がこの端末に届き続ける）。
  Future<bool> readTokenDeletionPending();

  Future<void> writeTokenDeletionPending(bool pending);
}

/// drift の Settings に置く実装。
class DriftPushSettingsStore implements PushSettingsStore {
  DriftPushSettingsStore(this._database);

  static const enabledKey = 'push.enabled';
  static const registrationKey = 'push.registration';
  static const deletionPendingKey = 'push.token_deletion_pending';

  final AppDatabase _database;

  @override
  Future<bool> readEnabled() async => await _read(enabledKey) != 'false';

  @override
  Future<void> writeEnabled(bool enabled) => _write(enabledKey, '$enabled');

  @override
  Future<PushRegistration?> readRegistration() async {
    final raw = await _read(registrationKey);
    return raw == null ? null : PushRegistration.tryParse(raw);
  }

  @override
  Future<void> writeRegistration(PushRegistration registration) =>
      _write(registrationKey, jsonEncode(registration.toJson()));

  @override
  Future<void> clearRegistration() => _delete(registrationKey);

  @override
  Future<bool> readTokenDeletionPending() async =>
      await _read(deletionPendingKey) == 'true';

  @override
  Future<void> writeTokenDeletionPending(bool pending) => pending
      ? _write(deletionPendingKey, 'true')
      : _delete(deletionPendingKey);

  Future<String?> _read(String key) async {
    final row = await (_database.select(
      _database.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _write(String key, String value) => _database
      .into(_database.settings)
      .insertOnConflictUpdate(SettingRow(key: key, value: value));

  Future<void> _delete(String key) async {
    await (_database.delete(
      _database.settings,
    )..where((t) => t.key.equals(key))).go();
  }
}

@Riverpod(keepAlive: true)
PushSettingsStore pushSettingsStore(Ref ref) =>
    DriftPushSettingsStore(ref.watch(appDatabaseProvider));
