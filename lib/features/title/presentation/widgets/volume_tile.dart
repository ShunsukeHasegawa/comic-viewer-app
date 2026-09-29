import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/format.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/thumbnail_image.dart';
import '../../../../domain/models/book_detail.dart';
import '../../../downloads/application/download_queue.dart';
import '../../../downloads/domain/volume_download.dart';
import '../../../library/presentation/widgets/book_tiles.dart';

/// 巻一覧の 1 行。
class VolumeTile extends ConsumerWidget {
  const VolumeTile({
    required this.bookId,
    required this.volume,
    required this.onOpen,
    super.key,
  });

  /// この巻が属するタイトル（台帳に持ち、#10 / #13 の一括操作で使う）。
  final int bookId;

  final BookVolume volume;

  /// タップでビューアを開く。`null` は開けない（圏外で未ダウンロードの巻。#11）。
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = volume.userStatus;
    // ダウンロード状態は 1 度だけ読み、行のラベルとボタンで共有する
    // （別々に watch すると表示と操作がずれる瞬間ができる）。
    final download = ref.watch(downloadQueueProvider).value?[volume.id];

    return ListTile(
      onTap: onOpen,
      // 開けない行は文字も薄くする（タップしても何も起きない理由を見せる）。
      enabled: onOpen != null,
      leading: SizedBox(
        width: 40,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: ThumbnailImage(
            apiUrl: volume.thumbnail,
            aspectRatio: bookCoverAspectRatio,
          ),
        ),
      ),
      title: Text('${volume.volume} 巻'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (volume.isFinished)
                '読了'
              else if (volume.isInProgress && status != null)
                '${status.currentPage} / ${status.maxPage} ページ'
              else
                '未読',
              if (volume.archiveBytes case final bytes?) formatBytes(bytes),
              downloadLabelOf(volume, download),
              if (onOpen == null) 'オフラインでは読めません',
            ].join('・'),
            style: theme.textTheme.bodySmall,
          ),
          if (volume.isInProgress && status != null && status.maxPage > 0) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (status.currentPage / status.maxPage).clamp(0, 1),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
      trailing: VolumeDownloadButton(
        bookId: bookId,
        volume: volume,
        download: download,
      ),
    );
  }
}

/// 行に出すダウンロード状態の文言（未DL / DL中 / DL済み / 更新あり）。
String downloadLabelOf(BookVolume volume, VolumeDownload? download) {
  // サーバー側のアーカイブが消えていても、端末に落としてあるものは
  // 「ダウンロード済み」として見せる（削除する導線もここからしか無い）。
  if (download == null) {
    return volume.isDownloadable ? '未ダウンロード' : 'ダウンロード不可';
  }

  return switch (download.status) {
    VolumeDownloadStatus.queued => 'ダウンロード待ち',
    VolumeDownloadStatus.downloading => 'ダウンロード中 ${download.percent}%',
    VolumeDownloadStatus.paused => '中断中 ${download.percent}%',
    VolumeDownloadStatus.failed =>
      'ダウンロード失敗: ${download.failureReason ?? 'もう一度お試しください。'}',
    // 取り直しが失敗して旧世代へ戻したものは理由を添える。黙って
    // 「ダウンロード済み」に見せると、更新が入ったものと誤解される。
    VolumeDownloadStatus.completed => switch (download.failureReason) {
      final reason? => 'ダウンロード済み（更新の取得に失敗: $reason）',
      _ => download.isOutdated(volume.filesVersion) ? '更新あり' : 'ダウンロード済み',
    },
  };
}

/// 巻のダウンロード操作。
///
/// 一括ダウンロード（タイトル単位）は #10、ダウンロード一覧の画面は #13。
/// ここは巻ごとの導線だけを持つ。
class VolumeDownloadButton extends ConsumerWidget {
  const VolumeDownloadButton({
    required this.bookId,
    required this.volume,
    required this.download,
    super.key,
  });

  final int bookId;
  final BookVolume volume;
  final VolumeDownload? download;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final queue = ref.read(downloadQueueProvider.notifier);
    final current = download;

    if (current == null) {
      // サーバー側にアーカイブが無い巻。台帳にも無いので操作は何も出せない。
      if (!volume.isDownloadable) {
        return Tooltip(
          message: 'この巻はダウンロードできません（アーカイブがありません）',
          child: Icon(Icons.cloud_off_outlined, color: scheme.onSurfaceVariant),
        );
      }
      return IconButton(
        onPressed: () => _guard(
          context,
          what: 'ダウンロードの開始',
          action: () => queue.enqueue(volumeId: volume.id, bookId: bookId),
        ),
        tooltip: 'ダウンロード',
        icon: const Icon(Icons.download_outlined),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: switch (current.status) {
        VolumeDownloadStatus.queued => [_cancelButton(context, queue)],
        VolumeDownloadStatus.downloading => [
          IconButton(
            onPressed: () => _guard(
              context,
              what: 'ダウンロードの中断',
              action: () => queue.pause(volume.id),
            ),
            tooltip: 'ダウンロードを中断（${current.percent}%）',
            icon: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(
                    // 全体のバイト数が未確定でも回り続ける表示にはしない
                    // （進んでいないのか分からない表示より 0% の方が正直）。
                    value: current.progress ?? 0,
                    strokeWidth: 2,
                  ),
                ),
                const Icon(Icons.stop, size: 14),
              ],
            ),
          ),
        ],
        VolumeDownloadStatus.paused || VolumeDownloadStatus.failed => [
          // サーバー側にアーカイブが無い巻は再開しても 404 になるだけなので、
          // 取り消し（端末から消す）だけを残す。
          if (volume.isDownloadable)
            IconButton(
              onPressed: () => _guard(
                context,
                what: 'ダウンロードの再開',
                action: () => queue.resume(volume.id),
              ),
              tooltip: current.status == VolumeDownloadStatus.failed
                  ? 'もう一度ダウンロードする'
                  : 'ダウンロードを再開',
              icon: Icon(
                current.status == VolumeDownloadStatus.failed
                    ? Icons.refresh
                    : Icons.play_arrow,
                color: current.status == VolumeDownloadStatus.failed
                    ? scheme.error
                    : null,
              ),
            ),
          _cancelButton(context, queue),
        ],
        VolumeDownloadStatus.completed => [
          // 取り直しに失敗して旧世代へ戻したものにも、もう一度試す導線を出す
          // （オフラインのまま押したときはサーバーの世代が分からないので、
          // isOutdated では拾えない）。
          if (current.isOutdated(volume.filesVersion) ||
              current.failureReason != null)
            IconButton(
              onPressed: () => _guard(
                context,
                what: 'ダウンロードの開始',
                action: () =>
                    queue.enqueue(volumeId: volume.id, bookId: bookId),
              ),
              tooltip: current.failureReason == null
                  ? 'サーバー側が更新されています。ダウンロードし直す'
                  : '更新の取得に失敗しました。もう一度試す',
              icon: Icon(Icons.sync_problem, color: scheme.error),
            )
          else
            Icon(Icons.offline_pin, color: scheme.primary),
          IconButton(
            onPressed: () => _confirmDelete(context, queue),
            tooltip: 'ダウンロードを削除',
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      },
    );
  }

  Widget _cancelButton(BuildContext context, DownloadQueue queue) => IconButton(
    onPressed: () => _guard(
      context,
      what: 'ダウンロードの取り消し',
      action: () => queue.remove(volume.id),
    ),
    tooltip: 'ダウンロードを取り消す',
    icon: const Icon(Icons.close),
  );

  /// 消す前に確認する（オフラインで読めなくなる）。
  Future<void> _confirmDelete(BuildContext context, DownloadQueue queue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${volume.volume} 巻のダウンロードを削除しますか？'),
        content: const Text('端末から削除します。オフラインでは読めなくなります（サーバー上のデータは消えません）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _guard(
      context,
      what: 'ダウンロードの削除',
      action: () => queue.remove(volume.id),
    );
  }

  /// 端末内の操作なので、失敗は黙って飲み込まずその場で知らせる。
  Future<void> _guard(
    BuildContext context, {
    required String what,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } on Object catch (error) {
      if (!context.mounted) return;
      showActionFailure(context, error, what: what);
    }
  }
}
