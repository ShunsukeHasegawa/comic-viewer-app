import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/json/json_list.dart';
import 'book.dart';

part 'read_volume.freezed.dart';
part 'read_volume.g.dart';

/// ビューアを開くための情報（`GET /api/books/read/volume/{volumeId}`）。
@freezed
abstract class ReadVolume with _$ReadVolume {
  const factory ReadVolume({
    required int id,

    /// 巻数。
    @Default(0) int volume,

    /// 前回読んでいたページ（1 始まり）。
    @JsonKey(name: 'current_page') @Default(1) int currentPage,
    @JsonKey(name: 'next_volume_id') int? nextVolumeId,

    /// 巻末オーバーレイ用。`?m=` 付きの相対 URL。
    @JsonKey(name: 'next_volume_thumbnail') String? nextVolumeThumbnail,

    /// ページ番号の一覧。ZIP が無い巻は空になる。
    @JsonKey(fromJson: intListFromJson) @Default([]) List<int> files,

    /// ページ画像の内容バージョン（ZIP の mtime）。
    ///
    /// 画像 URL に `?v=` として必ず付ける。ZIP を差し替えても URL が変わらないため、
    /// この値でキャッシュを切り替える。ZIP が無ければ `null`。
    @JsonKey(name: 'files_version') int? filesVersion,
    required Book book,
  }) = _ReadVolume;

  factory ReadVolume.fromJson(Map<String, dynamic> json) =>
      _$ReadVolumeFromJson(json);
}

/// [ReadVolume] の派生値。
extension ReadVolumeX on ReadVolume {
  /// ページ数。ZIP 欠損時は 0。
  int get pageCount => files.length;

  /// ZIP が無い（読めない）巻。進捗の保存も送信もしてはいけない。
  bool get isEmpty => files.isEmpty || filesVersion == null;

  /// 進捗として保存してよいページ番号に丸める。
  ///
  /// 巻末オーバーレイ（`files.length + 1` ページ目）の番号を保存しないため。
  int clampPage(int page) {
    if (files.isEmpty) return 0;
    if (page < 1) return 1;
    return page > files.length ? files.length : page;
  }
}
