import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cache/cache_settings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../downloads/application/download_settings.dart';
import '../../downloads/application/download_storage_summary_provider.dart';
import '../application/clear_all_data.dart';
import '../application/device_storage_provider.dart';
import '../application/storage_settings_controller.dart';
import 'widgets/auto_delete_section.dart';
import 'widgets/setting_tiles.dart';
import 'widgets/storage_usage_section.dart';

/// ストレージ設定（使用量の内訳・キャッシュの上限・保持期間・ダウンロードの
/// 自動削除・手動削除）。
class StorageSettingsScreen extends ConsumerWidget {
  const StorageSettingsScreen({super.key});

  /// ドロップダウンのキー（テストから引きやすくする）。
  static const pageLimitKey = Key('storage-settings-page-limit');
  static const thumbnailLimitKey = Key('storage-settings-thumbnail-limit');
  static const retentionKey = Key('storage-settings-retention');
  static const wifiOnlyKey = Key('storage-settings-wifi-only');
  static const manageDownloadsKey = Key('storage-settings-manage-downloads');
  static const clearAllKey = Key('storage-settings-clear-all');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storageSettingsControllerProvider);
    final controller = ref.read(storageSettingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('ストレージ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '使用量を再計算',
            onPressed: () => _refresh(context, ref),
          ),
        ],
      ),
      body: switch ((async.value, async.error)) {
        (null, final error?) => ErrorView(
          error: error,
          onRetry: controller.refresh,
        ),
        (null, null) => const Center(child: CircularProgressIndicator()),
        (final state?, _) => _Body(state: state),
      },
    );
  }
}

/// 使用量を取り直し、失敗したらその場で知らせる。
Future<void> _refresh(BuildContext context, WidgetRef ref) async {
  // 空き容量は投げないので、キャッシュの集計と並べて測り直す。
  ref.invalidate(deviceStorageProvider);
  final error = await ref
      .read(storageSettingsControllerProvider.notifier)
      .refresh();
  if (error == null || !context.mounted) return;
  showRefreshFailure(context, error, what: 'ストレージの使用量');
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final StorageSettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = state.usage;
    final settings = state.settings;
    final errorColor = Theme.of(context).colorScheme.error;

    return ListView(
      children: [
        const SettingsSectionTitle('使用量'),
        StorageUsageSection(usage: usage),
        const Divider(),

        const SettingsSectionTitle('上限'),
        const SettingsNote('一時キャッシュのみが対象です。ダウンロード済みのコミックは対象外です。'),
        SettingChoiceTile<CacheLimit>(
          dropdownKey: StorageSettingsScreen.pageLimitKey,
          title: 'ページ画像の上限',
          // ページは 1 枚 1MB 超になるため、サムネイルとは別枠で管理する。
          subtitle: '上限を超えると、最後に読んだのが古いものから削除されます',
          value: settings.pageLimit,
          values: CacheLimit.values,
          labelOf: (limit) => limit.label,
          onChanged: (limit) =>
              _update(context, ref, settings.copyWith(pageLimit: limit)),
        ),
        SettingChoiceTile<CacheLimit>(
          dropdownKey: StorageSettingsScreen.thumbnailLimitKey,
          title: 'サムネイルの上限',
          subtitle: '小さく数が多いので、ページ画像とは別枠です',
          value: settings.thumbnailLimit,
          values: CacheLimit.values,
          labelOf: (limit) => limit.label,
          onChanged: (limit) =>
              _update(context, ref, settings.copyWith(thumbnailLimit: limit)),
        ),
        SettingChoiceTile<CacheRetention>(
          dropdownKey: StorageSettingsScreen.retentionKey,
          title: '保持期間',
          subtitle: '最後に使ってからこの期間を過ぎたものは削除されます',
          value: settings.retention,
          values: CacheRetention.values,
          labelOf: (retention) => retention.label,
          onChanged: (retention) =>
              _update(context, ref, settings.copyWith(retention: retention)),
        ),
        const Divider(),

        const SettingsSectionTitle('ダウンロード'),
        const _WifiOnlyTile(),
        ListTile(
          key: StorageSettingsScreen.manageDownloadsKey,
          leading: const Icon(Icons.download_done_outlined),
          title: const Text('ダウンロードを管理'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.downloadManager),
        ),
        const Divider(),

        const SettingsSectionTitle('自動削除（ダウンロード済み）'),
        const AutoDeleteSection(),
        const Divider(),

        const SettingsSectionTitle('削除'),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('キャッシュを削除'),
          subtitle: const Text('ダウンロード済みのコミックは削除されません'),
          onTap: () => _confirmClear(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: const Text('サムネイルだけ削除'),
          subtitle: const Text('表紙の一覧を作り直します（ページ画像は残ります）'),
          onTap: () => _clear(
            context,
            ref,
            kind: CachedImageKind.thumbnail,
            done: 'サムネイルのキャッシュを削除しました',
          ),
        ),
        ListTile(
          key: StorageSettingsScreen.clearAllKey,
          leading: Icon(Icons.delete_forever_outlined, color: errorColor),
          title: Text('すべてのデータを削除', style: TextStyle(color: errorColor)),
          subtitle: const Text(
            'ダウンロード済みのコミックと一時キャッシュを削除します'
            '（読書進捗・設定・ログイン状態は残ります）',
          ),
          onTap: () => _confirmClearAll(context, ref),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Text(
            '一時キャッシュは読んだ画像を自動でためておく領域です。'
            '削除しても、ダウンロード済みのコミックとサーバー上のデータには影響しません。',
          ),
        ),
      ],
    );
  }

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    CacheSettings settings,
  ) async {
    final controller = ref.read(storageSettingsControllerProvider.notifier);
    final error = await controller.updateSettings(settings);
    if (!context.mounted) return;
    if (error != null) {
      showActionFailure(context, error, what: 'キャッシュの設定の保存');
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('キャッシュの設定を保存しました')));
  }

  /// 消す前に確認する（一度消すと取り返せない = 再ダウンロードになる）。
  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('キャッシュを削除しますか？'),
        content: const Text(
          '閲覧した画像の一時キャッシュ（ページ画像とサムネイル）を削除します。\n'
          'ダウンロード済みのコミックは削除されません。',
        ),
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
    await _clear(context, ref, done: 'キャッシュを削除しました');
  }

  Future<void> _clear(
    BuildContext context,
    WidgetRef ref, {
    required String done,
    CachedImageKind? kind,
  }) async {
    final controller = ref.read(storageSettingsControllerProvider.notifier);
    final error = await controller.clearCache(kind: kind);
    if (!context.mounted) return;
    // キャッシュが空けた分を空き容量の表示にも反映する。
    ref.invalidate(deviceStorageProvider);
    if (error != null) {
      showActionFailure(context, error, what: 'キャッシュの削除');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
  }

  /// 「すべてのデータを削除」。何が消えて何が残るかを示してから消す
  /// （数 GB のダウンロードの取り直しになるため）。
  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final downloads = ref.read(downloadStorageSummaryProvider).value;
    final cache = formatBytes(state.usage.totalBytes);
    final target = downloads == null
        ? 'ダウンロード済みのコミックと一時キャッシュ（$cache）'
        : 'ダウンロード済み ${downloads.installedVolumes} 巻'
              '（${formatBytes(downloads.totalBytes)}）と一時キャッシュ（$cache）';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('すべてのデータを削除しますか？'),
          content: Text(
            '$targetを削除します。ダウンロード中のものも取り消します。\n'
            '読書進捗・設定・ログイン状態は残ります。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    // keepAlive なので、画面を離れても削除は最後まで走らせる。
    final clearAll = ref.read(clearAllDataProvider);
    final controller = ref.read(storageSettingsControllerProvider.notifier);
    final error = await clearAll();
    // 一部が失敗しても消えた分はあるので、表示は必ず取り直す。
    await controller.refresh();
    if (!context.mounted) return;
    ref.invalidate(deviceStorageProvider);
    if (error != null) {
      showActionFailure(context, error, what: 'データの削除');
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('すべてのデータを削除しました')));
  }
}

/// 「Wi-Fi 接続時のみダウンロード」（#10）。
///
/// キャッシュの設定とは保存先も読み込みも別なので、自分で watch する
/// （キャッシュの使用量の再計算を待たずに切り替えられる）。
class _WifiOnlyTile extends ConsumerWidget {
  const _WifiOnlyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(downloadWifiOnlyProvider);
    return SwitchListTile(
      key: StorageSettingsScreen.wifiOnlyKey,
      title: const Text('Wi-Fi 接続時のみダウンロード'),
      subtitle: const Text('モバイル回線に切り替わると一時停止し、Wi-Fi に戻ると続きから再開します'),
      // 読み込み中は操作させない（既定値を表示して押させると、読み込み後に
      // 押したのと逆の値へ戻ったように見える）。読めなかったときは既定（ON。
      // キューもそう扱う）を見せたうえで、保存し直せるようにしておく。
      value: setting.value ?? true,
      onChanged: setting.isLoading
          ? null
          : (value) async {
              try {
                await ref.read(downloadWifiOnlyProvider.notifier).set(value);
              } on Object catch (error) {
                if (!context.mounted) return;
                showActionFailure(context, error, what: 'ダウンロードの設定の保存');
              }
            },
    );
  }
}
