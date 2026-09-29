import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/volume_download.dart';
import 'download_queue.dart';

part 'downloaded_lookup.g.dart';

/// 端末で読める（検証まで通った実体がある）巻 ID。
///
/// 初回の取得中 / 中断中は含めない。オフラインで「開ける巻」を判断する基準なので、
/// 途中のデータを含めると開いてから読めないことに気づく形になってしまう。
/// 一方で「更新あり」の取り直し中は**旧世代の ZIP が残っていて読める**ので、
/// status ではなく [VolumeDownload.hasInstalledArchive] で判断する（#11）。
@riverpod
Set<int> downloadedVolumeIds(Ref ref) {
  final downloads = ref.watch(downloadQueueProvider).value;
  return installedVolumeIds(downloads);
}

/// 読める巻を 1 つ以上持つタイトル ID。
@riverpod
Set<int> downloadedBookIds(Ref ref) {
  final downloads = ref.watch(downloadQueueProvider).value;
  return installedBookIds(downloads);
}

/// ダウンロード台帳をまだ読み終えていない（= 何が読めるか分からない）。
///
/// 台帳の読み込みは `path_provider` とディレクトリ作成を待つので、圏外の
/// コールドスタートでは一覧（drift の控え）より遅れる。その間の空集合を
/// 「ダウンロード済みが 0 件」と言い切ると、圏外で既定 ON の絞り込みが
/// 「ありません／すべて表示」になってしまう（#11 のレビュー指摘）。
/// 失敗（`AsyncError`）は `false`。読み終える見込みが無いので、待たせるより
/// 逃げ道（すべて表示）を出す。
@riverpod
bool isDownloadLedgerLoading(Ref ref) =>
    ref.watch(downloadQueueProvider).isLoading;
