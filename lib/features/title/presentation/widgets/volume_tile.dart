import 'package:flutter/material.dart';

import '../../../../core/utils/format.dart';
import '../../../../core/widgets/thumbnail_image.dart';
import '../../../../domain/models/book_detail.dart';
import '../../../library/presentation/widgets/book_tiles.dart';

/// 巻一覧の 1 行。
class VolumeTile extends StatelessWidget {
  const VolumeTile({required this.volume, required this.onOpen, super.key});

  final BookVolume volume;

  /// タップでビューアを開く。
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = volume.userStatus;

    return ListTile(
      onTap: onOpen,
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
      trailing: VolumeDownloadButton(volume: volume),
    );
  }
}

/// 巻のダウンロード操作。
///
/// ダウンロード機能そのものは #9（サーバー側は comic-viewer#7 / #8）なので、
/// ここでは状態の置き場所と導線だけ用意し、押せない状態で表示する。
class VolumeDownloadButton extends StatelessWidget {
  const VolumeDownloadButton({required this.volume, super.key});

  final BookVolume volume;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!volume.isDownloadable) {
      return Tooltip(
        message: 'この巻はダウンロードできません（アーカイブがありません）',
        child: Icon(Icons.cloud_off_outlined, color: scheme.onSurfaceVariant),
      );
    }

    return IconButton(
      // #9 でダウンロードキューに投入する。
      onPressed: null,
      tooltip: 'ダウンロード（#9 で実装）',
      icon: const Icon(Icons.download_outlined),
    );
  }
}
