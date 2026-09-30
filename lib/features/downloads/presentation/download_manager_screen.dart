import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../offline/application/offline_metadata_gateway.dart';
import '../application/download_manager_controller.dart';
import '../application/download_queue.dart';
import '../application/download_settings.dart';
import '../domain/download_manager_view.dart';
import '../domain/volume_download.dart';
import 'widgets/delete_downloads_dialog.dart';
import 'widgets/download_progress_tile.dart';
import 'widgets/downloaded_title_group.dart';

/// ダウンロード管理（進行中 / 失敗 / ダウンロード済み。#13）。
///
/// 台帳（`downloadQueueProvider`）が正。タイトル名や巻数は端末の控えから
/// 重ねるだけなので、控えが読めなくても行は台帳だけで描く。
class DownloadManagerScreen extends ConsumerStatefulWidget {
  const DownloadManagerScreen({super.key});

  @override
  ConsumerState<DownloadManagerScreen> createState() =>
      _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends ConsumerState<DownloadManagerScreen> {
  /// 複数選択の最中なら選んだ巻 ID。`null` は通常表示。
  ///
  /// 画面のローカル状態（離れたら捨てる）。台帳から消えた巻は
  /// [_effectiveSelection] で自動的に外す。
  Set<int>? _selection;

  /// 削除の進み具合（実行中でなければ `null`）。
  ({int done, int total})? _deleting;

  bool get _busy => _deleting != null;

  /// 走っている「更新を確認」（無ければ `null`）。
  Future<void>? _checking;

  @override
  Widget build(BuildContext context) {
    final ledgerAsync = ref.watch(downloadQueueProvider);
    final titlesAsync = ref.watch(downloadManagerTitlesProvider);
    final waitingForWifi =
        ref.watch(downloadGateProvider) == DownloadGate.waitingForWifi;

    final ledger = ledgerAsync.value;
    if (ledger == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('ダウンロード'),
        ),
        body: switch (ledgerAsync.error) {
          final error? => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(downloadQueueProvider),
          ),
          null => const Center(child: CircularProgressIndicator()),
        },
      );
    }

    final catalog = titlesAsync.value;
    final view = buildDownloadManagerView(
      ledger: ledger,
      titles: catalog?.titles ?? const {},
    );
    final selection = _effectiveSelection(view);
    // 読み込み自体の失敗（AsyncError）と、一部のタイトルだけの失敗の両方。
    final titlesError =
        titlesAsync.error ??
        (catalog?.hasFailure ?? false ? catalog!.error : null);

    return Scaffold(
      appBar: selection == null
          ? _normalAppBar(view)
          : _selectionAppBar(view, selection),
      body: RefreshIndicator(
        onRefresh: _checkUpdates,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (titlesError != null)
              MaterialBanner(
                content: const Text('タイトル名を読み込めませんでした（ID で表示しています）'),
                leading: const Icon(Icons.error_outline),
                actions: [
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(downloadManagerTitlesProvider),
                    child: const Text('再試行'),
                  ),
                ],
              ),
            if (view.isEmpty)
              ..._emptyMessage(context)
            else ...[
              _summary(context, view),
              if (waitingForWifi &&
                  view.inProgress.any((entry) => entry.download.isActive))
                const ListTile(
                  leading: Icon(Icons.wifi_off_outlined),
                  title: Text('Wi-Fi に接続すると自動で再開します'),
                  subtitle: Text('「Wi-Fi 接続時のみダウンロード」が オン です'),
                ),
              if (view.inProgress.isNotEmpty) ...[
                _SectionTitle('進行中（${view.inProgress.length}）'),
                for (final entry in view.inProgress)
                  DownloadProgressTile(
                    key: ValueKey('progress-${entry.volumeId}'),
                    entry: entry,
                    waitingForWifi: waitingForWifi,
                    enabled: !_busy,
                    onPause: () => _run(
                      what: 'ダウンロードの中断',
                      action: (queue) => queue.pause(entry.volumeId),
                    ),
                    onResume: () => _run(
                      what: 'ダウンロードの再開',
                      action: (queue) => queue.resume(entry.volumeId),
                    ),
                    onCancel: () => _run(
                      what: 'ダウンロードの取り消し',
                      action: (queue) => queue.remove(entry.volumeId),
                    ),
                  ),
              ],
              if (view.failed.isNotEmpty) ...[
                _SectionTitle('失敗（${view.failed.length}）'),
                for (final entry in view.failed)
                  DownloadFailureTile(
                    key: ValueKey('failed-${entry.volumeId}'),
                    entry: entry,
                    enabled: !_busy,
                    onRetry: () => _retry(entry),
                    onDelete: () => _deleteFailed(entry),
                  ),
              ],
              if (view.downloaded.isNotEmpty) ...[
                _SectionTitle('ダウンロード済み（${view.downloaded.length}）'),
                for (final group in view.downloaded)
                  DownloadedTitleGroupView(
                    key: ValueKey('group-${group.bookId}'),
                    group: group,
                    selection: selection,
                    enabled: !_busy,
                    onToggleVolume: _toggleVolume,
                    onToggleGroup: (select) => _toggleGroup(group, select),
                    onOpenVolume: (entry) =>
                        context.push(AppRoutes.viewer(entry.volumeId)),
                    onStartSelection: (entry) =>
                        setState(() => _selection = {entry.volumeId}),
                    onRefetchVolume: (entry) => _run(
                      what: 'ダウンロードの開始',
                      action: (queue) => queue.enqueue(
                        volumeId: entry.volumeId,
                        bookId: entry.bookId,
                      ),
                    ),
                    onDeleteVolume: (entry) => _deleteWithConfirm(
                      title:
                          '${entry.titleLabel} ${entry.volumeLabel}のダウンロードを削除しますか？',
                      volumeIds: [entry.volumeId],
                      ledger: ledger,
                    ),
                    onTitleAction: (action) =>
                        _onTitleAction(action, group, ledger),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _normalAppBar(DownloadManagerView view) => AppBar(
    leading: const AppBackButton(),
    title: const Text('ダウンロード'),
    bottom: _progressBar(),
    actions: [
      IconButton(
        onPressed: _busy || _checking != null ? null : _checkUpdates,
        tooltip: '更新を確認',
        icon: const Icon(Icons.sync),
      ),
      IconButton(
        onPressed: _busy || view.downloaded.isEmpty
            ? null
            : () => setState(() => _selection = {}),
        tooltip: '選択',
        icon: const Icon(Icons.checklist),
      ),
    ],
  );

  PreferredSizeWidget _selectionAppBar(
    DownloadManagerView view,
    Set<int> selection,
  ) {
    final bytes = _bytesOf(view, selection);
    return AppBar(
      leading: IconButton(
        onPressed: _busy ? null : () => setState(() => _selection = null),
        tooltip: '選択をやめる',
        icon: const Icon(Icons.close),
      ),
      title: Text('${selection.length} 巻選択・${formatBytes(bytes)}'),
      bottom: _progressBar(),
      actions: [
        IconButton(
          onPressed: _busy
              ? null
              : () => setState(
                  () => _selection = {
                    for (final group in view.downloaded)
                      for (final entry in group.volumes) entry.volumeId,
                  },
                ),
          tooltip: 'すべて選択',
          icon: const Icon(Icons.select_all),
        ),
        IconButton(
          onPressed: _busy || selection.isEmpty
              ? null
              : () => _deleteWithConfirm(
                  title: '選んだ巻のダウンロードを削除しますか？',
                  volumeIds: _orderedSelection(view, selection),
                  ledger: ref.read(downloadQueueProvider).value ?? const {},
                ),
          tooltip: '削除',
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  PreferredSizeWidget? _progressBar() {
    final deleting = _deleting;
    if (deleting == null) return null;
    return PreferredSize(
      preferredSize: const Size.fromHeight(4),
      child: LinearProgressIndicator(
        value: deleting.total == 0 ? null : deleting.done / deleting.total,
      ),
    );
  }

  Widget _summary(BuildContext context, DownloadManagerView view) => ListTile(
    leading: const Icon(Icons.offline_pin_outlined),
    title: Text(
      'ダウンロード済み ${view.downloadedVolumeCount} 巻・'
      '${formatBytes(view.downloadedBytes)}',
    ),
    trailing: TextButton(
      onPressed: () => context.push(AppRoutes.storageSettings),
      child: const Text('ストレージ設定'),
    ),
  );

  List<Widget> _emptyMessage(BuildContext context) {
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 120),
      Icon(
        Icons.download_outlined,
        size: 40,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      const SizedBox(height: 12),
      Text(
        'ダウンロードしたコミックはありません',
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 4),
      Text(
        'タイトル詳細の巻一覧からダウンロードできます',
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    ];
  }

  /// 台帳から消えた巻（別の画面で削除した / 自動削除）を選択から外す。
  Set<int>? _effectiveSelection(DownloadManagerView view) {
    final selection = _selection;
    if (selection == null) return null;
    final installed = {
      for (final group in view.downloaded)
        for (final entry in group.volumes) entry.volumeId,
    };
    return selection.intersection(installed);
  }

  void _toggleVolume(int volumeId) => setState(() {
    final selection = {...?_selection};
    if (!selection.remove(volumeId)) selection.add(volumeId);
    _selection = selection;
  });

  void _toggleGroup(DownloadedTitleGroup group, bool select) => setState(() {
    final ids = group.volumes.map((entry) => entry.volumeId);
    final selection = {...?_selection};
    if (select) {
      selection.addAll(ids);
    } else {
      selection.removeAll(ids);
    }
    _selection = selection;
  });

  /// 選んだ巻を画面の並び順に（タイトル → 巻数。消える順を予測しやすくする）。
  List<int> _orderedSelection(DownloadManagerView view, Set<int> selection) => [
    for (final group in view.downloaded)
      for (final entry in group.volumes)
        if (selection.contains(entry.volumeId)) entry.volumeId,
  ];

  int _bytesOf(DownloadManagerView view, Set<int> selection) => [
    for (final group in view.downloaded)
      for (final entry in group.volumes)
        if (selection.contains(entry.volumeId)) entry.download.totalBytes,
  ].fold(0, (sum, bytes) => sum + bytes);

  /// ユーザー操作の「更新を確認」（プルして更新 / AppBar）。
  ///
  /// 確認している間に押し直されたら、走っている確認を一緒に待つだけにする
  /// （自宅サーバーへ 2 回問い合わせない・結果の SnackBar も 1 回だけ）。
  Future<void> _checkUpdates() {
    final running = _checking;
    if (running != null) return running;
    final check = _runCheck().whenComplete(() {
      if (mounted) setState(() => _checking = null);
    });
    setState(() {
      _checking = check;
    });
    return check;
  }

  Future<void> _runCheck() async {
    final error = await ref
        .read(downloadManagerTitlesProvider.notifier)
        .refreshFromServer();
    if (!mounted) return;
    if (error != null) {
      // 取れた分は反映済み。表示は残し、確認できなかったことを伝える。
      showRefreshFailure(context, error, what: 'サーバーの更新情報');
      return;
    }
    final ledger = ref.read(downloadQueueProvider).value ?? const {};
    final view = buildDownloadManagerView(
      ledger: ledger,
      titles: ref.read(downloadManagerTitlesProvider).value?.titles ?? const {},
    );
    final outdated = view.downloaded.fold(
      0,
      (sum, group) => sum + group.outdatedCount,
    );
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          outdated == 0 ? '更新のある巻はありません' : '更新のある巻が $outdated 巻あります',
        ),
      ),
    );
  }

  /// 失敗した行の再試行。
  ///
  /// 取り直しの失敗（completed に戻した行）は resume できないので積み直す。
  void _retry(DownloadEntry entry) {
    if (entry.refetchFailed) {
      _run(
        what: 'ダウンロードの開始',
        action: (queue) =>
            queue.enqueue(volumeId: entry.volumeId, bookId: entry.bookId),
      );
      return;
    }
    _run(what: 'ダウンロードの再開', action: (queue) => queue.resume(entry.volumeId));
  }

  /// 失敗した行の削除。読める実体が無ければ確認しない（消えて困るものが無い）。
  void _deleteFailed(DownloadEntry entry) {
    if (!entry.download.hasInstalledArchive) {
      _run(what: 'ダウンロードの削除', action: (queue) => queue.remove(entry.volumeId));
      return;
    }
    _deleteWithConfirm(
      title: '${entry.titleLabel} ${entry.volumeLabel}のダウンロードを削除しますか？',
      volumeIds: [entry.volumeId],
      ledger: ref.read(downloadQueueProvider).value ?? const {},
    );
  }

  Future<void> _onTitleAction(
    DownloadedTitleAction action,
    DownloadedTitleGroup group,
    Map<int, VolumeDownload> ledger,
  ) async {
    switch (action) {
      case DownloadedTitleAction.refetchOutdated:
        final outdated = [
          for (final entry in group.volumes)
            if (entry.isOutdated)
              (volumeId: entry.volumeId, bookId: entry.bookId),
        ];
        await _run(
          what: 'ダウンロードの開始',
          action: (queue) => queue.enqueueAll(outdated),
        );
      case DownloadedTitleAction.openTitle:
        await context.push(AppRoutes.bookDetail(group.bookId));
      case DownloadedTitleAction.deleteTitle:
        // 台帳にある同じタイトルの行すべて（進行中・失敗を含む）。
        // 読める巻だけ消すと、取得中の巻が後から完了してタイトルが復活する。
        final volumeIds = [
          for (final download in ledger.values)
            if (download.bookId == group.bookId) download.volumeId,
        ]..sort();
        await _deleteWithConfirm(
          title: '「${group.titleLabel}」のダウンロードを削除しますか？',
          volumeIds: volumeIds,
          ledger: ledger,
          includesUnfinished: volumeIds.any(
            (id) => !(ledger[id]?.hasInstalledArchive ?? false),
          ),
        );
    }
  }

  /// 確認してから削除する（数百 MB の取り直しになるため）。
  Future<void> _deleteWithConfirm({
    required String title,
    required List<int> volumeIds,
    required Map<int, VolumeDownload> ledger,
    bool includesUnfinished = false,
  }) async {
    if (volumeIds.isEmpty) return;
    final confirmed = await confirmDeleteDownloads(
      context,
      title: title,
      volumeCount: volumeIds.length,
      bytes: _installedBytes(volumeIds, ledger),
      includesUnfinished: includesUnfinished,
    );
    if (!confirmed || !mounted) return;
    await _delete(volumeIds);
  }

  /// 1 巻ずつ順に消す（キューの鎖に載せる。並列にしない）。
  ///
  /// 失敗した巻があっても残りは続け、最後にまとめて知らせる。成功した分の
  /// 容量表示は台帳から出しているので自動で正しくなる。
  ///
  /// 確認済みの削除は**画面を離れても最後までやり切る**。途中で止めると、
  /// 全部消えたと思っているユーザーの端末に数 GB が黙って残る（「すべての
  /// データを削除」と同じ方針）。queue / gateway は keepAlive で、ループの前に
  /// 取ってあるので widget が無くても使える。止めるのは画面の更新だけにし、
  /// 結果はアプリ全体の ScaffoldMessenger（先に取っておく）で知らせる。
  Future<void> _delete(List<int> volumeIds) async {
    final queue = ref.read(downloadQueueProvider.notifier);
    final gateway = ref.read(offlineMetadataGatewayProvider);
    final ledger = ref.read(downloadQueueProvider).value ?? const {};
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _deleting = (done: 0, total: volumeIds.length));

    Object? firstError;
    final removed = <int>[];
    var removedBytes = 0;
    var processed = 0;
    for (final volumeId in volumeIds) {
      try {
        await queue.remove(volumeId);
        removed.add(volumeId);
        removedBytes += _installedBytes([volumeId], ledger);
      } on Object catch (error) {
        firstError ??= error;
      }
      processed++;
      if (mounted) {
        setState(() => _deleting = (done: processed, total: volumeIds.length));
      }
    }

    try {
      // ダウンロードが無くなったタイトルの控えを捨てる（次の一覧読み込みでも
      // やり直されるので、失敗しても知らせない）。
      await gateway.prune();
    } on Object catch (error) {
      debugPrint('[downloads] prune after delete failed: $error');
    }

    if (mounted) {
      setState(() {
        _deleting = null;
        final selection = _selection?.difference(removed.toSet());
        // 全部消せたら選択を終える。残った（失敗した）巻は選んだままにして、
        // もう一度押せば消し直せるようにする。
        _selection = selection == null || selection.isEmpty ? null : selection;
      });
    }
    if (messenger == null || !messenger.mounted) return;

    if (firstError case final error?) {
      messenger.showSnackBar(actionFailureSnackBar(error, what: 'ダウンロードの削除'));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${removed.length} 巻（${formatBytes(removedBytes)}）を削除しました',
        ),
      ),
    );
  }

  /// 端末の操作の失敗は黙って飲み込まずその場で知らせる（`VolumeTile` と同じ）。
  Future<void> _run({
    required String what,
    required Future<void> Function(DownloadQueue queue) action,
  }) async {
    try {
      await action(ref.read(downloadQueueProvider.notifier));
    } on Object catch (error) {
      if (!mounted) return;
      showActionFailure(context, error, what: what);
    }
  }
}

/// 読める巻の容量（削除で空く分の見積もり）。
int _installedBytes(List<int> volumeIds, Map<int, VolumeDownload> ledger) {
  var bytes = 0;
  for (final id in volumeIds) {
    final download = ledger[id];
    if (download != null && download.hasInstalledArchive) {
      bytes += download.totalBytes;
    }
  }
  return bytes;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
