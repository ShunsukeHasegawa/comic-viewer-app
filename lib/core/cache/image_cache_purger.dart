import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../session/session_data_purger.dart';
import 'image_cache_store.dart';
import 'memory_image_cache.dart';

part 'image_cache_purger.g.dart';

/// ログアウト / セッション失効で一時キャッシュを全部捨てる（#15）。
///
/// Web 版 `purgeMediaCaches` 相当。**ページもサムネイルもまとめて**消す
/// （別のユーザーで開いたときに前のユーザーの画像を見せない）。
/// 明示的にダウンロードしたデータ（#9）は別領域・別テーブルなので対象外。
///
/// 破棄の時点で走っているダウンロードは `ImageCacheStore` の世代で弾く
/// （`clear()` が世代を進め、それより前に始まった取得の書き戻しを捨てる）。
class ImageCachePurger implements SessionDataPurger {
  const ImageCachePurger(this._store, this._clearMemory);

  /// ログアウトまで DB / ディレクトリを作らせないため、解決は遅延させる。
  final Future<ImageCacheStore> Function() _store;

  final MemoryImageCacheClearer _clearMemory;

  @override
  String get debugLabel => 'image cache';

  /// 一時キャッシュは取り直せる（消えても表示が遅くなるだけ）。
  @override
  bool get purgesRefetchableOnly => true;

  @override
  Future<void> purgeSessionData() async {
    final store = await _store();
    await store.clear();
    // デコード済みの画像はメモリにも残るため、そちらも捨てる。
    _clearMemory();
  }
}

@Riverpod(keepAlive: true)
SessionDataPurger imageCachePurger(Ref ref) => ImageCachePurger(
  () => ref.read(imageCacheStoreProvider.future),
  ref.watch(memoryImageCacheClearerProvider),
);
