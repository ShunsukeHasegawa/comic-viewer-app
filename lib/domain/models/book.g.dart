// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Book _$BookFromJson(Map<String, dynamic> json) => _Book(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String? ?? '',
  kana: json['kana'] as String?,
  thumbnail: json['thumbnail'] as String?,
  isComplete: json['is_complete'] == null
      ? false
      : boolFromJson(json['is_complete']),
  isUnsafe: json['is_unsafe'] == null ? false : boolFromJson(json['is_unsafe']),
  volumeAddedAt: dateTimeFromJson(json['volume_added_at']),
  latestVolume: (json['latest_volume'] as num?)?.toInt(),
  author: json['author'] == null
      ? const []
      : stringListFromJson(json['author']),
  tags: json['tags'] == null ? const [] : intListFromJson(json['tags']),
  categories: json['categories'] == null
      ? const []
      : intListFromJson(json['categories']),
);

Map<String, dynamic> _$BookToJson(_Book instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'kana': instance.kana,
  'thumbnail': instance.thumbnail,
  'is_complete': instance.isComplete,
  'is_unsafe': instance.isUnsafe,
  'volume_added_at': dateTimeToJson(instance.volumeAddedAt),
  'latest_volume': instance.latestVolume,
  'author': instance.author,
  'tags': instance.tags,
  'categories': instance.categories,
};

_UserStatus _$UserStatusFromJson(Map<String, dynamic> json) => _UserStatus(
  unreads: json['unreads'] == null
      ? const []
      : intListFromJson(json['unreads']),
  favorites: json['favorites'] == null
      ? const []
      : intListFromJson(json['favorites']),
);

Map<String, dynamic> _$UserStatusToJson(_UserStatus instance) =>
    <String, dynamic>{
      'unreads': instance.unreads,
      'favorites': instance.favorites,
    };
