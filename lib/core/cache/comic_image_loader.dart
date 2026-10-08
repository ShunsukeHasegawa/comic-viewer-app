import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/downloads/data/downloaded_page_source.dart';
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
    this.page,
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
      page: ComicPageRef(
        volumeId: volumeId,
        page: page,
        filesVersion: filesVersion,
      ),
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

  /// ダウンロード済み ZIP から取り出すための座標（サムネイルは `null`）。
  ///
  /// キャッシュキーを文字列として解析して求めない。キーの形は保存先の都合で
  /// 変わりうるので、作った側が素の値を持ったまま運ぶ。
  final ComicPageRef? page;

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

/// ページ画像の座標（巻 / ページ番号 / 世代）。
///
/// [page] は `/books/view/{volumeId}/{page}` の番号 = **ZIP のエントリ番号**。
@immutable
class ComicPageRef {
  const ComicPageRef({
    required this.volumeId,
    required this.page,
    required this.filesVersion,
  });

  final int volumeId;
  final int page;
  final int filesVersion;

  @override
  bool operator ==(Object other) =>
      other is ComicPageRef &&
      other.volumeId == volumeId &&
      other.page == page &&
      other.filesVersion == filesVersion;

  @override
  int get hashCode => Object.hash(volumeId, page, filesVersion);

  @override
  String toString() => 'ComicPageRef(v$volumeId/$filesVersion/$page)';
}

/// コミック画像の取得口。**画像を取る経路はここ 1 本に集約する**。
///
/// 解決順は「**ダウンロード済みローカル → 一時キャッシュ → ネットワーク**」（#11）。
/// ここ 1 箇所で決めるので、表示も先読みも同じ順で解決される。
///
/// 認証は `Dio` の `AuthInterceptor` に任せる。API と同じオリジンにだけ Bearer が
/// 付き、他オリジン（CDN 等）へはトークンを送らない。判定を二重に持たない。
class ComicImageLoader {
  ComicImageLoader({
    required this.dio,
    required this.store,
    this.localPages = const NoDownloadedPageSource(),
  });

  final Dio dio;
  final ImageCacheStore store;

  /// ダウンロード済み ZIP（#9）からページを取り出す口。
  final DownloadedPageSource localPages;

  /// 進行中の取得（表示と先読みが同じページに重なることがある）。
  ///
  /// 始めた時点のキャッシュの世代も持つ。全削除の後に来た要求を、前の世代の
  /// 取得（結果を返さずに失敗する）に相乗りさせないため。
  final _inFlight = <String, ({int generation, Future<Uint8List> task})>{};

  /// 画像のバイト列を返す。取得できなければ [ApiException] を投げる。
  ///
  /// 取得の途中で一時キャッシュの全削除（ログアウトなど）が入ったら、結果を
  /// 返さずに [RequestCancelledException] を投げる。全削除と一緒にメモリの
  /// `ImageCache` も捨てているので、返すと前の世代の画像がデコードされて
  /// 捨てたばかりの `ImageCache` に入り直す（次のユーザーに前の表紙が見える）。
  Future<Uint8List> load(ComicImageRequest request) {
    final generation = store.generation;
    final running = _inFlight[request.cacheKey];
    // 同じ画像を二重にダウンロードしない（自宅サーバーの負荷を上げない）。
    if (running != null && running.generation == generation) {
      return running.task;
    }

    final task = _load(request, generation);
    final entry = (generation: generation, task: task);
    _inFlight[request.cacheKey] = entry;
    return task.whenComplete(() {
      // 後の世代の取得が同じキーで走っていれば、そちらの記録は残す。
      if (identical(_inFlight[request.cacheKey], entry)) {
        _inFlight.remove(request.cacheKey);
      }
    });
  }

  Future<Uint8List> _load(ComicImageRequest request, int generation) async {
    final bytes = await _resolve(request, generation);
    // 返す直前にも確かめる（ローカル / キャッシュの読み出し・書き戻しの最中に
    // 全削除が入ることもある）。
    if (store.generation != generation) {
      throw const RequestCancelledException();
    }
    return bytes;
  }

  Future<Uint8List> _resolve(ComicImageRequest request, int generation) async {
    // 1. 明示的にダウンロードした巻（ZIP）。圏外でもここで解決する。
    final local = await _readLocal(request);
    if (local != null) return local;

    // 2. 一時キャッシュ。
    try {
      final cached = await store.read(request.cacheKey);
      if (cached != null) return cached.bytes;
    } on Object {
      // キャッシュが読めないだけならネットワークから取り直す。
      // ここで投げると、取り直せば表示できる画像まで失敗扱いになる
      // （しかも `ApiException` ですらない例外が UI へ漏れる）。
    }

    // 3. ネットワーク。
    // ダウンロードの最中にログアウト（全削除）が入ったら書き戻さない
    // （[generation] で弾く）。前のユーザーの画像がディスクに残ると、
    // 別のユーザーがそれを見てしまう。
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

  /// ダウンロード済みのページ。無い / 世代が違う / 読めないときは `null`。
  ///
  /// サムネイルは ZIP に入っていないので見に行かない（[ComicImageRequest.page]
  /// が `null` = サムネイル）。
  Future<Uint8List?> _readLocal(ComicImageRequest request) async {
    final page = request.page;
    if (page == null) return null;
    try {
      return await localPages.readPage(
        volumeId: page.volumeId,
        page: page.page,
        filesVersion: page.filesVersion,
      );
    } on Object {
      // ローカルが読めないだけなら、一時キャッシュ / ネットワークへ落ちる。
      return null;
    }
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
      // Dio は bytes 指定で Uint8List を返す。複製すると数 MB のページが
      // 先読みの分だけ一時的に 2 つずつメモリに載る。
      bytes: data is Uint8List ? data : Uint8List.fromList(data),
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
    localPages: await ref.watch(downloadedPageSourceProvider.future),
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
    this.decodeBox,
  });

  final ComicImageLoader loader;
  final ComicImageRequest request;
  final double scale;

  /// 指定すると、この枠（物理ピクセル）を覆える最小の大きさまで縮めて
  /// デコードする（縦横比は保ち、原寸より大きくはしない）。
  ///
  /// 一覧のサムネイルや背景を原寸でデコードすると `ImageCache`（既定 100MB）を
  /// 食い、ビューアの先読みしたページを押し出す（#28）。ビューアのページは
  /// 拡大に耐える解像度が要るので `null`（原寸）のままにする。
  final ({int width, int height})? decodeBox;

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
      final box = decodeBox;
      return await decode(
        await ui.ImmutableBuffer.fromUint8List(bytes),
        getTargetSize: box == null
            ? null
            : (width, height) => coverTargetSize(
                intrinsicWidth: width,
                intrinsicHeight: height,
                box: box,
              ),
      );
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
      other.scale == scale &&
      other.decodeBox == decodeBox;

  /// 大きさ違いは別の項目にする（縮めた絵をビューアの原寸の代わりに出さない）。
  /// 失敗時の追い出し（`evict(this)`）も同じ大きさの項目に当たる。
  @override
  int get hashCode => Object.hash(request, scale, decodeBox);

  @override
  String toString() => 'ComicImageProvider(${request.cacheKey}, $decodeBox)';

  /// [box] を覆える（`BoxFit.cover` で隙間が出ない）最小のデコードの大きさ。
  ///
  /// 片方の辺だけ指定すると、エンジンが縦横比を保ってもう片方を決める。
  /// 原寸のほうが小さければ縮めない（引き伸ばしても細部は増えない）。
  @visibleForTesting
  static ui.TargetImageSize coverTargetSize({
    required int intrinsicWidth,
    required int intrinsicHeight,
    required ({int width, int height}) box,
  }) {
    if (intrinsicWidth <= 0 || intrinsicHeight <= 0) {
      return const ui.TargetImageSize();
    }
    final scale = math.max(
      box.width / intrinsicWidth,
      box.height / intrinsicHeight,
    );
    if (scale >= 1) return const ui.TargetImageSize();
    return ui.TargetImageSize(
      width: math.max(1, (intrinsicWidth * scale).ceil()),
    );
  }
}
