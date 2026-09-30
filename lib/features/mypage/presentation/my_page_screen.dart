import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/error_view.dart';
import '../../../domain/models/reading_book.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../downloads/application/download_queue.dart';
import '../../downloads/domain/volume_download.dart';
import '../application/stats_controller.dart';

/// マイページ（ユーザー情報・読書統計・設定入口）。
class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final stats = ref.watch(statsControllerProvider);
    // 件数と容量だけを select する（進捗が届くたびにマイページを描き直さない）。
    final downloads = ref.watch(
      downloadQueueProvider.select((ledger) => _downloadSummary(ledger.value)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: RefreshIndicator(
        onRefresh: () => _refreshStats(context, ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (user != null)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(user.name.isEmpty ? 'ユーザー' : user.name),
                subtitle: user.email == null ? null : Text(user.email!),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    if (user.isAdmin) const Chip(label: Text('管理者')),
                    if (user.safeMode) const Chip(label: Text('セーフモード')),
                  ],
                ),
              ),
            const Divider(),
            _StatsSection(stats: stats),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.sd_storage_outlined),
              title: const Text('ストレージ'),
              subtitle: const Text('キャッシュの使用量・上限・削除'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.storageSettings),
            ),
            ListTile(
              leading: const Icon(Icons.download_for_offline_outlined),
              title: const Text('ダウンロード'),
              subtitle: Text(switch (downloads) {
                null => 'ダウンロードしたコミックの管理',
                (installed: 0, bytes: _, active: 0) => 'ダウンロードしたコミックはありません',
                (:final installed, :final bytes, :final active) => [
                  '$installed 巻・${formatBytes(bytes)}',
                  if (active > 0) '（進行中 $active）',
                ].join(),
              }),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.downloadManager),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('ログアウト'),
              onTap: () => _confirmLogout(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウトしますか？'),
        content: const Text('この端末にダウンロードしたコミックと読書進捗は削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // ダイアログを閉じる間に画面が破棄されていることがある。
    if (!context.mounted) return;

    try {
      await ref.read(authControllerProvider.notifier).logout();
    } on Object {
      // 端末内データの削除に失敗した場合など。黙って失敗させない。
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログアウトに失敗しました。もう一度お試しください。')),
      );
    }
  }
}

/// マイページの「ダウンロード」に出す件数（台帳を読み終えるまでは `null`）。
///
/// 容量はダウンロード管理画面・ストレージ設定と同じ規則（読める巻の
/// totalBytes）で数える。画面ごとに数字が食い違わないようにするため。
({int installed, int bytes, int active})? _downloadSummary(
  Map<int, VolumeDownload>? ledger,
) {
  if (ledger == null) return null;
  var installed = 0;
  var bytes = 0;
  var active = 0;
  for (final download in ledger.values) {
    if (download.hasInstalledArchive) {
      installed++;
      bytes += download.totalBytes;
    }
    if (download.isActive || download.status == VolumeDownloadStatus.paused) {
      active++;
    }
  }
  return (installed: installed, bytes: bytes, active: active);
}

/// 統計を取り直し、失敗したらその場で知らせる。
Future<void> _refreshStats(BuildContext context, WidgetRef ref) async {
  await ref.read(statsControllerProvider.notifier).refresh();
  final error = ref.read(statsControllerProvider).error;
  if (error == null || !context.mounted) return;
  showRefreshFailure(context, error, what: '読書統計');
}

class _StatsSection extends ConsumerWidget {
  const _StatsSection({required this.stats});

  final AsyncValue<UserStats> stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('読書統計', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          switch ((stats.value, stats.error)) {
            (null, final error?) => ErrorView(
              error: error,
              onRetry: ref.read(statsControllerProvider.notifier).refresh,
            ),
            (null, null) => const Center(child: CircularProgressIndicator()),
            (final stats?, _) => _StatsContent(stats: stats),
          },
        ],
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = stats.monthly.fold<int>(
      0,
      (max, month) => month.count > max ? month.count : max,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatCard(label: '読了タイトル', value: '${stats.titlesCompleted}'),
            const SizedBox(width: 12),
            _StatCard(label: '読了巻数', value: '${stats.volumesCompleted}'),
          ],
        ),
        if (stats.monthly.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('月別の読了数', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final month in stats.monthly)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      formatYearMonth(month.month),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: maxCount == 0 ? 0 : month.count / maxCount,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${month.count}',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}
