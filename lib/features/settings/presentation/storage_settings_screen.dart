import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_settings.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/error_view.dart';
import '../application/storage_settings_controller.dart';

/// ストレージ設定（キャッシュの可視化・上限・保持期間・手動削除）。
///
/// 端末の空き容量チェック（プラグインが必要）は、ダウンロード前チェックとして
/// #9 で扱うためここには置かない。
class StorageSettingsScreen extends ConsumerWidget {
  const StorageSettingsScreen({super.key});

  /// ドロップダウンのキー（テストから引きやすくする）。
  static const pageLimitKey = Key('storage-settings-page-limit');
  static const thumbnailLimitKey = Key('storage-settings-thumbnail-limit');
  static const retentionKey = Key('storage-settings-retention');

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

    return ListView(
      children: [
        const _SectionTitle('使用量'),
        _UsageTile(
          label: 'ページ画像（一時キャッシュ）',
          bytes: usage.pageBytes,
          count: usage.pageCount,
        ),
        _UsageTile(
          label: 'サムネイル（一時キャッシュ）',
          bytes: usage.thumbnailBytes,
          count: usage.thumbnailCount,
        ),
        // ダウンロード済み容量の集計は #9 / #13。枠だけ先に用意する。
        const ListTile(
          title: Text('ダウンロード済み'),
          subtitle: Text('#9 で実装予定（一時キャッシュとは別に管理します）'),
          trailing: Text('—'),
        ),
        ListTile(
          title: const Text('一時キャッシュ合計'),
          trailing: Text(
            formatBytes(usage.totalBytes),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Divider(),

        const _SectionTitle('上限'),
        _ChoiceTile<CacheLimit>(
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
        _ChoiceTile<CacheLimit>(
          dropdownKey: StorageSettingsScreen.thumbnailLimitKey,
          title: 'サムネイルの上限',
          subtitle: '小さく数が多いので、ページ画像とは別枠です',
          value: settings.thumbnailLimit,
          values: CacheLimit.values,
          labelOf: (limit) => limit.label,
          onChanged: (limit) =>
              _update(context, ref, settings.copyWith(thumbnailLimit: limit)),
        ),
        _ChoiceTile<CacheRetention>(
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

        const _SectionTitle('削除'),
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
    if (error != null) {
      showActionFailure(context, error, what: 'キャッシュの削除');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _UsageTile extends StatelessWidget {
  const _UsageTile({
    required this.label,
    required this.bytes,
    required this.count,
  });

  final String label;
  final int bytes;
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text('$count 件'),
      trailing: Text(
        formatBytes(bytes),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

/// 選択肢を 1 つ選ぶ設定項目。
class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.dropdownKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  final Key dropdownKey;
  final String title;
  final String subtitle;
  final T value;
  final List<T> values;
  final String Function(T value) labelOf;
  final void Function(T value) onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<T>(
        key: dropdownKey,
        value: value,
        items: [
          for (final candidate in values)
            DropdownMenuItem<T>(
              value: candidate,
              child: Text(labelOf(candidate)),
            ),
        ],
        onChanged: (selected) {
          if (selected == null || selected == value) return;
          onChanged(selected);
        },
      ),
    );
  }
}
