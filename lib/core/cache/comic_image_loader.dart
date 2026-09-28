import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../media/media_urls.dart';
import '../network/api_exception.dart';
import '../network/dio_provider.dart';
import '../storage/app_database.dart';
import 'image_cache_store.dart';

part 'comic_image_loader.g.dart';

/// 画像 1 枚の取得指定（URL とキャッシュキーを必ず一組で運ぶ）。
///
/// URL とキーを別々に組み立てると、世代（`files_version` / `?m=`）がずれて
/// 「新しい画像を取りに行ったのに古いキャッシュを書き戻す」事故が起きる。
/// 生成は [ComicImageRequest.page] / [ComicImageRequest.thumbnail] だけに絞る。
@immutable
class ComicImageRequest {
  const ComicImageRequest({
    required this.url,
    required this.cacheKey,
    required this.kind,
  });

  /// ビューアのページ画像。
  factory ComicImageRequest.page(
    MediaUrls urls, {
    required int volumeId,
    required int page,
    required int filesVersion,
  }) {
    return ComicImageRequest(
      url: urls.page(
        volumeId: volumeId,
        page: page,
        filesVersion: filesVersion,
      ),
      cacheKey: urls.pageCacheKey(
        volumeId: volumeId,
        page: page,
        filesVersion: filesVersion,
      ),
      kind: CachedImageKind.page,
    );
  }

  /// サムネイル。[apiUrl] が「サムネイル無し」なら `null`。
  static ComicImageRequest? thumbnail(MediaUrls urls, String? apiUrl) {
    final url = urls.thumbnail(apiUrl);
    final cacheKey = urls.thumbnailCacheKey(apiUrl);
    if (url == null || cacheKey == null) return null;
    return ComicImageRequest(
      url: url,
      cacheKey: cacheKey,
      kind: CachedImageKind.thumbnail,
    );
  }

  final Uri url;

  /// ディスクキャッシュのキー（世代を含む）。
  final String cacheKey;

  /// ページ / サムネイル。上限を別枠で管理するため保存時に記録する。
  final CachedImageKind kind;

  @override
  bool operator ==(Object other) =>
      other is ComicImageRequest &&
      other.cacheKey == cacheKey &&
      other.url == url &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(cacheKey, url, kind);

  @override
  String toString() => 'ComicImageRequest($cacheKey, $url)';
}

/// コミック画像の取得口。**画像を取る経路はここ 1 本に集約する**。
///
/// 解決順は「一時キャッシュ → ネットワーク」。ダウンロード済みローカルを
/// 最優先にするのは #11 で [load] の先頭に差し込む（このクラスだけを直せば
/// 表示・先読みの両方に効く）。
///
/// 認証は `Dio` の `AuthInterceptor` に任せる。API と同じオリジンにだけ Bearer が
/// 付き、他オリジン（CDN 等）へはトークンを送らない。判定を二重に持たない。
class ComicImageLoader {
  ComicImageLoader({required this.dio, required this.store});

  final Dio dio;
  final ImageCacheStore store;

  /// 進行中の取得（表示と先読みが同じページに重なることがある）。
  final _inFlight = <String, Future<Uint8List>>{};

  /// 画像のバイト列を返す。取得できなければ [ApiException] を投げる。
  Future<Uint8List> load(ComicImageRequest request) {
    final running = _inFlight[request.cacheKey];
    // 同じ画像を二重にダウンロードしない（自宅サーバーの負荷を上げない）。
    if (running != null) return running;

    final task = _load(request);
    _inFlight[request.cacheKey] = task;
    return task.whenComplete(() => _inFlight.remove(request.cacheKey));
  }

  Future<Uint8List> _load(ComicImageRequest request) async {
    // #11 でここにダウンロード済みローカルファイルの参照を挿す。
    try {
      final cached = await store.read(request.cacheKey);
      if (cached != null) return cached.bytes;
    } on Object {
      // キャッシュが読めないだけならネットワークから取り直す。
      // ここで投げると、取り直せば表示できる画像まで失敗扱いになる
      // （しかも `ApiException` ですらない例外が UI へ漏れる）。
    }

    // ダウンロードの最中にログアウト（全削除）が入ったら書き戻さないための世代。
    // 前のユーザーの画像がディスクに残ると、別のユーザーがそれを見てしまう。
    final generation = store.generation;
    final downloaded = await _download(request.url);
    try {
      await store.write(
        key: request.cacheKey,
        kind: request.kind,
        bytes: downloaded.bytes,
        contentType: downloaded.contentType,
        generation: generation,
      );
    } on Object {
      // 保存に失敗しても表示は続ける（容量不足・OS のキャッシュ削除など）。
    }
    return downloaded.bytes;
  }

  Future<({Uint8List bytes, String? contentType})> _download(Uri url) async {
    final Response<List<int>> response;
    try {
      response = await dio.getUri<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          // 画像は JSON API より待つ（自宅サーバーは ZIP のシークに時間がかかる）。
          receiveTimeout: imageTimeout,
          sendTimeout: imageTimeout,
        ),
      );
    } on Object catch (error) {
      // 通信エラーと 404 を呼び出し側が型で区別できるようにする。
      throw ApiException.from(error);
    }

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const UnexpectedResponseException(
        message: '画像を読み込めませんでした。',
        detail: 'empty image body',
      );
    }
    return (
      bytes: Uint8List.fromList(data),
      contentType: response.headers.value(Headers.contentTypeHeader),
    );
  }
}

/// アプリ共通の画像取得口。
///
/// DB とキャッシュディレクトリの用意が終わるまで解決しないため、
/// 表示側は解決まで「読み込み中」を出す（ヘッダ無しで投げて 401 にしない）。
@Riverpod(keepAlive: true)
Future<ComicImageLoader> comicImageLoader(Ref ref) async {
  return ComicImageLoader(
    dio: ref.watch(dioProvider),
    store: await ref.watch(imageCacheStoreProvider.future),
  );
}

/// [ComicImageLoader] 経由で画像を読む [ImageProvider]。
///
/// デコード済み画像は Flutter の `ImageCache` が持つので、メモリ LRU を自前で
/// 作らない（二重に持つと解放のタイミングが読めなくなる）。
@immutable
class ComicImageProvider extends ImageProvider<ComicImageProvider> {
  const ComicImageProvider({
    required this.loader,
    required this.request,
    this.scale = 1,
  });

  final ComicImageLoader loader;
  final ComicImageRequest request;
  final double scale;

  @override
  Future<ComicImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<ComicImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    ComicImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: key._decode(decode),
      scale: key.scale,
      debugLabel: key.request.cacheKey,
    );
  }

  Future<ui.Codec> _decode(ImageDecoderCallback decode) async {
    try {
      final bytes = await loader.load(request);
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } on Object {
      // 失敗した completer は `ImageCache` に残り続ける（`putIfAbsent` は
      // pending のものをそのまま返す）。追い出さないと、ビューアの「再読み込み」も
      // 画面を開き直しても二度とここへ来ず、同じエラーが再生され続ける。
      PaintingBinding.instance.imageCache.evict(this);
      rethrow;
    }
  }

  /// `ImageCache` のキーは**キャッシュキー（世代つき）**で決める。
  ///
  /// [loader] は同一性に含めない。含めると provider を作り直すたびに
  /// メモリキャッシュが当たらなくなる。ログアウト時のメモリ破棄は
  /// `ImageCachePurger` が行う。
  @override
  bool operator ==(Object other) =>
      other is ComicImageProvider &&
      other.request == request &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(request, scale);

  @override
  String toString() => 'ComicImageProvider(${request.cacheKey})';
}
