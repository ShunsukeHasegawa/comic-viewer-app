// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'volume_status_sync.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VolumeStatusSyncItem _$VolumeStatusSyncItemFromJson(
  Map<String, dynamic> json,
) => _VolumeStatusSyncItem(
  volumeId: (json['volume_id'] as num).toInt(),
  currentPage: (json['current_page'] as num).toInt(),
  maxPage: (json['max_page'] as num).toInt(),
  readAt: DateTime.parse(json['read_at'] as String),
);

Map<String, dynamic> _$VolumeStatusSyncItemToJson(
  _VolumeStatusSyncItem instance,
) => <String, dynamic>{
  'volume_id': instance.volumeId,
  'current_page': instance.currentPage,
  'max_page': instance.maxPage,
  'read_at': _readAtToJson(instance.readAt),
};

_VolumeStatusSnapshot _$VolumeStatusSnapshotFromJson(
  Map<String, dynamic> json,
) => _VolumeStatusSnapshot(
  volumeId: (json['volume_id'] as num).toInt(),
  currentPage: (json['current_page'] as num?)?.toInt() ?? 0,
  maxPage: (json['max_page'] as num?)?.toInt() ?? 0,
  isFinished: json['is_finished'] == null
      ? false
      : boolFromJson(json['is_finished']),
  readAt: dateTimeFromJson(json['read_at']),
  updatedAt: dateTimeFromJson(json['updated_at']),
);

Map<String, dynamic> _$VolumeStatusSnapshotToJson(
  _VolumeStatusSnapshot instance,
) => <String, dynamic>{
  'volume_id': instance.volumeId,
  'current_page': instance.currentPage,
  'max_page': instance.maxPage,
  'is_finished': instance.isFinished,
  'read_at': dateTimeToJson(instance.readAt),
  'updated_at': dateTimeToJson(instance.updatedAt),
};

_VolumeStatusSkip _$VolumeStatusSkipFromJson(Map<String, dynamic> json) =>
    _VolumeStatusSkip(
      volumeId: (json['volume_id'] as num).toInt(),
      reason:
          $enumDecodeNullable(
            _$VolumeStatusSkipReasonEnumMap,
            json['reason'],
            unknownValue: VolumeStatusSkipReason.unknown,
          ) ??
          VolumeStatusSkipReason.unknown,
      current: json['current'] == null
          ? null
          : VolumeStatusSnapshot.fromJson(
              json['current'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$VolumeStatusSkipToJson(_VolumeStatusSkip instance) =>
    <String, dynamic>{
      'volume_id': instance.volumeId,
      'reason': _$VolumeStatusSkipReasonEnumMap[instance.reason]!,
      'current': instance.current,
    };

const _$VolumeStatusSkipReasonEnumMap = {
  VolumeStatusSkipReason.notFound: 'not_found',
  VolumeStatusSkipReason.stale: 'stale',
  VolumeStatusSkipReason.futureReadAt: 'future_read_at',
  VolumeStatusSkipReason.unknown: 'unknown',
};

_VolumeStatusSyncResult _$VolumeStatusSyncResultFromJson(
  Map<String, dynamic> json,
) => _VolumeStatusSyncResult(
  applied:
      (json['applied'] as List<dynamic>?)
          ?.map((e) => VolumeStatusSnapshot.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  skipped:
      (json['skipped'] as List<dynamic>?)
          ?.map((e) => VolumeStatusSkip.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$VolumeStatusSyncResultToJson(
  _VolumeStatusSyncResult instance,
) => <String, dynamic>{
  'applied': instance.applied,
  'skipped': instance.skipped,
};
