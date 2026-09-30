import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../downloads/application/download_queue.dart';
import '../../downloads/application/download_storage_summary_provider.dart';
import '../../downloads/data/free_space_probe.dart';

export '../../downloads/data/free_space_probe.dart' show DeviceStorage;

part 'device_storage_provider.g.dart';

/// 端末の空き容量と全体の容量（設定画面の表示用）。`null` は「不明」。
///
/// ダウンロードを消したら取り直す（台帳から出す使用量と空き容量の表示を
/// 食い違わせない）。キャッシュ削除・全データ削除・再計算の後は画面が
/// invalidate する。プローブは投げないので、エラーにはならない。
@riverpod
Future<DeviceStorage?> deviceStorage(Ref ref) {
  // 受信バイト（途中の分）は進捗が届くたびに変わるので見ない。見ると、
  // 設定画面を開いたままダウンロードが進む間ずっとプラットフォームチャネルを
  // 叩き続ける。測り直すのは、読める巻が消えた / 確定したとき（巻数と容量）と、
  // 台帳の行が増減したとき（途中の巻を消しても一時ファイルの分が空く）だけ。
  ref
    ..watch(
      downloadStorageSummaryProvider.select(
        (summary) =>
            (summary.value?.installedVolumes, summary.value?.installedBytes),
      ),
    )
    ..watch(downloadQueueProvider.select((ledger) => ledger.value?.length));
  return ref.watch(deviceStorageProbeProvider)();
}
