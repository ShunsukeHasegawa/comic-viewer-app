import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/open_volume.dart';
import '../../../../core/widgets/thumbnail_image.dart';
import '../../../title/application/book_detail_controller.dart';
import '../../../viewer/application/resume_reading_prompt.dart';
import '../../../viewer/data/open_volume_store.dart';

/// 前回、読んでいる途中で終了させられていたら、起動直後のホームで続きを
/// 読むか尋ねる。
class ResumeReadingPromptListener extends ConsumerStatefulWidget {
  const ResumeReadingPromptListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ResumeReadingPromptListener> createState() =>
      _ResumeReadingPromptListenerState();
}

class _ResumeReadingPromptListenerState
    extends ConsumerState<ResumeReadingPromptListener> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      resumeReadingPromptProvider,
      (_, next) => _ask(next.value),
      fireImmediately: true,
    );
  }

  void _ask(OpenVolume? volume) {
    if (volume == null) return;
    // `fireImmediately` だと initState（ビルド中）に呼ばれる。その間は
    // provider を変えられず、ダイアログも積めないので次のフレームに回す。
    WidgetsBinding.instance.addPostFrameCallback((_) => _askAfterFrame(volume));
  }

  Future<void> _askAfterFrame(OpenVolume volume) async {
    if (!mounted) return;
    // 尋ねるのはプロセスごとに 1 回（ホームへ戻るたびに出さない）。
    ref.read(resumeReadingPromptProvider.notifier).dismiss();
    final store = ref.read(openVolumeStoreProvider);
    // 起動時に読んだ後、ログアウト / safe_mode の変更で捨てられていたら
    // 尋ねない（前のユーザーの本や、見せられなくなったタイトルを出さない）。
    final current = await store.read().catchError((Object _) => null);
    if (!mounted || current?.volumeId != volume.volumeId) return;
    // 先に別の画面へ移っていたら（通知のタップなど）割り込まない。控えも
    // 捨てる（残すと次の起動で 2 回前の巻を尋ねる）。
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      await store.clear().catchError((Object _) {});
      return;
    }
    // サムネイルのために取る詳細を、「続きを読む」で開く詳細画面まで
    // 持ち越す（自宅サーバーに同じ詳細を 2 回取りに行かない）。
    final detail = ref.listenManual(
      bookDetailControllerProvider(volume.bookId),
      (_, _) {},
    );
    try {
      final resume = await showDialog<bool>(
        context: context,
        // 外のタップで閉じない（誤タップで「断った」ことにしない）。
        barrierDismissible: false,
        builder: (context) => ResumeReadingDialog(volume: volume),
      );
      if (!mounted) return;
      switch (resume) {
        case true:
          // 控えは開いたビューアが書き直す。
          pushVolumeViaTitle(
            context,
            bookId: volume.bookId,
            volumeId: volume.volumeId,
          );
          // 詳細画面が購読し始めてから手放す。
          await WidgetsBinding.instance.endOfFrame;
        case false:
          // 断られたら次の起動でも尋ねない。消せなくても次の起動で尋ねるだけ。
          await store.clear().catchError((Object _) {});
        case null:
        // 戻るボタンで閉じた。選んではいないので、次の起動でまた尋ねる。
      }
    } finally {
      detail.close();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 続きを読むか尋ねるダイアログ。「続きを読む」なら `true` で閉じる。
class ResumeReadingDialog extends ConsumerWidget {
  const ResumeReadingDialog({required this.volume, super.key});

  final OpenVolume volume;

  static const _thumbnailWidth = 64.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // 巻のサムネイルの URL は詳細にしか無い（`?m=` 付きで返るものを使い、
    // 組み立てない）。届くまではプレースホルダのまま。
    final volumes =
        ref
            .watch(bookDetailControllerProvider(volume.bookId))
            .value
            ?.detail
            .volumes ??
        const [];
    final thumbnail = [
      for (final v in volumes)
        if (v.id == volume.volumeId) v.thumbnail,
    ].firstOrNull;

    // AlertDialog は使わない。本文の Column が高さいっぱいに伸び、テーマで
    // 横幅いっぱいになる FilledButton がボタンを縦に積んでしまう。
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('続きを読みますか？', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _thumbnailWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: ThumbnailImage(
                      apiUrl: thumbnail,
                      aspectRatio: 2 / 3,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        volume.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${volume.volume} 巻',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.history,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '前回読んでいた途中です',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('閉じる'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('続きを読む'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
