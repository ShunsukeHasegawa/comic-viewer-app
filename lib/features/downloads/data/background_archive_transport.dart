import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'archive_transport.dart';
import 'transfer_mapping.dart';

part 'background_archive_transport.g.dart';

/// `background_downloader` で ZIP を転送する [ArchiveTransport]（#10）。
///
/// パッケージを包むだけの薄い層にして、判断（再試行・検証・台帳）は持たせない。
/// プラットフォームチャネルに触るので単体テストはせず、変換は
/// `transfer_mapping.dart` の純粋関数に寄せてそちらをテストする。
///
/// パッケージの `FileDownloader` はプロセスで 1 つのシングルトンで、
/// `updates` も 1 つしか購読できない。**アプリの他の場所から
/// `FileDownloader()` を呼ばない**こと（最初に作った側の永続化ストアが
/// 使われ、再開データを引けなくなる）。
class BackgroundArchiveTransport implements ArchiveTransport {
  BackgroundArchiveTransport();

  /// パッケージの永続化ストア。再開データと一時停止中のタスクは
  /// `FileDownloader` の公開 API から引けないので、同じインスタンスを持っておく。
  /// `FileDownloader` に渡せるのは最初の 1 回だけなので、どちらもプロセスで
  /// 1 つにする（provider が作り直されても 2 つ目を作らない）。
  static final _storage = LocalStorePersistentStorage();

  static final FileDownloader _downloader = FileDownloader(
    persistentStorage: _storage,
  );

  final _events = StreamController<TransferEvent>.broadcast();
  StreamSubscription<TaskUpdate>? _subscription;
  Future<void>? _packageStarted;

  @override
  Stream<TransferEvent> get events => _events.stream;

  /// 購読をやめる。パッケージの `updates` は単一購読なので、作り直して
  /// 次のインスタンスが購読できるようにする。
  Future<void> dispose() async {
    if (_subscription != null) {
      await _subscription?.cancel();
      _subscription = null;
      await _downloader.resetUpdates();
    }
    await _events.close();
  }

  @override
  Future<void> start({
    required bool wifiOnly,
    required TransferNotificationTexts texts,
  }) async {
    // 1. 先に購読する。`start` の中で、アプリが死んでいる間に届いた完了や
    //    失敗が再送されるので、その後だと取りこぼす。`updates` は
    //    単一購読なので一度だけ。
    _subscription ??= _downloader.updates.listen(_onUpdate);

    // 2. 設定はネイティブ側に残るので、毎回明示する（以前の値に頼らない）。
    //    - holding queue の同時実行数 1: 自宅サーバーの HDD を複数本で
    //      同時に読ませない。Dart の TaskQueue と違い、アプリが閉じていても
    //      次の巻を取り出す。
    //    - 一時ファイルをキャッシュ領域に置かない: 数百 MB の ZIP が OS に
    //      消されると、時間切れの pause から再開できなくなる。
    final results = await _downloader.configure(
      globalConfig: [(Config.holdingQueue, (1, null, null))],
      androidConfig: [(Config.useCacheDir, Config.never)],
    );
    for (final (config, result) in results) {
      if (result.isNotEmpty) {
        debugPrint('[transfer] configure $config: $result');
      }
    }

    // 3. Wi-Fi 限定（走行中の転送にも反映させる）。
    await setWifiOnly(wifiOnly);

    // 4. 通知は巻ごとではなくグループで 1 件にまとめる。一時停止の通知は
    //    出さない（通知のボタンから Dart を経由せずに止められる経路を増やさない）。
    _downloader.configureNotificationForGroup(
      archiveTransferGroup,
      running: TaskNotification(texts.runningTitle, texts.runningBody),
      complete: TaskNotification(texts.completeTitle, texts.completeBody),
      error: TaskNotification(texts.errorTitle, texts.errorBody),
      progressBar: true,
      groupNotificationId: archiveTransferNotificationId,
    );

    // 5. パッケージを開始する。
    //    - プラグインの自動再投入（5 秒後の rescheduleKilledTasks）は使わない。
    //      古いトークンのまま積み直し、キューの照合と二重に投入するため。
    //    - 記録は自動で間引く（増え続けないように）。
    //    二度目以降の呼び出しでは再送を繰り返さない。失敗したら次の呼び出しで
    //    やり直せるよう、覚えた Future を捨てる。
    final started = _packageStarted ??= _downloader.start(
      doRescheduleKilledTasks: false,
      autoCleanDatabase: true,
    );
    try {
      await started;
    } catch (_) {
      if (identical(_packageStarted, started)) _packageStarted = null;
      rethrow;
    }
  }

  void _onUpdate(TaskUpdate update) {
    if (_events.isClosed || update.task.group != archiveTransferGroup) return;
    final event = mapTaskUpdate(update);
    if (event != null) _events.add(event);
  }

  @override
  Future<void> setWifiOnly(bool value) => _downloader.requireWiFi(
    value ? RequireWiFi.forAllTasks : RequireWiFi.forNoTasks,
    rescheduleRunningTasks: true,
  );

  @override
  Future<bool> enqueue(ArchiveTransferRequest request) =>
      _downloader.enqueue(buildDownloadTask(request));

  @override
  Future<bool> pause(String taskId) async {
    // 走っているタスクしか確実には引けない。引けなければ（holding queue で
    // 待っているだけ等）一時停止はできないので false（呼び出し側が取り消す）。
    final task = await _downloader.taskForId(taskId);
    if (task is! DownloadTask) return false;
    return _downloader.pause(task);
  }

  @override
  Future<bool> resume(String taskId) async {
    final resumeData = await _storage.retrieveResumeData(taskId);
    final task = resumeData?.task;
    if (task is! DownloadTask) return false;
    return _downloader.resume(task);
  }

  @override
  Future<void> cancel(String taskId) async {
    // 一時停止中のタスク（パッケージの保存領域にしかいない）もこれで取り消せる。
    await _downloader.cancelTaskWithId(taskId);
  }

  @override
  Future<List<TransferSnapshot>> snapshot() async {
    final active = await _downloader.allTasks(group: archiveTransferGroup);
    final activeIds = {for (final task in active) task.taskId};
    final records = await _downloader.database.allRecords(
      group: archiveTransferGroup,
    );
    final resumeIds = {
      for (final data in await _storage.retrieveAllResumeData())
        if (data.task.group == archiveTransferGroup) data.task.taskId,
    };
    final pausedIds = {
      for (final task in await _storage.retrieveAllPausedTasks())
        if (task.group == archiveTransferGroup) task.taskId,
    };

    final states = <String, TransferState>{};
    for (final record in records) {
      final state = mapTaskStatus(record.status);
      final alive =
          state == TransferState.enqueued ||
          state == TransferState.running ||
          state == TransferState.waitingToRetry;
      // 記録は「走行中」なのにネイティブが知らない = プロセスごと殺されて
      // 消えた（holding queue の中身はメモリにしか無い）。積み直しが要る。
      states[record.taskId] = alive && !activeIds.contains(record.taskId)
          ? TransferState.notFound
          : state;
    }
    for (final taskId in activeIds) {
      final recorded = states[taskId];
      final alive =
          recorded == TransferState.enqueued ||
          recorded == TransferState.running ||
          recorded == TransferState.waitingToRetry;
      // 記録が遅れていても、ネイティブが持っているなら生きている。
      if (!alive) states[taskId] = TransferState.enqueued;
    }
    for (final taskId in {...resumeIds, ...pausedIds}) {
      states.putIfAbsent(taskId, () => TransferState.paused);
    }

    return [
      for (final MapEntry(key: taskId, value: state) in states.entries)
        TransferSnapshot(
          taskId: taskId,
          state: state,
          hasResumeData: resumeIds.contains(taskId),
        ),
    ];
  }

  @override
  Future<void> forget(String taskId) async {
    await _downloader.database.deleteRecordWithId(taskId);
    await _storage.removeResumeData(taskId);
    await _storage.removePausedTask(taskId);
  }

  @override
  Future<void> reset() async {
    // 走行中・待機中・一時停止中のすべてを取り消す。`cancelAll(group:)` は
    // 走行中の一覧からしか拾わないので、一時停止中と記録の ID も足す。
    final active = await _downloader.allTasks(group: archiveTransferGroup);
    final records = await _downloader.database.allRecords(
      group: archiveTransferGroup,
    );
    final resumeData = [
      for (final data in await _storage.retrieveAllResumeData())
        if (data.task.group == archiveTransferGroup) data,
    ];
    final paused = [
      for (final task in await _storage.retrieveAllPausedTasks())
        if (task.group == archiveTransferGroup) task,
    ];
    final taskIds = {
      for (final task in active) task.taskId,
      for (final record in records) record.taskId,
      for (final data in resumeData) data.task.taskId,
      for (final task in paused) task.taskId,
    };
    if (taskIds.isNotEmpty) {
      await _downloader.cancelTasksWithIds(taskIds);
    }
    await _downloader.reset(group: archiveTransferGroup);

    // タスクの記録には Bearer が平文で入っている（#15）。
    await _downloader.database.deleteAllRecords(group: archiveTransferGroup);
    for (final data in resumeData) {
      await _storage.removeResumeData(data.task.taskId);
    }
    for (final task in paused) {
      await _storage.removePausedTask(task.taskId);
    }
    await _deleteTempFiles();
  }

  /// パッケージの一時ファイル（前のユーザーの部分データ）を消す。
  ///
  /// Android で `useCacheDir: never` にすると、一時ファイルは application
  /// support の直下に `com.bbflight.background_downloader<乱数>` の名前で
  /// 作られ、取り消しや失敗で残ることがある（パッケージの CONFIG.md が
  /// 掃除をアプリに求めている）。以前の既定（whenAble）で作られたものが
  /// キャッシュ側に残っている可能性もあるので両方を見る。
  /// iOS は URLSession が自分の領域に置くので、ここでは何も見つからない。
  Future<void> _deleteTempFiles() async {
    final directories = <Directory>[];
    try {
      directories.add(await getApplicationSupportDirectory());
      directories.add(await getTemporaryDirectory());
    } on Object catch (error) {
      debugPrint('[transfer] temp dir lookup failed: $error');
    }
    for (final directory in directories) {
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith(_tempFilePrefix)) continue;
        try {
          await entity.delete();
        } on FileSystemException catch (error) {
          debugPrint('[transfer] temp file delete failed: $error');
        }
      }
    }
  }

  static const _tempFilePrefix = 'com.bbflight.background_downloader';

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      final permissions = _downloader.permissions;
      final status = await permissions.status(PermissionType.notifications);
      if (status == PermissionStatus.granted) return true;
      final result = await permissions.request(PermissionType.notifications);
      return result == PermissionStatus.granted;
    } on Object catch (error) {
      // 通知が出せなくても転送は続くので、失敗は「許可されなかった」扱いにする。
      debugPrint('[transfer] notification permission failed: $error');
      return false;
    }
  }
}

/// 巻の ZIP の転送経路。テストでは `FakeArchiveTransport` に差し替える
/// （本物はプラットフォームチャネルに触るため）。
@Riverpod(keepAlive: true)
ArchiveTransport archiveTransport(Ref ref) {
  final transport = BackgroundArchiveTransport();
  ref.onDispose(transport.dispose);
  return transport;
}
