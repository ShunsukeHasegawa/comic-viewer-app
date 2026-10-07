// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archive_url.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ArchiveUrl _$ArchiveUrlFromJson(Map<String, dynamic> json) => _ArchiveUrl(
  url: json['url'] as String,
  expiresAt: json['expires_at'] == null
      ? null
      : DateTime.parse(json['expires_at'] as String),
  filesVersion: (json['files_version'] as num).toInt(),
);

Map<String, dynamic> _$ArchiveUrlToJson(_ArchiveUrl instance) =>
    <String, dynamic>{
      'url': instance.url,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'files_version': instance.filesVersion,
    };
