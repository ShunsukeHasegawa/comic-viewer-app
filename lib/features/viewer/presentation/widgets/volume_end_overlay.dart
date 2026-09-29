import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/thumbnail_image.dart';
import '../../../../domain/models/read_volume.dart';
import '../../../library/presentation/widgets/book_tiles.dart';

/// 最終ページの次に出す巻末オーバーレイ（`files.length + 1` 枚目）。
class VolumeEndOverlay extends StatelessWidget {
  const VolumeEndOverlay({
    required this.volume,
    required this.hasNextVolume,
    required this.onNextVolume,
    required this.onClose,
    this.canOpenNextVolume = true,
    super.key,
  });

  final ReadVolume volume;

  /// 次の巻が存在するか（遷移中でも表示は変えない）。
  final bool hasNextVolume;

  /// 次の巻を開けるか（圏外で未ダウンロードなら開けない。#11）。
  ///
  /// 「次の巻が無い」と区別する。存在はするので、ダウンロードすれば読める。
  final bool canOpenNextVolume;

  /// 次の巻へ。遷移中は `null`（ボタンだけ無効になる）。
  final VoidCallback? onNextVolume;

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 「次の巻がある」と「いま押せる」は別（遷移中に案内文へ変わらないように）。
    final hasNext = hasNextVolume;

    return ColoredBox(
      color: AppColors.viewerBackground,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${volume.volume} 巻を読み終わりました',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (hasNext) ...[
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ThumbnailImage(
                      apiUrl: volume.nextVolumeThumbnail,
                      aspectRatio: bookCoverAspectRatio,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onNextVolume,
                  icon: Icon(
                    canOpenNextVolume
                        ? Icons.skip_next
                        : Icons.cloud_off_outlined,
                  ),
                  label: Text(
                    canOpenNextVolume ? '次の巻を読む' : 'オフラインでは次の巻を読めません',
                  ),
                ),
              ] else
                Text(
                  volume.book.isComplete ? 'この作品は完結しています' : '次の巻はまだありません',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('閉じる'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
