import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import '../../domain/models/volume_manifest.dart';
import 'api_client.dart';

part 'volumes_api.g.dart';

/// 巻アーカイブ（ZIP）のエンドポイント。
///
/// ページ単位ではなく **ZIP を 1 リクエストで**取る。自宅サーバー（HDD）は
/// ページ単位だと 1 巻で数百回 ZIP を開き直すことになるため。
///
/// ZIP 本体の転送は Dart ではなく OS のバックグラウンド転送（`ArchiveTransport`）
/// が行う（アプリを閉じても続けるため。#10）。ここが持つのはマニフェストの取得と、
/// 転送に渡す URL の組み立てだけ。
abstract interface class VolumesApi {
  /// ダウンロード計画用のマニフェスト。削除済みの巻は `NotFoundException`。
  Future<VolumeManifest> fetchManifest(int volumeId);

  /// ZIP の絶対 URL（OS の転送に渡す）。
  Uri archiveUri(int volumeId);
}

/// [VolumesApi] の実装。
class HttpVolumesApi implements VolumesApi {
  const HttpVolumesApi({required this.client, required this.dio});

  final ApiClient client;

  /// URL の組み立てに `baseUrl` を使う（API と同じ配信元に揃えるため）。
  final Dio dio;

  static String manifestPath(int volumeId) =>
      'api/v2/volumes/$volumeId/manifest';

  static String archivePath(int volumeId) => 'api/v2/volumes/$volumeId/archive';

  @override
  Future<VolumeManifest> fetchManifest(int volumeId) async {
    final path = manifestPath(volumeId);
    final json = await client.getObject(path);
    return ApiClient.parse(json, VolumeManifest.fromJson, path: path);
  }

  /// `dio` と同じ規則（`baseUrl` + 相対パス）で組み立てる。ベース URL が
  /// サブパスを持っていても保つ（`baseUrl` は末尾スラッシュ付き）。
  @override
  Uri archiveUri(int volumeId) =>
      Uri.parse(dio.options.baseUrl).resolve(archivePath(volumeId));
}

@Riverpod(keepAlive: true)
VolumesApi volumesApi(Ref ref) => HttpVolumesApi(
  client: ref.watch(apiClientProvider),
  dio: ref.watch(dioProvider),
);
