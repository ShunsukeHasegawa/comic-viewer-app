import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/cache/image_cache_store.dart';
import '../../../core/cache/memory_image_cache.dart';
import '../../downloads/application/auto_delete_runner.dart';
import '../../downloads/application/download_queue.dart';
import '../../offline/application/offline_metadata_gateway.dart';

part 'clear_all_data.g.dart';

/// 端末のデータをまとめて削除する。失敗があれば最初のエラーを返す。
typedef ClearAllData = Future<Object?> Function();

/// 「すべてのデータを削除」（#13）。
///
/// 消すもの: ダウンロード済みの巻（転送中・書きかけを含む）、一時キャッシュ
/// （ページ + サムネイル。メモリ上の画像も）、ダウンロードが無くなった
/// タイトルのオフライン用の控え、自動削除の記録。
///
/// **消さないもの**: 未送信の読書進捗（サーバーにも無い = 失うと戻らない）、
/// 設定、ログイン状態、一覧の控え（数百 KB。圏外で一覧を出し続けるため）。
/// ログアウトはしない。
///
/// 1 つの手順が失敗しても残りは続ける（途中で止めると「ダウンロードは
/// 消えたがキャッシュは残った」状態を黙って作る）。
@Riverpod(keepAlive: true)
ClearAllData clearAllData(Ref ref) => () async {
  Object? firstError;
  Future<void> step(String label, Future<void> Function() task) async {
    try {
      await task();
    } on Object catch (error) {
      debugPrint('[clear-all] $label failed: $error');
      firstError ??= error;
    }
  }

  // 転送の取り消し（タスクの記録に残る Bearer を先に消す）→ 台帳・ZIP・書きかけ。
  await step(
    'downloads',
    () => ref.read(downloadQueueProvider.notifier).purgeAll(),
  );
  await step('image cache', () async {
    try {
      final store = await ref.read(imageCacheStoreProvider.future);
      await store.clear();
    } finally {
      // ディスクの削除に失敗しても、デコード済みの画像は捨てる。
      ref.read(memoryImageCacheClearerProvider)();
    }
  });
  await step(
    'offline metadata',
    () => ref.read(offlineMetadataGatewayProvider).prune(),
  );
  await step(
    'auto delete records',
    // 気づいた時刻と「前回の自動削除」（残すと 0 巻の横に消えた記録が並ぶ）。
    () => ref.read(clearAutoDeleteRecordsProvider)(),
  );
  return firstError;
};
