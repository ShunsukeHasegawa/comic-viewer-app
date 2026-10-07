import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import '../../domain/models/archive_url.dart';
import '../../domain/models/volume_manifest.dart';
import 'api_client.dart';

part 'volumes_api.g.dart';

/// 巻アーカイブ（ZIP）のエンドポイント。
///
/// ページ単位ではなく **ZIP を 1 リクエストで**取る。自宅サーバー（HDD）は
/// ページ単位だと 1 巻で数百回 ZIP を開き直すことになるため。
///
/// ZIP 本体の転送は Dart ではなく OS のバックグラウンド転送（`ArchiveTransport`）
/// が行う（アプリを閉じても続けるため。#10）。ここが持つのはマニフェストと、
/// 転送に渡す署名付き URL の取得だけ。
abstract interface class VolumesApi {
  /// ダウンロード計画用のマニフェスト。削除済みの巻は `NotFoundException`。
  Future<VolumeManifest> fetchManifest(int volumeId);

  /// OS の転送に渡す ZIP の署名付き URL（#22）。配信できない巻は `NotFoundException`。
  ///
  /// `url` のスキームとホストは API と同じものに付け替えて返す（パスとクエリは
  /// そのまま）。サーバーは自分が受けたリクエストのホストで URL を作るので、
  /// TLS を終端するプロキシの後ろでは `http://` になりうる（ネイティブの転送は
  /// cleartext を許していないので全部失敗する）。署名はパスとクエリにしか
  /// 掛かっていないので、付け替えても通る。
  ///
  /// 転送には `Authorization` を付けない。付けると転送タスクの記録（Android は
  /// パッケージの永続領域、iOS は `UserDefaults`）にログイン用トークンが平文で残る。
  Future<ArchiveUrl> fetchArchiveUrl(int volumeId);
}

/// [VolumesApi] の実装。
class HttpVolumesApi implements VolumesApi {
  const HttpVolumesApi({required this.client, required this.dio});

  final ApiClient client;

  /// 署名付き URL の付け替え先（`baseUrl`。API と同じ配信元に揃えるため）。
  final Dio dio;

  static String manifestPath(int volumeId) =>
      'api/v2/volumes/$volumeId/manifest';

  static String archiveUrlPath(int volumeId) =>
      'api/v2/volumes/$volumeId/archive-url';

  @override
  Future<VolumeManifest> fetchManifest(int volumeId) async {
    final path = manifestPath(volumeId);
    final json = await client.getObject(path);
    return ApiClient.parse(json, VolumeManifest.fromJson, path: path);
  }

  @override
  Future<ArchiveUrl> fetchArchiveUrl(int volumeId) async {
    final path = archiveUrlPath(volumeId);
    final json = await client.getObject(path);
    final archiveUrl = ApiClient.parse(json, ArchiveUrl.fromJson, path: path);
    final issued = Uri.parse(archiveUrl.url);
    final base = Uri.parse(dio.options.baseUrl);
    return archiveUrl.copyWith(
      url: base.replace(path: issued.path, query: issued.query).toString(),
    );
  }
}

@Riverpod(keepAlive: true)
VolumesApi volumesApi(Ref ref) => HttpVolumesApi(
  client: ref.watch(apiClientProvider),
  dio: ref.watch(dioProvider),
);
