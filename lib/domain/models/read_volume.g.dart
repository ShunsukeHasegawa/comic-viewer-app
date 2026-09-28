// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'read_volume.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReadVolume _$ReadVolumeFromJson(Map<String, dynamic> json) => _ReadVolume(
  id: (json['id'] as num).toInt(),
  volume: (json['volume'] as num?)?.toInt() ?? 0,
  currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
  nextVolumeId: (json['next_volume_id'] as num?)?.toInt(),
  nextVolumeThumbnail: json['next_volume_thumbnail'] as String?,
  files: json['files'] == null ? const [] : intListFromJson(json['files']),
  filesVersion: (json['files_version'] as num?)?.toInt(),
  book: Book.fromJson(json['book'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ReadVolumeToJson(_ReadVolume instance) =>
    <String, dynamic>{
      'id': instance.id,
      'volume': instance.volume,
      'current_page': instance.currentPage,
      'next_volume_id': instance.nextVolumeId,
      'next_volume_thumbnail': instance.nextVolumeThumbnail,
      'files': instance.files,
      'files_version': instance.filesVersion,
      'book': instance.book,
    };
