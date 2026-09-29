import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/api/user_api.dart';
import '../../../domain/models/volume_status_sync.dart';
import '../data/progress_store.dart';
import '../domain/reading_progress.dart';

part 'progress_syncer.g.dart';

/// 未送信の読書進捗をサーバーへ流し込む（#12）。
///
/// 送信は一括 API（`POST /api/v2/user-volume-status/bulk`）だけを使う。1 件でも
/// 単発 API を使わないのは、単発が `max()` を取らない無条件 upsert で、
/// **古い進捗を送ると他端末の進捗を巻き戻す**ため（一括 API は `read_at` を
/// 比べて新しい方を残し、負けた件はサーバー値を返してくれる）。
class ProgressSyncer {
  ProgressSyncer({required this.store, required this.api});

  final ProgressStore store;
  final UserApi api;

  /// 走行中の同期（同時に 2 本走らせない）。
  Future<bool>? _running;

  /// 走行中に呼ばれたか（終わってからもう一度流す）。
  bool _requested = false;

  /// 未送信の進捗を送る。1 件でも反映できたら `true`。
  ///
  /// 圏外・サーバーエラーは投げずに `false` を返す（読書を止めない）。
  /// 送れなかった行は未送信のまま残り、次の機会に送り直される。
  Future<bool> sync() {
    final running = _running;
    if (running != null) {
      // 送信中に読み進めた分を取りこぼさないよう、終わったらもう一度回す。
      _requested = true;
      return running;
    }
    final task = _syncUntilSettled();
    _running = task;
    return task;
  }

  Future<bool> _syncUntilSettled() async {
    var changed = false;
    try {
      do {
        _requested = false;
        changed = await _drain() || changed;
      } while (_requested);
    } finally {
      _running = null;
    }
    return changed;
  }

  /// 未送信の行が無くなる（か、これ以上進まなくなる）まで送る。
  ///
  /// 前回と**まったく同じ未送信の集合**が返ってきたら打ち切る。サーバーが
  /// 受け取らなかった行（端末時計が進みすぎている等）を無限に送り続けないため。
  /// 中身が変わっている限りは続ける（送信の往復中に読み進めた分や、上限を
  /// 超えて次のバッチに回った分を取りこぼさない）。
  Future<bool> _drain() async {
    var changed = false;
    String? previousBatch;
    while (true) {
      final pending = await store.pending(limit: UserApi.bulkStatusMaxItems);
      if (pending.isEmpty) return changed;

      final batch = _signature(pending);
      if (batch == previousBatch) return changed;
      previousBatch = batch;

      final VolumeStatusSyncResult result;
      try {
        result = await api.syncVolumeStatuses([
          for (final progress in pending)
            VolumeStatusSyncItem(
              volumeId: progress.volumeId,
              currentPage: progress.currentPage,
              maxPage: progress.maxPage,
              readAt: progress.readAt,
            ),
        ]);
      } on ApiException {
        // 圏外・401・5xx。synced は立てない（次の機会に同じ行を送る）。
        return changed;
      }

      changed = await _apply(pending, result) > 0 || changed;
    }
  }

  /// 未送信の集合を表す文字列（同じ集合を送り続けていないかの判定用）。
  static String _signature(List<ReadingProgress> pending) => [
    for (final progress in pending)
      '${progress.volumeId}@${progress.readAt.microsecondsSinceEpoch}'
          ':${progress.currentPage}',
  ].join(',');

  /// 応答をローカルへ反映し、片付いた件数を返す。
  Future<int> _apply(
    List<ReadingProgress> sent,
    VolumeStatusSyncResult result,
  ) async {
    final sentByVolume = {
      for (final progress in sent) progress.volumeId: progress,
    };
    var resolved = 0;

    for (final snapshot in result.applied) {
      final progress = sentByVolume[snapshot.volumeId];
      if (progress == null) continue;
      // サーバーが採用した値をそのまま持つ（`current_page` の丸めや、
      // 同値再送で `read_at` が更新されなかった場合に食い違わせない）。
      final written = await store.overwriteFromServer(
        volumeId: snapshot.volumeId,
        sentReadAt: progress.readAt,
        currentPage: snapshot.currentPage,
        maxPage: snapshot.maxPage,
        readAt: snapshot.effectiveReadAt ?? progress.readAt,
      );
      if (written) resolved++;
    }

    for (final skip in result.skipped) {
      final progress = sentByVolume[skip.volumeId];
      if (progress == null) continue;
      switch (skip.reason) {
        case VolumeStatusSkipReason.stale:
          // 他端末の方が新しい。サーバー値でローカルを上書きする
          // （これをしないと次の同期で同じ行を送り続ける）。
          final current = skip.current;
          if (current == null) break;
          final written = await store.overwriteFromServer(
            volumeId: skip.volumeId,
            sentReadAt: progress.readAt,
            currentPage: current.currentPage,
            maxPage: current.maxPage,
            readAt: current.effectiveReadAt ?? progress.readAt,
          );
          if (written) resolved++;
        case VolumeStatusSkipReason.notFound:
          // 巻が消えた / セーフモードで見えない。再送しても通らないので捨てる。
          await store.delete(skip.volumeId);
          resolved++;
        case VolumeStatusSkipReason.futureReadAt:
        case VolumeStatusSkipReason.unknown:
          // 端末時計のずれ / 未知の理由。未送信のまま残して次の機会に送る。
          break;
      }
    }

    return resolved;
  }
}

@Riverpod(keepAlive: true)
ProgressSyncer progressSyncer(Ref ref) => ProgressSyncer(
  store: ref.watch(progressStoreProvider),
  api: ref.watch(userApiProvider),
);
