import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/format.dart';
import '../../../../domain/models/book_detail.dart';
import '../../../downloads/application/download_queue.dart';
import '../../../downloads/application/download_settings.dart';
import '../../../downloads/domain/title_download_plan.dart';

/// タイトル単位の一括ダウンロードの確認ダイアログ（#10）。
///
/// 範囲（全巻 / 未読のみ / 最新 N 巻）を選ばせ、**積む巻数と合計容量を見せてから**
/// 実行する。1 巻数百 MB になるので、押した瞬間に全巻を積むことはしない。
///
/// 積む巻を返す（キャンセルなら `null`）。
Future<TitleDownloadPlan?> showTitleDownloadDialog(
  BuildContext context, {
  required BookDetail detail,
}) => showDialog<TitleDownloadPlan>(
  context: context,
  builder: (context) => TitleDownloadDialog(detail: detail),
);

class TitleDownloadDialog extends ConsumerStatefulWidget {
  const TitleDownloadDialog({required this.detail, super.key});

  final BookDetail detail;

  @override
  ConsumerState<TitleDownloadDialog> createState() =>
      _TitleDownloadDialogState();
}

class _TitleDownloadDialogState extends ConsumerState<TitleDownloadDialog> {
  var _scope = TitleDownloadScope.all;
  var _latestCount = latestVolumeCounts[1];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloads = ref.watch(downloadQueueProvider).value ?? const {};
    final waitingForWifi =
        ref.watch(downloadGateProvider) == DownloadGate.waitingForWifi;

    TitleDownloadPlan planOf(TitleDownloadScope scope) => planTitleDownload(
      volumes: widget.detail.volumes,
      downloads: downloads,
      scope: scope,
      latestCount: _latestCount,
    );
    final plan = planOf(_scope);

    return AlertDialog(
      title: const Text('まとめてダウンロード'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<TitleDownloadScope>(
              groupValue: _scope,
              onChanged: (scope) {
                if (scope != null) setState(() => _scope = scope);
              },
              child: Column(
                children: [
                  for (final scope in TitleDownloadScope.values)
                    RadioListTile<TitleDownloadScope>(
                      value: scope,
                      contentPadding: EdgeInsets.zero,
                      title: scope == TitleDownloadScope.latest
                          ? _LatestTitle(
                              count: _latestCount,
                              onChanged: (count) => setState(() {
                                _latestCount = count;
                                _scope = TitleDownloadScope.latest;
                              }),
                            )
                          : Text(scope.label),
                      // 選ぶ前に各範囲の量が分かるようにする。
                      subtitle: Text(_summaryOf(planOf(scope))),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (plan.skipped > 0)
              Text(
                'ダウンロード済み・取得待ちの ${plan.skipped} 巻は含みません。',
                style: theme.textTheme.bodySmall,
              ),
            if (waitingForWifi)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Wi-Fi に接続するまで待機します（設定の「Wi-Fi 接続時のみ」が ON）。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: plan.isEmpty
              ? null
              : () => Navigator.of(context).pop(plan),
          child: Text(
            plan.isEmpty
                ? 'ダウンロードする巻がありません'
                : '${plan.volumes.length} 巻をダウンロード',
          ),
        ),
      ],
    );
  }

  static String _summaryOf(TitleDownloadPlan plan) => plan.isEmpty
      ? 'ダウンロードする巻はありません'
      : '${plan.volumes.length} 巻・${formatBytes(plan.bytes)}';
}

/// 「最新 N 巻」の見出し（N をその場で選べる）。
class _LatestTitle extends StatelessWidget {
  const _LatestTitle({required this.count, required this.onChanged});

  final int count;
  final ValueChanged<int> onChanged;

  static const dropdownKey = Key('title-download-latest-count');

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('最新の '),
        DropdownButton<int>(
          key: dropdownKey,
          value: count,
          isDense: true,
          items: [
            for (final n in latestVolumeCounts)
              DropdownMenuItem(value: n, child: Text('$n')),
          ],
          onChanged: (n) {
            if (n != null) onChanged(n);
          },
        ),
        const Text(' 巻'),
      ],
    );
  }
}
