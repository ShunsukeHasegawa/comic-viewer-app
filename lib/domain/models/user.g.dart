// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String? ?? '',
  email: json['email'] as String?,
  isAdmin: json['is_admin'] == null ? false : boolFromJson(json['is_admin']),
  safeMode: json['safe_mode'] == null ? false : boolFromJson(json['safe_mode']),
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'is_admin': instance.isAdmin,
  'safe_mode': instance.safeMode,
};
