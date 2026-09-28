import 'package:flutter/painting.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_image_cache.g.dart';

/// デコード済み画像（Flutter の `ImageCache`）を捨てる処理。
///
/// ディスクのメタ情報だけ消してもメモリには残るため、「表紙を作り直す」つもりの
/// 手動削除やログアウトでは**必ずこちらも呼ぶ**。テストでは差し替える
/// （`PaintingBinding` を直接触らずに、呼ばれたことを確かめられるように）。
typedef MemoryImageCacheClearer = void Function();

@Riverpod(keepAlive: true)
MemoryImageCacheClearer memoryImageCacheClearer(Ref ref) {
  return () {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    // 表示中（listener が残っている）画像も捨てる。これが無いと、見えている
    // 一覧の表紙だけ削除前のまま残る。
    cache.clearLiveImages();
  };
}
