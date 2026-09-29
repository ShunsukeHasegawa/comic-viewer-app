import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'archive_transport.dart';
import 'task_record_scrubber.dart';
import 'transfer_mapping.dart';
import 'transfer_temp_files.dart';

part 'background_archive_transport.g.dart';

/// `background_downloader` で ZIP を転送する [ArchiveTransport]（#10）。
///
/// パッケージを包むだけの薄い層にして、判断（再試行・検証・台帳）は持たせない。
/// プラットフォームチャネルに触るので単体テストはせず、変換や掃除は
/// `transfer_mapping.dart` などの純粋な部品に寄せてそちらをテストする。
///
/// パッケージの `FileDownloader` はプロセスで 1 つのシングルトンで、
/// `updates` も 1 つしか購読できない。**アプリの他の場所から
/// `FileDownloader()` を呼ばない**こと（最初に作った側の永続化ストアが
/// 使われ、再開データを引けなくなる）。
class BackgroundArchiveTransport implements ArchiveTransport {
  BackgroundArchiveTransport() {
    _scrubber = TaskRecordScrubber(erase: _erase, exists: _hasRecord);
  }

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

  /// 前のセッションのタスクの記録を、書き戻されても消し直す（#15）。
  late final TaskRecordScrubber _scrubber;

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
    //    - foreground 実行: 9 分の時間切れ（holding queue を迂回する再投入）を
    //      起こさない。通知の許可が無いと逆効果なので許可を見て決める
    //      （`foregroundModeFor` 参照）。
    final foreground = foregroundModeFor(
      notificationsGranted: await _notificationsGranted(),
    );
    _logConfigureResults(
      await _downloader.configure(
        globalConfig: [(Config.holdingQueue, (1, null, null))],
        androidConfig: [
          (Config.useCacheDir, Config.never),
          (Config.runInForeground, foreground),
        ],
      ),
    );

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

    // 5. パッケージを開始する（設定の理由は `archiveTransferStartOptions`）。
    //    二度目以降の呼び出しでは再送を繰り返さない。失敗したら次の呼び出しで
    //    やり直せるよう、覚えた Future を捨てる。
    final started = _packageStarted ??= _downloader.start(
      doRescheduleKilledTasks:
          archiveTransferStartOptions.doRescheduleKilledTasks,
      autoCleanDatabase: archiveTransferStartOptions.autoCleanDatabase,
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
    // ログアウトで消した ID の更新は、その更新が記録を書き戻す。消し直す。
    _scrubber.onUpdate(update.task.taskId);
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
    // 引けなければ一時停止はできないので false（呼び出し側が取り消す）。
    // Android は待機中のタスクにも true を返すので、走っているものにだけ
    // 呼んでもらう（[ArchiveTransport.pause]）。
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
  Future<bool> hasResumeData(String taskId) async =>
      await _storage.retrieveResumeData(taskId) != null;

  @override
  Future<void> cancel(String taskId) async {
    // 一時停止中のタスク（パッケージの保存領域にしかいない）もこれで取り消せる。
    await _downloader.cancelTaskWithId(taskId);
  }

  @override
  Future<List<TransferSnapshot>> snapshot() async {
    final listed = await _downloader.allTasks(group: archiveTransferGroup);
    final records = await _downloader.database.allRecords(
      group: archiveTransferGroup,
    );
    return mergeTransferSnapshots(
      records: [for (final record in records) (record.taskId, record.status)],
      listedIds: [for (final task in listed) task.taskId],
      resumeIds: await _resumeIds(),
      pausedIds: await _pausedIds(),
    );
  }

  @override
  Future<void> forget(String taskId) => _erase(taskId);

  @override
  Future<void> forgetForeign(String taskId) async {
    await _erase(taskId);
    _scrubber.purge([taskId]);
  }

  Future<void> _erase(String taskId) async {
    await _downloader.database.deleteRecordWithId(taskId);
    await _storage.removeResumeData(taskId);
    await _storage.removePausedTask(taskId);
  }

  Future<bool> _hasRecord(String taskId) async =>
      await _downloader.database.recordForId(taskId) != null;

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
    // 取り消した転送の canceled は後から届き、そのたびにパッケージが記録
    // （トークン入り）を書き戻す。消した ID を覚えておき、届いた後にも消し直す。
    // アプリがその前に落ちても、次の起動の照合が別セッションの記録として
    // `forgetForeign` で消す。
    _scrubber.purge(taskIds);
    // 前のユーザーの書きかけ。走っていたものも取り消したので全部消す。
    await deleteTransferTempFiles(await _tempDirectories());
  }

  @override
  Future<void> sweepOrphanTempFiles({bool staleOnly = false}) async {
    // 走っている転送の書きかけも同じ名前。1 本でも生きていれば、しばらく
    // 書き込まれていないもの（失敗して置き去りになったもの）だけを消す。
    // まとめて積んだ巻が走り続ける間も、失敗のたびに数百 MB を溜めない。
    final listed = await _downloader.allTasks(group: archiveTransferGroup);
    final alive = mergeTransferSnapshots(
      records: const [],
      listedIds: [for (final task in listed) task.taskId],
      resumeIds: const {},
      pausedIds: await _pausedIds(),
    ).where((snapshot) => snapshot.state != TransferState.paused);
    final busy = staleOnly || alive.isNotEmpty;
    // 一時停止中 / 再試行待ちの転送の書きかけは「再開」で続きに使うので残す。
    final keep = {
      for (final data in await _storage.retrieveAllResumeData()) data.data,
    };
    final deleted = await deleteTransferTempFiles(
      await _tempDirectories(),
      keepPaths: keep,
      olderThan: busy ? transferTempStaleAge : null,
    );
    if (deleted > 0) debugPrint('[transfer] swept $deleted temp files');
  }

  Future<Set<String>> _resumeIds() async => {
    for (final data in await _storage.retrieveAllResumeData())
      if (data.task.group == archiveTransferGroup) data.task.taskId,
  };

  Future<Set<String>> _pausedIds() async => {
    for (final task in await _storage.retrieveAllPausedTasks())
      if (task.group == archiveTransferGroup) task.taskId,
  };

  /// パッケージの一時ファイルが置かれうる場所。
  ///
  /// `useCacheDir: never` なら application support の直下。以前の既定
  /// （whenAble）で作られたものがキャッシュ側に残っている可能性もあるので
  /// 両方を見る。iOS は URLSession が自分の領域に置くので何も見つからない。
  Future<List<Directory>> _tempDirectories() async {
    final directories = <Directory>[];
    try {
      directories.add(await getApplicationSupportDirectory());
      directories.add(await getTemporaryDirectory());
    } on Object catch (error) {
      debugPrint('[transfer] temp dir lookup failed: $error');
    }
    return directories;
  }

  Future<bool> _notificationsGranted() async {
    try {
      final status = await _downloader.permissions.status(
        PermissionType.notifications,
      );
      return status == PermissionStatus.granted;
    } on Object catch (error) {
      debugPrint('[transfer] notification status failed: $error');
      return false;
    }
  }

  void _logConfigureResults(List<(String, String)> results) {
    for (final (config, result) in results) {
      if (result.isNotEmpty) {
        debugPrint('[transfer] configure $config: $result');
      }
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      final permissions = _downloader.permissions;
      var status = await permissions.status(PermissionType.notifications);
      if (status != PermissionStatus.granted) {
        status = await permissions.request(PermissionType.notifications);
      }
      final granted = status == PermissionStatus.granted;
      // 許可が出たら foreground 実行に切り替える（次に走るタスクから効く）。
      if (granted) await _configureForeground(granted: true);
      return granted;
    } on Object catch (error) {
      // 通知が出せなくても転送は続くので、失敗は「許可されなかった」扱いにする。
      debugPrint('[transfer] notification permission failed: $error');
      return false;
    }
  }

  @override
  Future<void> refreshForegroundMode() async {
    // 設定アプリで許可を取り消されても、パッケージは保存済みの「always」の
    // まま走らせる（許可を見ない）。前面に戻るたびに合わせ直す。アプリが
    // 閉じている間の取り消しは、ネイティブの ComicLazApplication が
    // プロセスの起動時に「never」へ直す（取り消しはプロセスを殺すので、
    // 次のワーカーは必ず新しいプロセスで起動時の処理を通る）。
    try {
      await _configureForeground(granted: await _notificationsGranted());
    } on Object catch (error) {
      debugPrint('[transfer] foreground refresh failed: $error');
    }
  }

  Future<void> _configureForeground({required bool granted}) async {
    _logConfigureResults(
      await _downloader.configure(
        androidConfig: [
          (
            Config.runInForeground,
            foregroundModeFor(notificationsGranted: granted),
          ),
        ],
      ),
    );
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
