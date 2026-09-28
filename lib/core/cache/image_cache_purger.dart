import 'package:flutter/painting.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../session/session_data_purger.dart';
import 'image_cache_store.dart';

part 'image_cache_purger.g.dart';

/// ログアウト / セッション失効で一時キャッシュを全部捨てる（#15）。
///
/// Web 版 `purgeMediaCaches` 相当。**ページもサムネイルもまとめて**消す
/// （別のユーザーで開いたときに前のユーザーの画像を見せない）。
/// 明示的にダウンロードしたデータ（#9）は別領域・別テーブルなので対象外。
class ImageCachePurger implements SessionDataPurger {
  const ImageCachePurger(this._store);

  /// ログアウトまで DB / ディレクトリを作らせないため、解決は遅延させる。
  final Future<ImageCacheStore> Function() _store;

  @override
  String get debugLabel => 'image cache';

  @override
  Future<void> purgeSessionData() async {
    final store = await _store();
    await store.clear();
    // デコード済みの画像はメモリにも残るため、そちらも捨てる。
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}

@Riverpod(keepAlive: true)
SessionDataPurger imageCachePurger(Ref ref) =>
    ImageCachePurger(() => ref.read(imageCacheStoreProvider.future));
