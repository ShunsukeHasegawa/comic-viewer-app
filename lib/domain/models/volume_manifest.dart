import 'package:freezed_annotation/freezed_annotation.dart';

part 'volume_manifest.freezed.dart';
part 'volume_manifest.g.dart';

/// ダウンロード計画用のマニフェスト（`GET /api/v2/volumes/{id}/manifest`）。
///
/// サーバー（comic-viewer `V2\VolumeController::manifest` / `VolumeService::getManifest`）は
/// `id` / `volume` / `book_id` / `files_version` / `archive_bytes` / `archive_etag` /
/// `page_count` / `pages` を返す。`volume` は巻数（float もありうる）で
/// ダウンロードには使わないため、ここでは受け取らない。
@freezed
abstract class VolumeManifest with _$VolumeManifest {
  const factory VolumeManifest({
    required int id,
    @JsonKey(name: 'book_id') @Default(0) int bookId,

    /// ZIP の mtime。取得済みデータの世代であり「更新あり」判定の基準。
    @JsonKey(name: 'files_version') @Default(0) int filesVersion,

    /// ZIP のバイト数。`Content-Length` の検証と空き容量チェックに使う。
    @JsonKey(name: 'archive_bytes') @Default(0) int archiveBytes,

    /// `<16進 mtime>-<16進 size>` 形式の検証子。再開時の `If-Range` に使う。
    @JsonKey(name: 'archive_etag') String? archiveEtag,

    /// ZIP に入っている画像の枚数。展開後の検証に使う。
    @JsonKey(name: 'page_count') @Default(0) int pageCount,
    @Default([]) List<VolumeManifestPage> pages,
  }) = _VolumeManifest;

  factory VolumeManifest.fromJson(Map<String, dynamic> json) =>
      _$VolumeManifestFromJson(json);
}

/// マニフェストの 1 ページ。
///
/// [index] は ZIP 内のエントリ番号（`/books/view/{volumeId}/{index}` と同じ）で、
/// ダウンロード済み ZIP からページを取り出すとき（#11）にそのまま使える。
@freezed
abstract class VolumeManifestPage with _$VolumeManifestPage {
  const factory VolumeManifestPage({
    @Default(0) int index,

    /// `jpg` / `png` / `avif`（サーバー側で `jpeg` → `jpg` に正規化済み）。
    @Default('jpg') String extension,
    @Default(0) int bytes,
  }) = _VolumeManifestPage;

  factory VolumeManifestPage.fromJson(Map<String, dynamic> json) =>
      _$VolumeManifestPageFromJson(json);
}
