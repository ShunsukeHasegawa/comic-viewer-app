import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/json/json_bool.dart';
import '../../core/json/json_date_time.dart';
import '../../core/json/json_list.dart';

part 'book.freezed.dart';
part 'book.g.dart';

/// ライブラリ一覧の 1 冊（`GET /api/books`）。
///
/// サーバーは `BookResource` を **`data` ラップ無しの素の配列**として返す。
/// 著者は単数形 `author`（`authors` ではない）で、名前の配列。
/// `tags` / `categories` は **ID の配列**（名前は `/api/tag` / `/api/category` 側）。
@freezed
abstract class Book with _$Book {
  const factory Book({
    required int id,
    @Default('') String title,

    /// 五十音順の並び替え / 検索に使う読み。
    String? kana,

    /// 最新巻のサムネイル URL（`?m=updated_at` 付きの相対 URL）。
    /// `null` は「サムネイル無し」。組み立て直してはいけない。
    String? thumbnail,
    @JsonKey(name: 'is_complete', fromJson: boolFromJson)
    @Default(false)
    bool isComplete,
    @JsonKey(name: 'is_unsafe', fromJson: boolFromJson)
    @Default(false)
    bool isUnsafe,

    /// 最新巻が追加された日時（更新日順の並び替えに使う）。
    @JsonKey(
      name: 'volume_added_at',
      fromJson: dateTimeFromJson,
      toJson: dateTimeToJson,
    )
    DateTime? volumeAddedAt,
    @JsonKey(name: 'latest_volume') int? latestVolume,
    @JsonKey(fromJson: stringListFromJson) @Default([]) List<String> author,
    @JsonKey(fromJson: intListFromJson) @Default([]) List<int> tags,
    @JsonKey(fromJson: intListFromJson) @Default([]) List<int> categories,
  }) = _Book;

  factory Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);
}

/// 一覧に重ねるユーザー固有の状態（`GET /api/books/user_status`）。
@freezed
abstract class UserStatus with _$UserStatus {
  const factory UserStatus({
    /// 未読の巻を含む書籍 ID。
    @JsonKey(fromJson: intListFromJson) @Default([]) List<int> unreads,

    /// お気に入りの書籍 ID。
    @JsonKey(fromJson: intListFromJson) @Default([]) List<int> favorites,
  }) = _UserStatus;

  factory UserStatus.fromJson(Map<String, dynamic> json) =>
      _$UserStatusFromJson(json);
}
