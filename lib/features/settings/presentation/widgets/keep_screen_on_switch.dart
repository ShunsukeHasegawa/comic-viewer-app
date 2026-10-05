import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_view.dart';
import '../../application/keep_screen_on_setting.dart';

/// 「読書中は画面を消さない」の切り替え（#19）。
class KeepScreenOnSwitch extends ConsumerWidget {
  const KeepScreenOnSwitch({super.key});

  static const switchKey = Key('keep-screen-on-switch');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final setting = ref.watch(keepScreenOnSettingProvider);
    // 読めなかったときは、ビューアが実際に使う既定（ON）を見せたうえで
    // 切り替えられるようにする（保存できればそれで直る）。
    final failedToLoad = setting.hasError && !setting.hasValue;

    return SwitchListTile(
      key: switchKey,
      secondary: const Icon(Icons.light_mode_outlined),
      title: const Text('読書中は画面を消さない'),
      subtitle: Text(
        failedToLoad
            ? '設定を読み込めませんでした。読書中は画面を消さずに表示します。'
            // 一覧などほかの画面では端末の消灯時間のままなので、それと分かるように。
            : 'ビューアで読んでいる間だけ、端末の自動消灯を止めます',
        style: failedToLoad ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      value: setting.value ?? true,
      // 読み込み中は操作させない（既定を表示して押させると、読み込み後に
      // 押したのと違う値へ戻ったように見える）。
      onChanged: setting.isLoading
          ? null
          : (value) => _toggle(context, ref, value),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool value) async {
    try {
      await ref.read(keepScreenOnSettingProvider.notifier).set(value);
    } on Object catch (error) {
      if (!context.mounted) return;
      showActionFailure(context, error, what: '画面の消灯の設定の保存');
    }
  }
}
