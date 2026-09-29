import 'dart:io';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/dio_provider.dart';
import '../../domain/models/volume_manifest.dart';
import 'api_client.dart';

part 'volumes_api.g.dart';

/// アーカイブ取得の進捗通知。[total] はマニフェストと食い違うことがあるので、
/// 検証は呼び出し側（`DownloadQueue`）がマニフェストの値で行う。
typedef ArchiveProgress = void Function(int received, int? total);

/// 1 回のアーカイブ取得の結果。
class ArchiveDownloadResult {
  const ArchiveDownloadResult({
    required this.receivedBytes,
    required this.resumed,
    this.contentLength,
  });

  /// 取得後のファイル全体のバイト数（再開時は既存分を含む）。
  final int receivedBytes;

  /// サーバーが `Range` を受け入れて 206 を返したか。
  ///
  /// 200 が返ったときは続きではなく先頭から届いているため、ファイルは
  /// 切り詰めて書き直している（途中に古い内容が残らない）。
  final bool resumed;

  /// サーバーが申告した全体のバイト数（206 なら `Content-Range` の全体長）。
  final int? contentLength;
}

/// 巻アーカイブ（ZIP）のエンドポイント。
///
/// ページ単位ではなく **ZIP を 1 リクエストで**取る。自宅サーバー（HDD）は
/// ページ単位だと 1 巻で数百回 ZIP を開き直すことになるため。
abstract interface class VolumesApi {
  /// ダウンロード計画用のマニフェスト。削除済みの巻は [NotFoundException]。
  Future<VolumeManifest> fetchManifest(int volumeId);

  /// ZIP を [target] へ書く。
  ///
  /// [target] が既に存在する場合は**その続きから** `Range` で取得する。
  /// [ifRangeEtag] を渡すと、サーバー側の ZIP が差し替わっていた場合に
  /// 部分ファイルへ別世代のバイト列が継ぎ足されるのを防げる（サーバーは
  /// 200 を返し、こちらは先頭から書き直す）。
  Future<ArchiveDownloadResult> downloadArchive({
    required int volumeId,
    required File target,
    String? ifRangeEtag,
    ArchiveProgress? onProgress,
    CancelToken? cancelToken,
  });
}

/// [VolumesApi] の実装（`dio` のストリーム取得）。
class HttpVolumesApi implements VolumesApi {
  const HttpVolumesApi({required this.client, required this.dio});

  final ApiClient client;

  /// アーカイブ本体はストリームで受けるため [Dio] を直接使う
  /// （`ApiClient` はメモリに載せる JSON 用）。Bearer は同じ
  /// `AuthInterceptor` が付ける。
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

  @override
  Future<ArchiveDownloadResult> downloadArchive({
    required int volumeId,
    required File target,
    String? ifRangeEtag,
    ArchiveProgress? onProgress,
    CancelToken? cancelToken,
  }) async {
    final offset = target.existsSync() ? target.lengthSync() : 0;

    final Response<ResponseBody> response;
    try {
      response = await dio.get<ResponseBody>(
        archivePath(volumeId),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          // ZIP は数百 MB になる。JSON API の 8 秒では読み始める前に切れる。
          receiveTimeout: imageTimeout,
          sendTimeout: imageTimeout,
          headers: {
            if (offset > 0) 'range': 'bytes=$offset-',
            if (offset > 0 && ifRangeEtag != null)
              'if-range': _quoteEtag(ifRangeEtag),
          },
          // 206 も成功として受ける。それ以外（416 など）は `ApiException` にする。
          validateStatus: (status) => status == 200 || status == 206,
        ),
      );
    } on Object catch (error) {
      throw ApiException.from(error);
    }

    final resumed = response.statusCode == 206;
    final body = response.data;
    if (body == null) {
      throw const UnexpectedResponseException(
        message: 'ダウンロードを開始できませんでした。',
        detail: 'empty archive body',
      );
    }

    final total = _expectedTotal(response.headers, resumed: resumed);
    // 206 でなければサーバーは先頭から送ってきている。追記すると壊れるので
    // 切り詰めて書き直す（`FileMode.writeOnly` が truncate する）。
    var received = resumed ? offset : 0;
    final sink = target.openSync(
      mode: resumed ? FileMode.writeOnlyAppend : FileMode.writeOnly,
    );
    try {
      await for (final chunk in body.stream) {
        sink.writeFromSync(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      sink.flushSync();
    } on FileSystemException {
      // 保存先の失敗（容量不足など）は通信の失敗と混ぜない。
      // 呼び出し側は「空き容量が足りません」として扱い、再送もしない。
      rethrow;
    } on Object catch (error) {
      // キャンセル / 回線断はここへ来る。書けた分は残す（再開の起点になる）。
      throw ApiException.from(error);
    } finally {
      sink.closeSync();
    }

    return ArchiveDownloadResult(
      receivedBytes: received,
      resumed: resumed,
      contentLength: total,
    );
  }

  /// 応答から「ZIP 全体のバイト数」を読む。
  ///
  /// 206 の `Content-Length` は**その応答の分だけ**なので、再開時は
  /// `Content-Range: bytes {from}-{to}/{total}` の `total` を見る。
  static int? _expectedTotal(Headers headers, {required bool resumed}) {
    if (resumed) {
      final range = headers.value('content-range');
      final total = range?.split('/').last.trim();
      return total == null ? null : int.tryParse(total);
    }
    final length = headers.value(Headers.contentLengthHeader);
    return length == null ? null : int.tryParse(length.trim());
  }

  /// `If-Range` はサーバーが返した ETag と**文字列として**比較される。
  ///
  /// マニフェストの `archive_etag` は引用符なしなので付け直す
  /// （Symfony / nginx が返す `ETag` は `"..."` の形）。
  static String _quoteEtag(String etag) {
    final trimmed = etag.trim();
    if (trimmed.startsWith('"') || trimmed.startsWith('W/')) return trimmed;
    return '"$trimmed"';
  }
}

@Riverpod(keepAlive: true)
VolumesApi volumesApi(Ref ref) => HttpVolumesApi(
  client: ref.watch(apiClientProvider),
  dio: ref.watch(dioProvider),
);
