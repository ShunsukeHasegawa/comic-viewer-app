import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/json/json_bool.dart';
import '../../core/json/json_date_time.dart';

part 'reading_book.freezed.dart';
part 'reading_book.g.dart';

/// 「続きを読む」カルーセルの 1 件（`GET /api/v2/user/reading`。`data` でラップされる）。
@freezed
abstract class ReadingBook with _$ReadingBook {
  const factory ReadingBook({
    @JsonKey(name: 'book_id') required int bookId,
    @Default('') String title,

    /// `?m=` 付きの相対 URL。`null` はサムネイル無し。
    String? thumbnail,
    @JsonKey(name: 'volume_number') @Default(0) int volumeNumber,
    @JsonKey(name: 'volume_id') required int volumeId,
    @JsonKey(name: 'current_page') @Default(0) int currentPage,
    @JsonKey(name: 'max_page') @Default(0) int maxPage,

    /// サーバーが計算した進捗率（0-100）。
    @JsonKey(name: 'progress_percent') @Default(0) int progressPercent,
  }) = _ReadingBook;

  factory ReadingBook.fromJson(Map<String, dynamic> json) =>
      _$ReadingBookFromJson(json);
}

/// 読書履歴の 1 件（`GET /api/user-volume-status/history?page=`）。
@freezed
abstract class HistoryEntry with _$HistoryEntry {
  const factory HistoryEntry({
    /// 巻 ID。
    required int id,
    @JsonKey(name: 'book_id') required int bookId,
    @Default('') String title,
    @Default(0) int volume,
    String? thumbnail,
    @JsonKey(name: 'current_page') @Default(0) int currentPage,
    @JsonKey(name: 'max_page') @Default(0) int maxPage,
    @JsonKey(name: 'is_finished', fromJson: boolFromJson)
    @Default(false)
    bool isFinished,
    @JsonKey(
      name: 'updated_at',
      fromJson: dateTimeFromJson,
      toJson: dateTimeToJson,
    )
    DateTime? updatedAt,
  }) = _HistoryEntry;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$HistoryEntryFromJson(json);
}

/// 読書統計（`GET /api/v2/user/stats`）。
@freezed
abstract class UserStats with _$UserStats {
  const factory UserStats({
    @JsonKey(name: 'titles_completed') @Default(0) int titlesCompleted,
    @JsonKey(name: 'volumes_completed') @Default(0) int volumesCompleted,

    /// 直近 12 か月の読了数（古い月から順）。
    @Default([]) List<MonthlyReadCount> monthly,
  }) = _UserStats;

  factory UserStats.fromJson(Map<String, dynamic> json) =>
      _$UserStatsFromJson(json);
}

/// 月別の読了数。
@freezed
abstract class MonthlyReadCount with _$MonthlyReadCount {
  const factory MonthlyReadCount({
    /// `YYYY-MM`。
    @Default('') String month,
    @Default(0) int count,
  }) = _MonthlyReadCount;

  factory MonthlyReadCount.fromJson(Map<String, dynamic> json) =>
      _$MonthlyReadCountFromJson(json);
}

/// カテゴリ / タグ（`GET /api/category` / `GET /api/tag`）。
///
/// サーバーはモデルをそのまま返すので他のカラムも来るが、アプリは ID と名前だけ使う。
@freezed
abstract class Taxonomy with _$Taxonomy {
  const factory Taxonomy({required int id, @Default('') String name}) =
      _Taxonomy;

  factory Taxonomy.fromJson(Map<String, dynamic> json) =>
      _$TaxonomyFromJson(json);
}
