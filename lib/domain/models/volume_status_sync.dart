import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/json/json_bool.dart';
import '../../core/json/json_date_time.dart';

part 'volume_status_sync.freezed.dart';
part 'volume_status_sync.g.dart';

/// 一括同期（`POST /api/v2/user-volume-status/bulk`）で送る 1 件。
///
/// `read_at` は**タイムゾーン付き**で送る。サーバーはタイムゾーン無しの値を
/// `Asia/Tokyo` として解釈するため、UTC の文字列をそのまま渡すと 9 時間ずれて
/// 「未来の進捗」として棄却される。
@freezed
abstract class VolumeStatusSyncItem with _$VolumeStatusSyncItem {
  const factory VolumeStatusSyncItem({
    @JsonKey(name: 'volume_id') required int volumeId,
    @JsonKey(name: 'current_page') required int currentPage,
    @JsonKey(name: 'max_page') required int maxPage,
    @JsonKey(name: 'read_at', toJson: _readAtToJson) required DateTime readAt,
  }) = _VolumeStatusSyncItem;

  factory VolumeStatusSyncItem.fromJson(Map<String, dynamic> json) =>
      _$VolumeStatusSyncItemFromJson(json);
}

/// サーバーは秒精度（MySQL の TIMESTAMP）でしか保存しないので、送る側も秒で切る。
///
/// ミリ秒を残すと保存値と一致せず、同じバッチの再送が毎回「新しい」と判定される。
String _readAtToJson(DateTime value) =>
    value.toUtc().copyWith(microsecond: 0, millisecond: 0).toIso8601String();

/// サーバー側の進捗 1 件（採用された値 / 競合時の現在値）。
@freezed
abstract class VolumeStatusSnapshot with _$VolumeStatusSnapshot {
  const factory VolumeStatusSnapshot({
    @JsonKey(name: 'volume_id') required int volumeId,
    @JsonKey(name: 'current_page') @Default(0) int currentPage,
    @JsonKey(name: 'max_page') @Default(0) int maxPage,
    @JsonKey(name: 'is_finished', fromJson: boolFromJson)
    @Default(false)
    bool isFinished,

    /// 端末が申告した読了時刻。`read_at` 列の追加前に作られた行では `null`。
    @JsonKey(
      name: 'read_at',
      fromJson: dateTimeFromJson,
      toJson: dateTimeToJson,
    )
    DateTime? readAt,

    /// サーバーが記録した時刻。`read_at` が無い行の比較に使う。
    @JsonKey(
      name: 'updated_at',
      fromJson: dateTimeFromJson,
      toJson: dateTimeToJson,
    )
    DateTime? updatedAt,
  }) = _VolumeStatusSnapshot;

  const VolumeStatusSnapshot._();

  factory VolumeStatusSnapshot.fromJson(Map<String, dynamic> json) =>
      _$VolumeStatusSnapshotFromJson(json);

  /// ローカルへ書き戻すときの時刻（サーバーの比較基準に合わせる）。
  DateTime? get effectiveReadAt => readAt ?? updatedAt;
}

/// 採用されなかった理由（サーバーの `UserVolumeStatusService` の定数）。
enum VolumeStatusSkipReason {
  /// 巻が存在しない / セーフモードで見えない。再送しても通らない。
  @JsonValue('not_found')
  notFound,

  /// サーバー側の記録の方が新しい。`current` の値でローカルを上書きする。
  @JsonValue('stale')
  stale,

  /// 端末時計が進みすぎていて信用されなかった。次の機会に送り直す。
  @JsonValue('future_read_at')
  futureReadAt,

  /// サーバーが理由を増やした場合（未送信のまま残す）。
  unknown,
}

/// 採用されなかった 1 件。
@freezed
abstract class VolumeStatusSkip with _$VolumeStatusSkip {
  const factory VolumeStatusSkip({
    @JsonKey(name: 'volume_id') required int volumeId,
    @JsonKey(unknownEnumValue: VolumeStatusSkipReason.unknown)
    @Default(VolumeStatusSkipReason.unknown)
    VolumeStatusSkipReason reason,

    /// サーバー側の現在値（`not_found` と、記録が無い場合は `null`）。
    VolumeStatusSnapshot? current,
  }) = _VolumeStatusSkip;

  factory VolumeStatusSkip.fromJson(Map<String, dynamic> json) =>
      _$VolumeStatusSkipFromJson(json);
}

/// 一括同期の応答と、それを返したサーバーの時刻（`Date` ヘッダ）。
///
/// サーバー時刻を一緒に配るのは、端末時計が進みすぎて `future_read_at` で
/// 棄却された行を合わせ直して送り直すため（サーバー側のコメントが指示している
/// 手順）。ヘッダが読めなければ `null`。
typedef VolumeStatusSyncResponse = ({
  VolumeStatusSyncResult result,
  DateTime? serverTime,
});

/// 一括同期の応答。
@freezed
abstract class VolumeStatusSyncResult with _$VolumeStatusSyncResult {
  const factory VolumeStatusSyncResult({
    @Default([]) List<VolumeStatusSnapshot> applied,
    @Default([]) List<VolumeStatusSkip> skipped,
  }) = _VolumeStatusSyncResult;

  factory VolumeStatusSyncResult.fromJson(Map<String, dynamic> json) =>
      _$VolumeStatusSyncResultFromJson(json);
}
