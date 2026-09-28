import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/json/json_bool.dart';
import '../../core/json/json_list.dart';

part 'book_detail.freezed.dart';
part 'book_detail.g.dart';

/// タイトル詳細（`GET /api/v2/books/{bookId}`）。
///
/// 一覧の [Book] と違い、`authors`（複数形）・タグは**名前**で返る。
@freezed
abstract class BookDetail with _$BookDetail {
  const factory BookDetail({
    required int id,
    @Default('') String title,

    /// あらすじ。
    String? overview,
    @JsonKey(name: 'is_complete', fromJson: boolFromJson)
    @Default(false)
    bool isComplete,
    @JsonKey(name: 'is_favorite', fromJson: boolFromJson)
    @Default(false)
    bool isFavorite,
    @JsonKey(fromJson: stringListFromJson) @Default([]) List<String> authors,
    String? publisher,
    String? label,
    @JsonKey(fromJson: stringListFromJson) @Default([]) List<String> tags,
    @Default([]) List<BookCategory> categories,
    @Default([]) List<BookVolume> volumes,

    /// 全巻ダウンロード時の合計バイト数（ZIP が無い巻は 0 として合算）。
    @JsonKey(name: 'total_archive_bytes') @Default(0) int totalArchiveBytes,
    @JsonKey(name: 'reading_progress') ReadingProgress? readingProgress,
  }) = _BookDetail;

  factory BookDetail.fromJson(Map<String, dynamic> json) =>
      _$BookDetailFromJson(json);
}

/// 詳細に含まれるカテゴリ（ID と名前）。
@freezed
abstract class BookCategory with _$BookCategory {
  const factory BookCategory({required int id, @Default('') String name}) =
      _BookCategory;

  factory BookCategory.fromJson(Map<String, dynamic> json) =>
      _$BookCategoryFromJson(json);
}

/// 巻一覧の 1 巻。
@freezed
abstract class BookVolume with _$BookVolume {
  const factory BookVolume({
    required int id,
    @Default(0) int volume,

    /// `?m=` 付きの相対 URL。`null` はサムネイル無し。
    String? thumbnail,

    /// 既読情報から分かる総ページ数（未読の巻は `null`）。
    @JsonKey(name: 'total_pages') int? totalPages,

    /// ZIP のバイト数。ZIP が無ければ `null` = ダウンロードできない。
    @JsonKey(name: 'archive_bytes') int? archiveBytes,

    /// ページ画像の内容バージョン（ZIP の mtime）。
    /// ダウンロード済みデータとの照合（「更新あり」判定）に使う。
    @JsonKey(name: 'files_version') int? filesVersion,
    @JsonKey(name: 'user_volume_status') VolumeUserStatus? userStatus,
  }) = _BookVolume;

  factory BookVolume.fromJson(Map<String, dynamic> json) =>
      _$BookVolumeFromJson(json);
}

/// 巻ごとの読書状態。
@freezed
abstract class VolumeUserStatus with _$VolumeUserStatus {
  const factory VolumeUserStatus({
    @JsonKey(name: 'current_page') @Default(0) int currentPage,
    @JsonKey(name: 'max_page') @Default(0) int maxPage,
    @JsonKey(name: 'is_finished', fromJson: boolFromJson)
    @Default(false)
    bool isFinished,
  }) = _VolumeUserStatus;

  factory VolumeUserStatus.fromJson(Map<String, dynamic> json) =>
      _$VolumeUserStatusFromJson(json);
}

/// タイトル単位の読書進捗。
@freezed
abstract class ReadingProgress with _$ReadingProgress {
  const factory ReadingProgress({
    @JsonKey(name: 'read_volumes') @Default(0) int readVolumes,
    @JsonKey(name: 'total_volumes') @Default(0) int totalVolumes,

    /// 読みかけの巻の**巻数**（巻 ID ではない）。無ければ `null`。
    @JsonKey(name: 'current_volume') int? currentVolume,
    @JsonKey(name: 'current_page') @Default(0) int currentPage,
    @JsonKey(name: 'total_pages') @Default(0) int totalPages,
  }) = _ReadingProgress;

  factory ReadingProgress.fromJson(Map<String, dynamic> json) =>
      _$ReadingProgressFromJson(json);
}

/// [BookVolume] の派生値。
extension BookVolumeX on BookVolume {
  /// ダウンロードできる巻か（ZIP がある）。
  bool get isDownloadable => archiveBytes != null && filesVersion != null;

  /// 読了済みか。
  bool get isFinished => userStatus?.isFinished ?? false;

  /// 読みかけか。
  bool get isInProgress {
    final status = userStatus;
    return status != null && !status.isFinished && status.currentPage > 0;
  }
}
