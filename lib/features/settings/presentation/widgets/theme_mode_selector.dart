import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_view.dart';
import '../../application/theme_mode_setting.dart';

/// 表示テーマ（ライト / ダーク / システムに合わせる）の切り替え（#17）。
///
/// 3 択を一度に見せて 1 タップで切り替えられるよう、ダイアログではなく
/// SegmentedButton にする（選んだ結果がその場で画面全体に反映されて確かめられる）。
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  static const buttonKey = Key('theme-mode-selector');

  static String labelOf(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'システム',
    ThemeMode.light => 'ライト',
    ThemeMode.dark => 'ダーク',
  };

  static IconData _iconOf(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.brightness_auto_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final setting = ref.watch(themeModeSettingProvider);
    // 読めなかったときは、アプリが実際に使っている既定（システムに合わせる）を
    // 見せたうえで選び直せるようにする（保存できればそれで直る）。
    final failedToLoad = setting.hasError && !setting.hasValue;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Text('テーマ', style: theme.textTheme.bodyLarge),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            key: buttonKey,
            // 幅いっぱいに広げる（3 つの文言が狭い端末でも切れないように）。
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: [
              for (final mode in ThemeMode.values)
                ButtonSegment(
                  value: mode,
                  icon: Icon(_iconOf(mode)),
                  label: Text(labelOf(mode)),
                ),
            ],
            selected: {setting.value ?? ThemeMode.system},
            // 読み込み中は操作させない（既定を表示して押させると、読み込み後に
            // 押したのと違う値へ戻ったように見える）。
            onSelectionChanged: setting.isLoading
                ? null
                : (selected) => _select(context, ref, selected.single),
          ),
          const SizedBox(height: 6),
          Text(
            failedToLoad
                ? 'テーマの設定を読み込めませんでした。端末の設定に合わせて表示しています。'
                : '「システム」は端末のライト / ダークの設定に合わせます。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: failedToLoad
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    ThemeMode mode,
  ) async {
    try {
      await ref.read(themeModeSettingProvider.notifier).set(mode);
    } on Object catch (error) {
      if (!context.mounted) return;
      showActionFailure(context, error, what: 'テーマの設定の保存');
    }
  }
}
