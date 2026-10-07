import 'package:freezed_annotation/freezed_annotation.dart';

part 'archive_url.freezed.dart';
part 'archive_url.g.dart';

/// 巻の ZIP 用の署名付き URL（`GET /api/v2/volumes/{id}/archive-url`。#22）。
///
/// サーバー（comic-viewer `V2\VolumeController::archiveUrl` /
/// `VolumeService::buildArchiveSignedUrl`）は `url` / `expires_at` / `files_version`
/// を返す。`url` はその巻の ZIP しか取れず、期限切れ・ログアウトで 403、発行後に
/// ZIP が差し替わると 409 になる。`Authorization` 無しでそのまま GET する。
@freezed
abstract class ArchiveUrl with _$ArchiveUrl {
  const factory ArchiveUrl({
    required String url,

    /// 有効期限（最長 24 時間。トークンの期限が先ならそちら）。キューは見ない
    /// （期限切れは 403 で分かる）が、調べるときのために受け取っておく。
    @JsonKey(name: 'expires_at') DateTime? expiresAt,

    /// 発行時の ZIP の mtime（マニフェストの `files_version` と同じもの）。
    /// 既定値を持たせない（無いまま 0 で読むと、毎回「サーバー側のデータが
    /// 更新されました」になって理由が分からない）。
    @JsonKey(name: 'files_version') required int filesVersion,
  }) = _ArchiveUrl;

  factory ArchiveUrl.fromJson(Map<String, dynamic> json) =>
      _$ArchiveUrlFromJson(json);
}
