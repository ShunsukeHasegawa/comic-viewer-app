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
  /// サーバーが受け取らなかった行（未知の理由 / 時刻を直しても通らない）は
  /// [blocked] に入れ、この回では二度と送らない。入れずに「未送信の集合が
  /// 変わったか」だけで判断すると、片付いた行があるたびに停滞行を含む
  /// リクエストをもう 1 回投げてしまう（HDD サーバーへの無駄な往復）。
  ///
  /// 集合が前回とまったく同じでも打ち切る（保険）。中身が変わっている限りは
  /// 続ける（送信の往復中に読み進めた分や、上限を超えて次のバッチに回った分を
  /// 取りこぼさない）。
  Future<bool> _drain() async {
    var changed = false;
    String? previousBatch;
    // この回で送っても動かないと分かった行。
    final blocked = <int>{};
    // `read_at` を付け替え直した行（同じ行で何度も付け替えない = 必ず終わる）。
    final rebased = <int>{};
    while (true) {
      // 停滞行が上限を埋めてしまわないよう、その分だけ多めに読む。
      final pending = await store.pending(
        limit: UserApi.bulkStatusMaxItems + blocked.length,
      );
      final sendable = [
        for (final progress in pending)
          if (!blocked.contains(progress.volumeId)) progress,
      ].take(UserApi.bulkStatusMaxItems).toList();
      if (sendable.isEmpty) return changed;

      final batch = _signature(sendable);
      if (batch == previousBatch) return changed;
      previousBatch = batch;

      final VolumeStatusSyncResponse response;
      try {
        response = await api.syncVolumeStatuses([
          for (final progress in sendable)
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

      final resolved = await _apply(
        sendable,
        response.result,
        serverTime: response.serverTime,
        blocked: blocked,
        rebased: rebased,
      );
      changed = resolved > 0 || changed;
    }
  }

  /// 未送信の集合を表す文字列（同じ集合を送り続けていないかの判定用）。
  static String _signature(List<ReadingProgress> pending) => [
    for (final progress in pending)
      '${progress.volumeId}@${progress.readAt.microsecondsSinceEpoch}'
          ':${progress.currentPage}',
  ].join(',');

  /// 応答をローカルへ反映し、片付いた件数を返す。
  ///
  /// [serverTime] は応答の `Date` ヘッダ（サーバーの現在時刻）。端末時計が
  /// 進みすぎて棄却された行を合わせ直すのに使う。
  Future<int> _apply(
    List<ReadingProgress> sent,
    VolumeStatusSyncResult result, {
    required DateTime? serverTime,
    required Set<int> blocked,
    required Set<int> rebased,
  }) async {
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
        sentCurrentPage: progress.currentPage,
        currentPage: snapshot.currentPage,
        maxPage: snapshot.maxPage,
        readAt: snapshot.effectiveReadAt ?? progress.readAt,
      );
      // 書けなかった = 往復中に読み進めた行。次の周回でその値が送られる。
      if (written) resolved++;
    }

    for (final skip in result.skipped) {
      final progress = sentByVolume[skip.volumeId];
      if (progress == null) continue;
      switch (skip.reason) {
        case VolumeStatusSkipReason.stale:
          final current = skip.current;
          final serverReadAt = current?.effectiveReadAt;
          if (current == null || serverReadAt == null) {
            // 何に負けたのか分からない。送り直しても同じなので今回は触らない。
            blocked.add(skip.volumeId);
          } else if (_isSameSecond(serverReadAt, progress.readAt) &&
              progress.currentPage > current.currentPage) {
            // サーバーの記録が**同じ秒**で、手元の方が読み進んでいる。負けたのは
            // `read_at` が秒精度で「より新しいときだけ採用」だからなので、1 秒
            // 進めて送り直す。サーバー値で上書きしてしまうと、同期した直後の
            // 同じ秒に入ったページ送りが毎回消えて送信済み扱いになる。
            if (rebased.add(skip.volumeId)) {
              await store.rebaseReadAt(
                volumeId: skip.volumeId,
                sentReadAt: progress.readAt,
                sentCurrentPage: progress.currentPage,
                readAt: serverReadAt.add(const Duration(seconds: 1)),
              );
            } else {
              // 合わせ直しても同じ秒で負けた。手元の新しいページは捨てずに残す。
              blocked.add(skip.volumeId);
            }
          } else {
            // 他端末の方が本当に新しい。サーバー値でローカルを上書きする
            // （これをしないと次の同期で同じ行を送り続ける）。
            final written = await store.overwriteFromServer(
              volumeId: skip.volumeId,
              sentReadAt: progress.readAt,
              sentCurrentPage: progress.currentPage,
              currentPage: current.currentPage,
              maxPage: current.maxPage,
              readAt: serverReadAt,
            );
            if (written) resolved++;
          }
        case VolumeStatusSkipReason.notFound:
          // 巻が消えた / セーフモードで見えない。再送しても通らないので捨てる。
          await store.delete(skip.volumeId);
          resolved++;
        case VolumeStatusSkipReason.futureReadAt:
          // 端末時計が進みすぎて信用されなかった。放置すると進捗は永久に
          // 届かないのに手元には最新があるので、アプリ上は正常に見えてしまう。
          // サーバー時刻へ合わせ直して、この同期のうちに送り直す。
          if (serverTime != null && rebased.add(skip.volumeId)) {
            await store.rebaseReadAt(
              volumeId: skip.volumeId,
              sentReadAt: progress.readAt,
              sentCurrentPage: progress.currentPage,
              readAt: _truncateToSecond(serverTime),
            );
          } else {
            // サーバー時刻が読めない / 合わせ直しても駄目だった。未送信のまま
            // 残して次の同期に回す（この回では送り直さない）。
            blocked.add(skip.volumeId);
          }
        case VolumeStatusSkipReason.unknown:
          // サーバーが理由を増やした。何をすべきか分からないので残すだけ。
          blocked.add(skip.volumeId);
      }
    }

    return resolved;
  }

  /// サーバーもローカルも `read_at` は秒精度。同じ秒かどうかで比べる。
  static bool _isSameSecond(DateTime a, DateTime b) =>
      _truncateToSecond(a).isAtSameMomentAs(_truncateToSecond(b));

  static DateTime _truncateToSecond(DateTime value) =>
      value.toUtc().copyWith(millisecond: 0, microsecond: 0);
}

@Riverpod(keepAlive: true)
ProgressSyncer progressSyncer(Ref ref) => ProgressSyncer(
  store: ref.watch(progressStoreProvider),
  api: ref.watch(userApiProvider),
);
