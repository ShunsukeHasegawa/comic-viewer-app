import 'package:flutter/material.dart';

import '../../../../core/utils/format.dart';
import '../../../../core/widgets/thumbnail_image.dart';
import '../../../library/presentation/widgets/book_tiles.dart';
import '../../domain/download_manager_view.dart';
import '../../domain/volume_download.dart';

/// 進行中の行に出す状態の文言。
///
/// [waitingForWifi] は Wi-Fi 限定の設定で Wi-Fi に繋がっていないこと。待機中の
/// 巻が動かない理由を「ダウンロード待ち」のまま隠さない。
String progressLabelOf(DownloadEntry entry, {bool waitingForWifi = false}) {
  final download = entry.download;
  return switch (download.status) {
    VolumeDownloadStatus.downloading => [
      '${entry.isRefetch ? '更新を取得中' : 'ダウンロード中'} ${download.percent}%',
      if (download.totalBytes > 0)
        '${formatBytes(download.receivedBytes)} / '
            '${formatBytes(download.totalBytes)}',
    ].join('・'),
    VolumeDownloadStatus.queued =>
      waitingForWifi
          ? 'Wi-Fi 接続待ち'
          : (entry.isRefetch ? '更新の取得待ち' : 'ダウンロード待ち'),
    VolumeDownloadStatus.paused => '中断中 ${download.percent}%',
    VolumeDownloadStatus.failed =>
      'ダウンロード失敗: ${download.failureReason ?? 'もう一度お試しください。'}',
    VolumeDownloadStatus.completed => 'ダウンロード済み',
  };
}

/// 失敗の行に出す文言。
String failureLabelOf(DownloadEntry entry) {
  final reason = entry.download.failureReason ?? 'もう一度お試しください。';
  return entry.refetchFailed ? '更新の取得に失敗: $reason' : 'ダウンロード失敗: $reason';
}

/// 小さなサムネイル（行の先頭）。
class DownloadThumbnail extends StatelessWidget {
  const DownloadThumbnail({required this.apiUrl, super.key});

  final String? apiUrl;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 40,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: ThumbnailImage(apiUrl: apiUrl, aspectRatio: bookCoverAspectRatio),
    ),
  );
}

/// 進行中（取得中 / 待機中 / 中断）の 1 行。
///
/// 並び替えは #13 では実装せず、別 Issue に切り出す（未起票。起票したら番号を
/// ここに書く。それまで #13 のチェックリストの「並び替え」は未完了のまま残す）。
/// OS の holding queue は priority → creationTime の順で取り出すので、待機中の
/// 巻を前へ動かすには取り消して優先度付きで積み直す必要があり、`DownloadQueue`
/// の `_tasks` / `_cancelling` / `_reservedBytes` / 起動時の照合と絡む。#10 の
/// レビューで何度も直した箇所なので、`DownloadQueue` 側の API
/// （例: `prioritize(volumeId)`）として設計する。
class DownloadProgressTile extends StatelessWidget {
  const DownloadProgressTile({
    required this.entry,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    this.waitingForWifi = false,
    this.enabled = true,
    super.key,
  });

  final DownloadEntry entry;
  final bool waitingForWifi;

  /// 削除の実行中など、操作を受け付けないとき `false`。
  final bool enabled;

  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final download = entry.download;

    return ListTile(
      leading: DownloadThumbnail(apiUrl: entry.thumbnail),
      title: Text('${entry.titleLabel} ${entry.volumeLabel}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            progressLabelOf(entry, waitingForWifi: waitingForWifi),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              // 全体のバイト数が未確定でも回り続ける表示にはしない
              // （進んでいないのか分からない表示より 0% の方が正直）。
              value: download.progress ?? 0,
              minHeight: 3,
            ),
          ),
        ],
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: _actions()),
    );
  }

  List<Widget> _actions() {
    VoidCallback? guard(VoidCallback action) => enabled ? action : null;

    // 「更新あり」の取り直し。remove だと読める旧世代の ZIP まで消えるので、
    // 中止は pause（キューが旧世代の completed へ戻す）にする。
    if (entry.isRefetch) {
      return [
        IconButton(
          onPressed: guard(onPause),
          tooltip: '更新を中止',
          icon: const Icon(Icons.stop_circle_outlined),
        ),
      ];
    }
    return switch (entry.download.status) {
      VolumeDownloadStatus.paused => [
        IconButton(
          onPressed: guard(onResume),
          tooltip: '再開',
          icon: const Icon(Icons.play_arrow),
        ),
        // 旧世代が読める中断行（キューが旧世代の完了へ戻す前に書かれた古い
        // 行。今のキューは再起動後の中断でも完了へ戻す）は、ここで取り消すと
        // 旧世代まで消える。消すのは「ダウンロード済み」の行から（確認つき）に限る。
        if (!entry.download.hasInstalledArchive)
          IconButton(
            onPressed: guard(onCancel),
            tooltip: 'キャンセル',
            icon: const Icon(Icons.close),
          ),
      ],
      _ => [
        IconButton(
          onPressed: guard(onPause),
          tooltip: '一時停止',
          icon: const Icon(Icons.pause),
        ),
        IconButton(
          onPressed: guard(onCancel),
          tooltip: 'キャンセル',
          icon: const Icon(Icons.close),
        ),
      ],
    };
  }
}

/// 失敗した巻の 1 行（再試行 / 削除）。
class DownloadFailureTile extends StatelessWidget {
  const DownloadFailureTile({
    required this.entry,
    required this.onRetry,
    required this.onDelete,
    this.enabled = true,
    super.key,
  });

  final DownloadEntry entry;
  final bool enabled;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: DownloadThumbnail(apiUrl: entry.thumbnail),
      title: Text('${entry.titleLabel} ${entry.volumeLabel}'),
      subtitle: Text(
        failureLabelOf(entry),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: enabled ? onRetry : null,
            tooltip: '再試行',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: enabled ? onDelete : null,
            tooltip: '削除',
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
