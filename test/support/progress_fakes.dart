import 'dart:async';

import 'package:comic_laz/core/device/app_resume_monitor.dart';
import 'package:comic_laz/core/device/connectivity_monitor.dart';
import 'package:comic_laz/core/device/network_kind_monitor.dart';
import 'package:comic_laz/domain/models/volume_status_sync.dart';
import 'package:comic_laz/features/progress/data/progress_store.dart';
import 'package:comic_laz/features/progress/domain/reading_progress.dart';
import 'package:flutter_test/flutter_test.dart';

/// DB を作らずに [ProgressStore] を差し替える（画面のテスト用）。
///
/// 送信中に読み進めた行を守るガード（`read_at` とページ番号の一致）と、
/// `read_at` を秒で切り捨てるところまで本物と同じにしておく。ここが違うと
/// 「同期の途中でページを送った」テストが嘘になる。
class InMemoryProgressStore implements ProgressStore {
  InMemoryProgressStore([Iterable<ReadingProgress> initial = const []])
    : _rows = {for (final row in initial) row.volumeId: row};

  final Map<int, ReadingProgress> _rows;

  @override
  Future<void> save({
    required int volumeId,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  }) async {
    if (maxPage < 1) return;
    _rows[volumeId] = ReadingProgress(
      volumeId: volumeId,
      currentPage: currentPage.clamp(1, maxPage),
      maxPage: maxPage,
      // drift（と MySQL の TIMESTAMP）は秒精度なので、ここでも秒で切る。
      readAt: readAt.copyWith(millisecond: 0, microsecond: 0),
    );
  }

  @override
  Future<ReadingProgress?> find(int volumeId) async => _rows[volumeId];

  @override
  Future<Map<int, ReadingProgress>> loadAll() async => {..._rows};

  @override
  Future<List<ReadingProgress>> pending({required int limit}) async {
    final rows = _rows.values.where((row) => row.isPending).toList()
      ..sort((a, b) => a.readAt.compareTo(b.readAt));
    return rows.take(limit).toList();
  }

  @override
  Future<bool> overwriteFromServer({
    required int volumeId,
    required DateTime sentReadAt,
    required int sentCurrentPage,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  }) async {
    final row = _sentRow(volumeId, sentReadAt, sentCurrentPage);
    if (row == null) return false;
    _rows[volumeId] = ReadingProgress(
      volumeId: volumeId,
      currentPage: currentPage,
      maxPage: maxPage,
      readAt: readAt,
      synced: true,
    );
    return true;
  }

  @override
  Future<bool> rebaseReadAt({
    required int volumeId,
    required DateTime sentReadAt,
    required int sentCurrentPage,
    required DateTime readAt,
  }) async {
    final row = _sentRow(volumeId, sentReadAt, sentCurrentPage);
    if (row == null) return false;
    _rows[volumeId] = ReadingProgress(
      volumeId: volumeId,
      currentPage: row.currentPage,
      maxPage: row.maxPage,
      readAt: readAt.copyWith(millisecond: 0, microsecond: 0),
      synced: row.synced,
    );
    return true;
  }

  /// 送ったときから変わっていない行（変わっていれば `null`）。
  ///
  /// `read_at` が秒精度なので、同じ秒に入ったページ送りはページ番号まで
  /// 見ないと区別できない。本物と同じガードにしておく。
  ReadingProgress? _sentRow(
    int volumeId,
    DateTime sentReadAt,
    int sentCurrentPage,
  ) {
    final row = _rows[volumeId];
    if (row == null) return null;
    if (!row.readAt.isAtSameMomentAs(sentReadAt)) return null;
    if (row.currentPage != sentCurrentPage) return null;
    return row;
  }

  @override
  Future<void> delete(int volumeId) async => _rows.remove(volumeId);

  @override
  Future<void> deleteAll() async => _rows.clear();
}

/// 一括同期 API を真似たサーバー。
///
/// `read_at` 同士の比較・`stale` での現在値返却・存在しない巻の `not_found` を
/// 本物（`UserVolumeStatusService::syncBulk`）と同じ規則で再現する。応答だけを
/// 固定したフェイクでは「他端末が進んでいる巻が巻き戻らない」ことを確かめられない。
class FakeStatusServer {
  FakeStatusServer({
    Map<int, VolumeStatusSnapshot> statuses = const {},
    this.knownVolumes,
  }) : statuses = {...statuses};

  /// 巻 ID → サーバーが持っている進捗。
  final Map<int, VolumeStatusSnapshot> statuses;

  /// 存在する（セーフモードで見える）巻。`null` なら全部存在する扱い。
  Set<int>? knownVolumes;

  /// サーバー側の現在時刻。`null` なら未来時刻の検査をしない。
  ///
  /// 本物は `read_at` がここから [futureToleranceSeconds] 秒以上未来の行を
  /// `future_read_at` で棄却する（端末時計が進んでいる状況の再現に使う）。
  DateTime? now;

  /// `UserVolumeStatusService::FUTURE_TOLERANCE_SECONDS`。
  static const futureToleranceSeconds = 300;

  /// 受け取ったバッチ（何件まとめて送ったかの検証に使う）。
  final batches = <List<VolumeStatusSyncItem>>[];

  /// サーバー側の記録を差し込む（他端末が進めた状態を作る）。
  void record({
    required int volumeId,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  }) {
    statuses[volumeId] = VolumeStatusSnapshot(
      volumeId: volumeId,
      currentPage: currentPage,
      maxPage: maxPage,
      isFinished: currentPage >= maxPage,
      readAt: readAt.toUtc(),
      updatedAt: readAt.toUtc(),
    );
  }

  VolumeStatusSyncResult sync(List<VolumeStatusSyncItem> items) {
    batches.add(items);
    final applied = <VolumeStatusSnapshot>[];
    final skipped = <VolumeStatusSkip>[];

    for (final item in items) {
      final volumeId = item.volumeId;
      if (knownVolumes case final known? when !known.contains(volumeId)) {
        skipped.add(
          VolumeStatusSkip(
            volumeId: volumeId,
            reason: VolumeStatusSkipReason.notFound,
          ),
        );
        continue;
      }

      final current = statuses[volumeId];
      // サーバーは秒精度でしか保存しない。
      final readAt = _truncate(item.readAt);
      if (now case final serverNow?
          when !readAt.isBefore(
            _truncate(serverNow)
                .add(const Duration(seconds: futureToleranceSeconds)),
          )) {
        // 信用できない時刻は書かない（巻き戻しもしない）。
        skipped.add(
          VolumeStatusSkip(
            volumeId: volumeId,
            reason: VolumeStatusSkipReason.futureReadAt,
            current: current,
          ),
        );
        continue;
      }
      final serverReadAt = current?.readAt ?? current?.updatedAt;
      if (serverReadAt != null && !readAt.isAfter(serverReadAt)) {
        skipped.add(
          VolumeStatusSkip(
            volumeId: volumeId,
            reason: VolumeStatusSkipReason.stale,
            current: current,
          ),
        );
        continue;
      }

      final currentPage = item.currentPage.clamp(0, item.maxPage);
      final next = VolumeStatusSnapshot(
        volumeId: volumeId,
        currentPage: currentPage,
        maxPage: item.maxPage,
        isFinished: currentPage >= item.maxPage,
        readAt: readAt,
        updatedAt: readAt,
      );
      statuses[volumeId] = next;
      applied.add(next);
    }

    return VolumeStatusSyncResult(applied: applied, skipped: skipped);
  }

  static DateTime _truncate(DateTime value) =>
      value.toUtc().copyWith(millisecond: 0, microsecond: 0);
}

/// ネットワーク復帰をテストから起こせる [ConnectivityMonitor]。
class FakeConnectivityMonitor implements ConnectivityMonitor {
  FakeConnectivityMonitor({this.emitsOnListen = false}) {
    addTearDown(close);
  }

  /// 購読した瞬間に 1 件流すか。
  ///
  /// 本物（`connectivity_plus`）は購読時に現在の接続状態を必ず 1 件流すので、
  /// 「一覧を開いた瞬間に復帰通知が来る」状況を再現するために使う（#11）。
  final bool emitsOnListen;

  final _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get onRestored async* {
    if (emitsOnListen) yield null;
    yield* _controller.stream;
  }

  /// 圏外 → 接続あり。
  void restore() => _controller.add(null);

  Future<void> close() => _controller.close();
}

/// 回線の切り替えをテストから起こせる [NetworkKindMonitor]（#10）。
class FakeNetworkKindMonitor implements NetworkKindMonitor {
  FakeNetworkKindMonitor([this.kind = NetworkKind.unmetered]) {
    addTearDown(close);
  }

  NetworkKind kind;

  final _controller = StreamController<NetworkKind>.broadcast();

  @override
  Future<NetworkKind> current() async => kind;

  @override
  Stream<NetworkKind> get changes => _controller.stream;

  void switchTo(NetworkKind next) {
    kind = next;
    _controller.add(next);
  }

  Future<void> close() => _controller.close();
}

/// テスト用のローカル進捗。
ReadingProgress testProgress({
  required int volumeId,
  int currentPage = 1,
  int maxPage = 10,
  DateTime? readAt,
  bool synced = false,
}) => ReadingProgress(
  volumeId: volumeId,
  currentPage: currentPage,
  maxPage: maxPage,
  readAt: readAt ?? DateTime.utc(2026, 9, 25, 10),
  synced: synced,
);

/// 前面復帰をテストから起こせる [AppResumeMonitor]。
///
/// 本物は `AppLifecycleListener`（`WidgetsBinding`）を使うので、単体テストでは
/// 差し替える。
class FakeAppResumeMonitor implements AppResumeMonitor {
  final _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get onResumed => _controller.stream;

  /// 背面 → 前面。
  void resume() => _controller.add(null);
}
