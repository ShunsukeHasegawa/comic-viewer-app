import 'package:flutter/material.dart';

import '../../../../core/utils/format.dart';
import '../../domain/download_manager_view.dart';
import '../../domain/volume_download.dart';
import 'download_progress_tile.dart';

/// ダウンロード済みの巻の状態の文言。
String downloadedLabelOf(DownloadEntry entry) {
  final download = entry.download;
  if (entry.isRefetch) {
    return download.status == VolumeDownloadStatus.downloading
        ? '更新を取得中 ${download.percent}%'
        : '更新の取得待ち';
  }
  // 取り直しの途中でアプリが落ちた行。旧世代は読める。
  if (download.status == VolumeDownloadStatus.paused) return '更新を中断中';
  if (entry.refetchFailed) return '更新の取得に失敗: ${download.failureReason}';
  if (entry.isOutdated) return '更新あり';
  return 'ダウンロード済み';
}

/// タイトル見出しのメニュー。
enum DownloadedTitleAction { refetchOutdated, openTitle, deleteTitle }

/// ダウンロード済みの 1 タイトル（見出し + 巻の行）。
///
/// [selection] が `null` でなければ複数選択の最中（行にチェックボックスを出し、
/// タップは選択の切り替えになる）。
class DownloadedTitleGroupView extends StatefulWidget {
  const DownloadedTitleGroupView({
    required this.group,
    required this.selection,
    required this.onToggleVolume,
    required this.onToggleGroup,
    required this.onOpenVolume,
    required this.onStartSelection,
    required this.onRefetchVolume,
    required this.onDeleteVolume,
    required this.onTitleAction,
    this.enabled = true,
    super.key,
  });

  final DownloadedTitleGroup group;
  final Set<int>? selection;
  final bool enabled;

  final void Function(int volumeId) onToggleVolume;

  /// 見出しのチェック。`true` なら配下の巻をすべて選ぶ、`false` なら外す。
  final void Function(bool select) onToggleGroup;

  final void Function(DownloadEntry entry) onOpenVolume;

  /// 長押しで複数選択に入る（押した巻を選んだ状態で）。
  final void Function(DownloadEntry entry) onStartSelection;
  final void Function(DownloadEntry entry) onRefetchVolume;
  final void Function(DownloadEntry entry) onDeleteVolume;
  final void Function(DownloadedTitleAction action) onTitleAction;

  @override
  State<DownloadedTitleGroupView> createState() =>
      _DownloadedTitleGroupViewState();
}

class _DownloadedTitleGroupViewState extends State<DownloadedTitleGroupView> {
  var _expanded = true;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final selection = widget.selection;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: selection == null
              ? DownloadThumbnail(apiUrl: group.thumbnail)
              : Checkbox(
                  tristate: true,
                  value: _groupValue(selection),
                  onChanged: widget.enabled
                      // 一部だけ選んでいるときに押したら「全部選ぶ」にする。
                      ? (_) =>
                            widget.onToggleGroup(_groupValue(selection) != true)
                      : null,
                ),
          title: Text(group.titleLabel, style: theme.textTheme.titleSmall),
          subtitle: Text(
            [
              '${group.volumes.length} 巻',
              formatBytes(group.bytes),
              if (group.outdatedCount > 0) '更新あり ${group.outdatedCount}',
            ].join('・'),
            style: theme.textTheme.bodySmall,
          ),
          onTap: () => setState(() => _expanded = !_expanded),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selection == null)
                PopupMenuButton<DownloadedTitleAction>(
                  enabled: widget.enabled,
                  tooltip: 'タイトルの操作',
                  onSelected: widget.onTitleAction,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: DownloadedTitleAction.refetchOutdated,
                      enabled: group.outdatedCount > 0,
                      child: const Text('更新をまとめて取得'),
                    ),
                    const PopupMenuItem(
                      value: DownloadedTitleAction.openTitle,
                      child: Text('タイトルを開く'),
                    ),
                    const PopupMenuItem(
                      value: DownloadedTitleAction.deleteTitle,
                      child: Text('このタイトルを削除'),
                    ),
                  ],
                ),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
        ),
        if (_expanded)
          for (final entry in group.volumes)
            _VolumeRow(
              entry: entry,
              selection: selection,
              enabled: widget.enabled,
              onToggle: () => widget.onToggleVolume(entry.volumeId),
              onOpen: () => widget.onOpenVolume(entry),
              onLongPress: () => widget.onStartSelection(entry),
              onRefetch: () => widget.onRefetchVolume(entry),
              onDelete: () => widget.onDeleteVolume(entry),
            ),
      ],
    );
  }

  bool? _groupValue(Set<int> selection) {
    final selected = widget.group.volumes
        .where((entry) => selection.contains(entry.volumeId))
        .length;
    if (selected == 0) return false;
    if (selected == widget.group.volumes.length) return true;
    return null;
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.entry,
    required this.selection,
    required this.enabled,
    required this.onToggle,
    required this.onOpen,
    required this.onLongPress,
    required this.onRefetch,
    required this.onDelete,
  });

  final DownloadEntry entry;
  final Set<int>? selection;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final VoidCallback onRefetch;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selection = this.selection;
    final selecting = selection != null;
    final download = entry.download;
    // 取り直しを積み直せるのは、更新がある / 取り直しに失敗した巻だけ
    // （取得中のものを二重に積まない）。
    final canRefetch =
        download.isCompleted && (entry.isOutdated || entry.refetchFailed);

    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 32, end: 16),
      enabled: enabled,
      leading: selecting
          ? Checkbox(
              value: selection.contains(entry.volumeId),
              onChanged: enabled ? (_) => onToggle() : null,
            )
          : DownloadThumbnail(apiUrl: entry.thumbnail),
      title: Text(entry.volumeLabel),
      subtitle: Text(
        [formatBytes(download.totalBytes), downloadedLabelOf(entry)].join('・'),
        style: theme.textTheme.bodySmall,
      ),
      // 圏外でも読める（端末の ZIP から開く）。
      onTap: selecting ? onToggle : onOpen,
      onLongPress: selecting ? null : onLongPress,
      trailing: selecting
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canRefetch)
                  IconButton(
                    onPressed: enabled ? onRefetch : null,
                    tooltip: entry.refetchFailed
                        ? '更新の取得に失敗しました。もう一度試す'
                        : '更新を取得',
                    icon: Icon(
                      Icons.sync_problem,
                      color: theme.colorScheme.error,
                    ),
                  ),
                IconButton(
                  onPressed: enabled ? onDelete : null,
                  tooltip: 'ダウンロードを削除',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
    );
  }
}
