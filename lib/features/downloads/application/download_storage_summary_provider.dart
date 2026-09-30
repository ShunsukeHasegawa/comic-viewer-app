import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/download_storage_summary.dart';
import 'download_queue.dart';

export '../domain/download_storage_summary.dart';

part 'download_storage_summary_provider.g.dart';

/// ダウンロードの容量の内訳（設定画面用）。
///
/// 台帳（[downloadQueueProvider]）から毎回集計する。DB を別に集計しないので、
/// 巻を削除すればその場で表示が減る（「削除後に容量表示が正しく更新される」）。
///
/// 台帳の読み込み中 / 失敗はそのまま返す。0 B と見せると「ダウンロードが無い」
/// と読めてしまうため、画面はそれぞれを別に表示する。
@riverpod
AsyncValue<DownloadStorageSummary> downloadStorageSummary(Ref ref) =>
    ref.watch(downloadQueueProvider).whenData(summarizeDownloads);
