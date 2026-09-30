import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/format.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../downloads/application/auto_delete_runner.dart';
import '../../../downloads/application/auto_delete_settings.dart';
import '../../application/device_storage_provider.dart';
import 'setting_tiles.dart';

/// ダウンロード済みの巻の自動削除（#13）。既定はすべてオフ。
class AutoDeleteSection extends ConsumerWidget {
  const AutoDeleteSection({super.key});

  static const finishedKey = Key('storage-settings-auto-delete-finished');
  static const lowSpaceKey = Key('storage-settings-auto-delete-low-space');
  static const lastResultKey = Key('storage-settings-auto-delete-last');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(autoDeleteSettingsControllerProvider);
    final device = ref.watch(deviceStorageProvider);
    final last = ref.watch(autoDeleteLastResultProvider).value;

    // 読めないうちは選ばせない（既定のオフを見せて押させると、読み込み後に
    // 押したのと違う値へ戻ったように見える）。
    final loaded = async.hasValue;
    final settings = async.value ?? const AutoDeleteSettings();
    // 測り終えて「分からない」と決まったときだけ使えなくする（測っている
    // 最中に一瞬「使えません」と出さない）。
    final spaceUnknown = !device.isLoading && device.value == null;
    // 使えない端末でも、すでにオンになっている設定はオフに戻せるようにする。
    final lowSpaceSelectable =
        loaded && (!spaceUnknown || settings.lowSpace != LowSpaceThreshold.off);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!loaded && async.hasError)
          ListTile(
            leading: Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('自動削除の設定を読み込めませんでした'),
            trailing: TextButton(
              onPressed: () =>
                  ref.invalidate(autoDeleteSettingsControllerProvider),
              child: const Text('再試行'),
            ),
          ),
        SettingChoiceTile<FinishedRetention>(
          dropdownKey: finishedKey,
          title: '読了した巻を削除',
          subtitle: '読み終えて（最後に開いてから）この期間が過ぎた巻を削除します。読書中の巻は削除しません',
          value: settings.finished,
          values: FinishedRetention.values,
          labelOf: (value) => value.label,
          onChanged: loaded
              ? (value) =>
                    _save(context, ref, settings.copyWith(finished: value))
              : null,
        ),
        SettingChoiceTile<LowSpaceThreshold>(
          dropdownKey: lowSpaceKey,
          title: '空き容量が少ないとき',
          subtitle: spaceUnknown
              ? 'この端末では空き容量を取得できないため使えません'
              : 'この端末で開いた巻を、最後に読んだのが古い順に削除します。ダウンロードしてからまだ開いていない巻は削除しません',
          value: settings.lowSpace,
          values: LowSpaceThreshold.values,
          labelOf: (value) => value.label,
          onChanged: lowSpaceSelectable
              ? (value) =>
                    _save(context, ref, settings.copyWith(lowSpace: value))
              : null,
        ),
        if (last != null)
          ListTile(
            key: lastResultKey,
            title: const Text('前回の自動削除'),
            subtitle: Text(
              '${formatDateTime(last.at)}・${last.volumes} 巻'
              '（${formatBytes(last.bytes)}）',
            ),
          ),
      ],
    );
  }

  /// 保存してから、その場で新しい設定を適用する（「上限を下げたらその場で
  /// 掃除」と同じ扱い）。消した結果は SnackBar で知らせる。
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    AutoDeleteSettings next,
  ) async {
    // どちらも keepAlive なので、画面を離れても await の後に使ってよい。
    final controller = ref.read(autoDeleteSettingsControllerProvider.notifier);
    final runner = ref.read(autoDeleteRunnerProvider.notifier);
    try {
      await controller.set(next);
    } on Object catch (error) {
      if (!context.mounted) return;
      showActionFailure(context, error, what: '自動削除の設定の保存');
      return;
    }

    final AutoDeleteResult? result;
    try {
      result = await runner.run(AutoDeleteTrigger.settingsChanged);
    } on Object catch (error) {
      if (!context.mounted) return;
      // 設定は保存できている（次の起動 / 復帰でやり直される）。
      showActionFailure(context, error, what: '自動削除');
      return;
    }
    if (!context.mounted) return;
    final message = result == null
        ? '自動削除の設定を保存しました'
        : '自動削除: ${result.volumes} 巻（${formatBytes(result.bytes)}）を削除しました';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
