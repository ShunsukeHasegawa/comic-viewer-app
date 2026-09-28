// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BookDetail _$BookDetailFromJson(Map<String, dynamic> json) => _BookDetail(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String? ?? '',
  overview: json['overview'] as String?,
  isComplete: json['is_complete'] == null
      ? false
      : boolFromJson(json['is_complete']),
  isFavorite: json['is_favorite'] == null
      ? false
      : boolFromJson(json['is_favorite']),
  authors: json['authors'] == null
      ? const []
      : stringListFromJson(json['authors']),
  publisher: json['publisher'] as String?,
  label: json['label'] as String?,
  tags: json['tags'] == null ? const [] : stringListFromJson(json['tags']),
  categories:
      (json['categories'] as List<dynamic>?)
          ?.map((e) => BookCategory.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  volumes:
      (json['volumes'] as List<dynamic>?)
          ?.map((e) => BookVolume.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  totalArchiveBytes: (json['total_archive_bytes'] as num?)?.toInt() ?? 0,
  readingProgress: json['reading_progress'] == null
      ? null
      : ReadingProgress.fromJson(
          json['reading_progress'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$BookDetailToJson(_BookDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'overview': instance.overview,
      'is_complete': instance.isComplete,
      'is_favorite': instance.isFavorite,
      'authors': instance.authors,
      'publisher': instance.publisher,
      'label': instance.label,
      'tags': instance.tags,
      'categories': instance.categories,
      'volumes': instance.volumes,
      'total_archive_bytes': instance.totalArchiveBytes,
      'reading_progress': instance.readingProgress,
    };

_BookCategory _$BookCategoryFromJson(Map<String, dynamic> json) =>
    _BookCategory(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
    );

Map<String, dynamic> _$BookCategoryToJson(_BookCategory instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

_BookVolume _$BookVolumeFromJson(Map<String, dynamic> json) => _BookVolume(
  id: (json['id'] as num).toInt(),
  volume: (json['volume'] as num?)?.toInt() ?? 0,
  thumbnail: json['thumbnail'] as String?,
  totalPages: (json['total_pages'] as num?)?.toInt(),
  archiveBytes: (json['archive_bytes'] as num?)?.toInt(),
  filesVersion: (json['files_version'] as num?)?.toInt(),
  userStatus: json['user_volume_status'] == null
      ? null
      : VolumeUserStatus.fromJson(
          json['user_volume_status'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$BookVolumeToJson(_BookVolume instance) =>
    <String, dynamic>{
      'id': instance.id,
      'volume': instance.volume,
      'thumbnail': instance.thumbnail,
      'total_pages': instance.totalPages,
      'archive_bytes': instance.archiveBytes,
      'files_version': instance.filesVersion,
      'user_volume_status': instance.userStatus,
    };

_VolumeUserStatus _$VolumeUserStatusFromJson(Map<String, dynamic> json) =>
    _VolumeUserStatus(
      currentPage: (json['current_page'] as num?)?.toInt() ?? 0,
      maxPage: (json['max_page'] as num?)?.toInt() ?? 0,
      isFinished: json['is_finished'] == null
          ? false
          : boolFromJson(json['is_finished']),
    );

Map<String, dynamic> _$VolumeUserStatusToJson(_VolumeUserStatus instance) =>
    <String, dynamic>{
      'current_page': instance.currentPage,
      'max_page': instance.maxPage,
      'is_finished': instance.isFinished,
    };

_ReadingProgress _$ReadingProgressFromJson(Map<String, dynamic> json) =>
    _ReadingProgress(
      readVolumes: (json['read_volumes'] as num?)?.toInt() ?? 0,
      totalVolumes: (json['total_volumes'] as num?)?.toInt() ?? 0,
      currentVolume: (json['current_volume'] as num?)?.toInt(),
      currentPage: (json['current_page'] as num?)?.toInt() ?? 0,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ReadingProgressToJson(_ReadingProgress instance) =>
    <String, dynamic>{
      'read_volumes': instance.readVolumes,
      'total_volumes': instance.totalVolumes,
      'current_volume': instance.currentVolume,
      'current_page': instance.currentPage,
      'total_pages': instance.totalPages,
    };
