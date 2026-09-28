// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReadingBook _$ReadingBookFromJson(Map<String, dynamic> json) => _ReadingBook(
  bookId: (json['book_id'] as num).toInt(),
  title: json['title'] as String? ?? '',
  thumbnail: json['thumbnail'] as String?,
  volumeNumber: (json['volume_number'] as num?)?.toInt() ?? 0,
  volumeId: (json['volume_id'] as num).toInt(),
  currentPage: (json['current_page'] as num?)?.toInt() ?? 0,
  maxPage: (json['max_page'] as num?)?.toInt() ?? 0,
  progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ReadingBookToJson(_ReadingBook instance) =>
    <String, dynamic>{
      'book_id': instance.bookId,
      'title': instance.title,
      'thumbnail': instance.thumbnail,
      'volume_number': instance.volumeNumber,
      'volume_id': instance.volumeId,
      'current_page': instance.currentPage,
      'max_page': instance.maxPage,
      'progress_percent': instance.progressPercent,
    };

_HistoryEntry _$HistoryEntryFromJson(Map<String, dynamic> json) =>
    _HistoryEntry(
      id: (json['id'] as num).toInt(),
      bookId: (json['book_id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      thumbnail: json['thumbnail'] as String?,
      currentPage: (json['current_page'] as num?)?.toInt() ?? 0,
      maxPage: (json['max_page'] as num?)?.toInt() ?? 0,
      isFinished: json['is_finished'] == null
          ? false
          : boolFromJson(json['is_finished']),
      updatedAt: dateTimeFromJson(json['updated_at']),
    );

Map<String, dynamic> _$HistoryEntryToJson(_HistoryEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'book_id': instance.bookId,
      'title': instance.title,
      'volume': instance.volume,
      'thumbnail': instance.thumbnail,
      'current_page': instance.currentPage,
      'max_page': instance.maxPage,
      'is_finished': instance.isFinished,
      'updated_at': dateTimeToJson(instance.updatedAt),
    };

_UserStats _$UserStatsFromJson(Map<String, dynamic> json) => _UserStats(
  titlesCompleted: (json['titles_completed'] as num?)?.toInt() ?? 0,
  volumesCompleted: (json['volumes_completed'] as num?)?.toInt() ?? 0,
  monthly:
      (json['monthly'] as List<dynamic>?)
          ?.map((e) => MonthlyReadCount.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$UserStatsToJson(_UserStats instance) =>
    <String, dynamic>{
      'titles_completed': instance.titlesCompleted,
      'volumes_completed': instance.volumesCompleted,
      'monthly': instance.monthly,
    };

_MonthlyReadCount _$MonthlyReadCountFromJson(Map<String, dynamic> json) =>
    _MonthlyReadCount(
      month: json['month'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MonthlyReadCountToJson(_MonthlyReadCount instance) =>
    <String, dynamic>{'month': instance.month, 'count': instance.count};

_Taxonomy _$TaxonomyFromJson(Map<String, dynamic> json) => _Taxonomy(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String? ?? '',
);

Map<String, dynamic> _$TaxonomyToJson(_Taxonomy instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
};
