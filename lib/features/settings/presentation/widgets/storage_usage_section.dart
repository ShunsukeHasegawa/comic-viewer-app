import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/cache/image_cache_store.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/format.dart';
import '../../../downloads/application/download_storage_summary_provider.dart';
import '../../application/device_storage_provider.dart';
import 'setting_tiles.dart';

/// 使用量の内訳（ダウンロード済み・一時キャッシュ・合計・端末の空き容量）。
///
/// 「何がどれだけ使っているか」を 1 画面で見せる。ダウンロード分は台帳から
/// その場で集計するので、巻を消せばすぐに減る。
class StorageUsageSection extends ConsumerWidget {
  const StorageUsageSection({required this.usage, super.key});

  /// 一時キャッシュの使用量（DB の集計）。
  final CacheUsage usage;

  static const downloadedKey = Key('storage-usage-downloaded');
  static const partialKey = Key('storage-usage-partial');
  static const totalKey = Key('storage-usage-total');
  static const freeSpaceKey = Key('storage-usage-free-space');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(downloadStorageSummaryProvider);
    final device = ref.watch(deviceStorageProvider);
    final downloads = summary.value;
    final valueStyle = Theme.of(context).textTheme.titleMedium;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          key: downloadedKey,
          title: const Text('ダウンロード済み'),
          subtitle: Text(switch ((downloads, summary.hasError)) {
            (final downloads?, _) => '${downloads.installedVolumes} 巻',
            // 0 B と見せると「何も無い」と読めてしまうので、読めなかったと出す。
            (null, true) => 'ダウンロードの情報を読み込めませんでした',
            (null, false) => '読み込み中…',
          }),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                downloads == null ? '—' : formatBytes(downloads.installedBytes),
                style: valueStyle,
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => context.push(AppRoutes.downloadManager),
        ),
        if (downloads != null && downloads.partialBytes > 0)
          ListTile(
            key: partialKey,
            title: const Text('ダウンロード途中'),
            subtitle: const Text('完了すると「ダウンロード済み」に移ります'),
            trailing: Text(
              formatBytes(downloads.partialBytes),
              style: valueStyle,
            ),
          ),
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
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          key: totalKey,
          title: const Text('合計'),
          // ダウンロード分が分からないまま合計を出すと、実際より少なく見える。
          subtitle: downloads == null ? const Text('ダウンロード済みを含みません') : null,
          trailing: Text(
            formatBytes(usage.totalBytes + (downloads?.totalBytes ?? 0)),
            style: valueStyle,
          ),
        ),
        ListTile(
          key: freeSpaceKey,
          title: const Text('端末の空き容量'),
          trailing: Text(switch (device) {
            AsyncValue(value: final storage?) => switch (storage.totalBytes) {
              final total? =>
                '${formatBytes(storage.freeBytes)} / ${formatBytes(total)}',
              null => formatBytes(storage.freeBytes),
            },
            AsyncValue(isLoading: true) => '…',
            // 取得できない端末（プラグインが値を返さない）。
            _ => '不明',
          }, style: valueStyle),
        ),
        const SettingsNote(
          'ダウンロード済みのコミックは、下の「上限」「保持期間」による自動削除の'
          '対象外です。削除されるのは手動で削除したときと、「自動削除」を'
          'オンにしたときだけです。',
        ),
      ],
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
