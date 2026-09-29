// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'volume_manifest.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VolumeManifest _$VolumeManifestFromJson(Map<String, dynamic> json) =>
    _VolumeManifest(
      id: (json['id'] as num).toInt(),
      bookId: (json['book_id'] as num?)?.toInt() ?? 0,
      filesVersion: (json['files_version'] as num?)?.toInt() ?? 0,
      archiveBytes: (json['archive_bytes'] as num?)?.toInt() ?? 0,
      archiveEtag: json['archive_etag'] as String?,
      pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
      pages:
          (json['pages'] as List<dynamic>?)
              ?.map(
                (e) => VolumeManifestPage.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$VolumeManifestToJson(_VolumeManifest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'book_id': instance.bookId,
      'files_version': instance.filesVersion,
      'archive_bytes': instance.archiveBytes,
      'archive_etag': instance.archiveEtag,
      'page_count': instance.pageCount,
      'pages': instance.pages,
    };

_VolumeManifestPage _$VolumeManifestPageFromJson(Map<String, dynamic> json) =>
    _VolumeManifestPage(
      index: (json['index'] as num?)?.toInt() ?? 0,
      extension: json['extension'] as String? ?? 'jpg',
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$VolumeManifestPageToJson(_VolumeManifestPage instance) =>
    <String, dynamic>{
      'index': instance.index,
      'extension': instance.extension,
      'bytes': instance.bytes,
    };
