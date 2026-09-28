import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/json/json_bool.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// ログイン中のユーザー。`GET /api/user` の応答。
///
/// [safeMode] はクライアントの表示制御用のヒントに過ぎない。
/// **セーフモードの実際の制御はサーバー側が正**で、対象の巻はそもそも配信されない。
@freezed
abstract class User with _$User {
  const factory User({
    required int id,
    @Default('') String name,
    String? email,
    @JsonKey(name: 'is_admin', fromJson: boolFromJson)
    @Default(false)
    bool isAdmin,
    @JsonKey(name: 'safe_mode', fromJson: boolFromJson)
    @Default(false)
    bool safeMode,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
