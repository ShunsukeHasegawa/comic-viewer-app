import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/device/app_resume_monitor.dart';
import '../../../core/device/connectivity_monitor.dart';
import '../../../core/utils/format.dart';
import '../../../data/api/volumes_api.dart';
import '../../../domain/models/volume_manifest.dart';
import '../data/archive_transport.dart';
import '../data/background_archive_transport.dart';
import '../data/download_store.dart';
import '../data/free_space_probe.dart';
import '../domain/archive_task_id.dart';
import '../domain/volume_download.dart';
import 'archive_installer.dart';
import 'download_failure_policy.dart';
import 'download_queue_memory.dart';
import 'download_settings.dart';
import 'startup_reconciler.dart';
import 'transfer_cleanup.dart';
import 'transfer_event_reducer.dart';

export 'download_failure_policy.dart' show maxDownloadAttempts;
export 'download_progress_book.dart' show progressPersistIntervalBytes;

part 'download_queue.g.dart';

/// 再試行の待ち時間（テストから即時にできるようにする）。
typedef RetryDelay = Future<void> Function(Duration duration);

@Riverpod(keepAlive: true)
RetryDelay downloadRetryDelay(Ref ref) => Future<void>.delayed;

/// 空き容量チェックの余裕分。
///
/// ぴったり入るだけの空きしか無い状態で始めると、OS やほかのアプリの書き込みで
/// 途中で詰まる。
const freeSpaceMarginBytes = 64 * 1024 * 1024;

/// 巻単位のダウンロードキュー。
///
/// ZIP の転送は OS のバックグラウンド転送（[ArchiveTransport]）に任せ、
/// アプリを閉じても続くようにする（#10）。Dart 側に残すのは次のものだけ:
/// - 積む順番（`creationTime` を狭義単調増加にして、1 巻から順に落とす）
/// - 転送が終わった後の検証（サイズ / ZIP として開けるか / ページ数）と、
///   `.zip.download` から本番のファイル名への rename、台帳の確定
/// - 失敗の解釈と再試行（ネイティブの 401 / Wi-Fi 切れ / 5xx を分ける）
/// - 起動時の照合（アプリが死んでいる間に終わった / 消えた転送の拾い上げ）
///
/// 同時実行数（1。自宅サーバーの HDD を複数本で読ませない）と Wi-Fi 限定は
/// OS 側（holding queue / requireWiFi）が守る。アプリが閉じていても効かせる
/// ため、Dart では止めない。Android の 9 分の時間切れは holding queue を
/// 迂回して同時実行数を崩すので foreground 実行で避ける（背面で始まった巻には
/// 効かない残りの穴がある。`foregroundModeFor` 参照）。
///
/// このクラスは調停役で、公開の操作（積む / 中断 / 再開 / 削除 / 破棄）・投入・
/// 再試行・台帳の書き込み・世代の管理を持つ。次の処理は部品に分けてある（#32）:
/// - 起動時の照合の実行: [StartupReconciler]（判断の表は reconcile_planner.dart）
/// - 転送イベントの反映: [TransferEventReducer]
/// - 確定（検証・rename・台帳の完了）: [ArchiveInstaller]
/// - 取り消し・書きかけ / 記録 / 一時ファイルの後始末: [TransferCleanup]
///
/// 部品は巻ごとの印と鎖（[DownloadQueueMemory]）をこのクラスと共有し、台帳や
/// 投入はここ（[DownloadQueueHost]）に頼む。
@Riverpod(keepAlive: true)
class DownloadQueue extends _$DownloadQueue {
  /// 巻ごとの印と鎖。部品（照合 / イベントの reducer / 確定 / 後始末）と
  /// 共有する（[DownloadQueueMemory]。#32）。
  final _memory = DownloadQueueMemory();

  late final _host = _QueueHost(this);
  late final _cleanup = TransferCleanup(_memory, _host);
  late final _installer = ArchiveInstaller(_memory, _host, _cleanup);
  late final _events = TransferEventReducer(_memory, _host, _cleanup);
  late final _reconciler = StartupReconciler(_memory, _host, _cleanup);

  /// 進行中の非同期処理（テストで「落ち着くまで待つ」ために使う）。
  final _pending = <Future<void>>{};

  /// 起動時の照合が終わるまで、転送のイベントを待たせる。
  ///
  /// 照合の前は「今の転送」が分からないので、届いた完了を自分のものと
  /// 判断できない（取りこぼすか、古い世代を確定してしまう）。
  Completer<void> _ready = Completer<void>();

  /// 直前に渡した `creationTime`（ミリ秒）。
  int _lastCreationMs = 0;

  /// このプロセスで通知の許可を確かめたか。
  bool _notificationChecked = false;

  /// 破棄の世代。[purgeAll] と再構築のたびに進む。
  ///
  /// ログアウトより前に始まった処理が、破棄の後に完了して前のユーザーの
  /// データを書き戻さないようにするための仕切り。
  int _generation = 0;

  /// 今のログインセッションのタグ（タスク ID に埋め込む。#15）。
  ///
  /// `null` の間（破棄の途中）は、届いたイベントをすべて他人のものとして扱う。
  String? _sessionTag;

  DownloadStore? _store;
  ArchiveTransport? _transport;

  /// 進行中の処理がすべて終わるまで待つ（テスト用）。
  @visibleForTesting
  Future<void> get idle async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }

  /// 進行中の処理があるか（テスト用）。
  @visibleForTesting
  bool get hasPendingWork => _pending.isNotEmpty;

  @override
  Future<Map<int, VolumeDownload>> build() async {
    // Notifier は再構築でも同じインスタンスが使い回される。前回の処理が
    // 後から書き戻さないよう世代を進め、メモリ上の状態を捨てる。
    _generation++;
    final generation = _generation;
    _memory.reset();
    final ready = _ready = Completer<void>();
    ref.onDispose(() {
      if (!ready.isCompleted) ready.complete();
    });

    final transport = ref.watch(archiveTransportProvider);
    _transport = transport;
    // 先に購読する。`start` の中で、アプリが死んでいる間に終わった転送の
    // 完了が届く。
    final events = transport.events.listen(_events.onEvent);
    ref.onDispose(events.cancel);

    // Wi-Fi 限定の設定は OS の転送に反映する（走行中の転送にも効かせる）。
    ref.listen(downloadWifiOnlyProvider, (previous, next) {
      // 初回の読み込み（値なし → 値あり）は `start` で渡すので送らない。
      if (previous == null || !(previous.hasValue || previous.hasError)) {
        return;
      }
      final value = next.hasError ? true : next.value;
      final before = previous.hasError ? true : previous.value;
      if (value == null || value == before) return;
      _track(transport.setWifiOnly(value));
    });
    // 投入できずに待機のまま残った巻を、流せそうな契機で投入し直す。
    ref.listen(downloadGateProvider, (_, gate) {
      if (gate == DownloadGate.open) _submitPending();
    });
    final restored = ref
        .read(connectivityMonitorProvider)
        .onRestored
        .listen((_) => _submitPending());
    ref.onDispose(restored.cancel);
    final resumed = ref.read(appResumeMonitorProvider).onResumed.listen((_) {
      // 通知の許可は設定アプリで後から取り消せる。起動時の判断のままだと
      // foreground のつもりで走り、WorkManager の 10 分の上限で止められる
      // （`foregroundModeFor`）。前面に戻るたびに合わせ直す。
      _track(transport.refreshForegroundMode());
      _submitPending();
    });
    ref.onDispose(resumed.cancel);

    try {
      final store = await ref.watch(downloadStoreProvider.future);
      _store = store;

      final loaded = await store.loadAll();
      final restoredRows = <int, VolumeDownload>{};
      for (final entry in loaded.entries) {
        // 「取得中」は OS の転送の状態で決め直す（照合で running なら戻す）。
        // ユーザーは止めていないので「中断中」にはしない。
        final download = entry.value.status == VolumeDownloadStatus.downloading
            ? entry.value.copyWith(status: VolumeDownloadStatus.queued)
            : entry.value;
        if (download != entry.value) await store.save(download);
        restoredRows[entry.key] = download;
      }

      _sessionTag = await store.readSessionTag();
      final wifiOnly = await _readWifiOnly();
      try {
        await transport.start(
          wifiOnly: wifiOnly,
          texts: const TransferNotificationTexts(),
        );
      } on Object catch (error) {
        // 始められなくても台帳は見せる（投入は失敗として理由を出す）。
        debugPrint('[downloads] transport start failed: $error');
      }

      // 台帳が state に入ってから照合する（照合は state を書き換える）。
      _track(
        Future<void>(() async {
          try {
            await future;
            if (_isStale(generation)) return;
            List<TransferSnapshot> snapshots;
            try {
              snapshots = await transport.snapshot();
            } on Object catch (error) {
              // 一覧が取れなければ「何も走っていない」とみなして積み直す。
              // 走っていた場合は二重になるが、古い方は「今の転送」ではない
              // ので、届いた完了 / 失敗は取り込まずに捨てる（書き込み先は
              // 同じ世代なので消さない）。
              debugPrint('[downloads] snapshot failed: $error');
              snapshots = const [];
            }
            if (_isStale(generation)) return;
            await _reconciler.run(snapshots, generation);
          } finally {
            if (!ready.isCompleted) ready.complete();
          }
        }),
      );
      return restoredRows;
    } on Object {
      if (!ready.isCompleted) ready.complete();
      rethrow;
    }
  }

  /// ダウンロードを積む（既に積まれているものは無視）。
  ///
  /// 「更新あり」の取り直しも同じ入口。マニフェストを取り直すので、
  /// 呼び出し側は `files_version` を知らなくてよい。
  Future<void> enqueue({required int volumeId, required int bookId}) async {
    await future;
    if (!ref.mounted) return;

    final existing = state.value?[volumeId];
    if (existing != null && existing.isActive) return;
    // 取り直し（完了済みの巻を新しい世代で落とし直す）なら、手元の世代を覚えておく。
    if (existing != null) _rememberInstalled(existing);

    final download =
        (existing ??
                VolumeDownload(
                  volumeId: volumeId,
                  bookId: bookId,
                  filesVersion: 0,
                  status: VolumeDownloadStatus.queued,
                ))
            .copyWith(
              status: VolumeDownloadStatus.queued,
              clearFailureReason: true,
            );
    await _save(download);
    if (!ref.mounted) return;
    _memory.attempts.reset(volumeId);
    _checkNotificationPermissionOnce();
    _scheduleSubmit(volumeId);
  }

  /// まとめて積む（タイトル単位の一括ダウンロード。#10）。
  ///
  /// 並べた順に取得する（1 巻から順に読めるようになる）。
  Future<void> enqueueAll(Iterable<({int volumeId, int bookId})> items) async {
    for (final item in items) {
      await enqueue(volumeId: item.volumeId, bookId: item.bookId);
      if (!ref.mounted) return;
    }
  }

  /// 中断する（OS の転送は再開データを残して止める）。
  Future<void> pause(int volumeId) async {
    await future;
    if (!ref.mounted) return;

    final current = state.value?[volumeId];
    if (current == null || !current.isActive) return;
    // 転送はもう終わっていて、確定（検証・rename）を待っているだけ（F2）。
    // ここで止めると書き上がった ZIP を捨てる（確定の途中なら rename が
    // 失敗して「保存できませんでした」になる）。止める意味が無いので確定させる。
    if (_memory.installing.contains(volumeId) ||
        _memory.awaitingInstall.contains(volumeId)) {
      return;
    }
    final task = _memory.tasks[volumeId];

    if (task == null) {
      // 止める意図を台帳へ書く（F1）。投入の処理（マニフェスト取得中）は
      // ここで止めなくても、台帳を見て畳む。
      await _savePaused(current);
      return;
    }
    if (_memory.pausing.contains(volumeId)) {
      // 先の中断の処理中に「再開」され、もう一度「中断」された。最後の操作に
      // 従う（先の中断がそのまま止める）。
      _memory.resumeRequested.remove(volumeId);
      await _savePaused(current);
      return;
    }

    // F3: 中断の処理（台帳の書き込み〜OS との往復）の間に押された「再開」は
    // この処理が引き受ける。**最初の await より前に**印を付ける（台帳の
    // 書き込みを待つ間に押された「再開」が、止め終わる前に resume して
    // 断られ、先頭から積み直すことのないように）。
    _memory.pausing.add(volumeId);
    var paused = false;
    var pauseFailed = false;
    var wasRunning = false;
    bool pausedSeen;
    bool resumeRequested;
    try {
      // 止める意図を**先に台帳へ書く**（F1）。OS から届く paused は、台帳が
      // 中断になっているかどうかで「ユーザーが止めた」か「9 分の時間切れ /
      // Wi-Fi の切り替えによる一時的なもの」かを見分ける。
      await _savePaused(current);
      // 止める前に再開された（OS には何もしていないので、そのまま続く）/
      // 削除 / 積み直し / ログアウトされた（後はそちらに任せる）。
      if (!ref.mounted ||
          _memory.tasks[volumeId] != task ||
          _memory.resumeRequested.contains(volumeId)) {
        return;
      }
      // 走っている転送は一時停止する。待機中のものは、再開データがある
      // （続きから再開した / 時間切れや Wi-Fi 設定で再投入された）ときだけ
      // 一時停止の印に任せる（F11）。Android は待機中のタスクに印を付ける
      // だけなので、後で走り出して同時実行の枠を一瞬使ってから止まる。
      // それでも取り消すと、canceled は最終状態なのでパッケージが再開データを
      // 捨て、書きかけごと先頭から落とし直しになる。
      wasRunning = _memory.runningTasks.contains(volumeId);
      // 一度走った巻は、Dart から見えなくてもネイティブが再開データを
      // 持っている（[DownloadQueueMemory.hadProgress]）。再起動でそれを
      // 忘れた後は、ユーザーの一時停止で Dart に届いた再開データで判断する。
      final canPause =
          wasRunning ||
          _memory.hadProgress.contains(volumeId) ||
          await _hasResumeData(task);
      if (!ref.mounted ||
          _memory.tasks[volumeId] != task ||
          _memory.resumeRequested.contains(volumeId)) {
        return;
      }
      if (canPause) {
        try {
          paused = await _transport!.pause(task.toString());
        } on Object catch (error) {
          pauseFailed = true;
          debugPrint('[downloads] pause failed: $error');
        }
      }
    } finally {
      // ここまでに押された「再開」はこの後で扱う。この後に押されたものは
      // resume() 自身が扱う（同期的に引き継ぐので取りこぼさない）。
      _memory.pausing.remove(volumeId);
      pausedSeen = _memory.pausedSeen.remove(volumeId);
      resumeRequested = _memory.resumeRequested.remove(volumeId);
    }
    if (!ref.mounted) return;
    // 止めている間に削除 / 積み直し / ログアウトされた。後はそちらに任せる。
    if (_memory.tasks[volumeId] != task) return;

    if (resumeRequested) {
      // F3: OS に止めてもらっている間に「再開」が押された（台帳は待機中に
      // 戻っている）。再開データは止め終わってから届くので、paused が
      // 届いてから続きを取る。放置すると、ネイティブは止まったまま表示だけ
      // 「待機中」で動かなくなる。止めていない / 止められなかったなら、
      // そのまま走り続ける（書き上がっていれば完了が確定する）。
      if (!paused) return;
      _memory.liveTasks.remove(volumeId);
      _memory.runningTasks.remove(volumeId);
      if (pausedSeen) {
        await _resumeOrSubmit(task, generation: _generation);
      } else {
        _memory.resumeOnPaused.add(volumeId);
      }
      return;
    }
    if (paused) {
      _memory.liveTasks.remove(volumeId);
      _memory.runningTasks.remove(volumeId);
      if (!pausedSeen) _memory.pausedEventPending.add(volumeId);
      return;
    }
    if (wasRunning && !pauseFailed) {
      // 走っていたのに「止められない」と返った = ネイティブにはもう走っている
      // タスクが無い（書き上がって完了が届く途中 / 失敗した）。取り消しに回すと
      // 書き上がった ZIP（書き込み先そのもの）を消してしまう。取り消さず、
      // 届く最終状態に任せる: 完了なら確定（[ArchiveInstaller]）し、失敗なら台帳
      // （中断）のまま片付く。
      _memory.liveTasks.remove(volumeId);
      _memory.runningTasks.remove(volumeId);
      return;
    }
    // 再開データの無い待機中（holding queue で待っているだけ / 再試行待ち）の
    // 転送は捨てるものが無いので取り消す。中断中の表示のまま落としきらせない。
    await _cleanup.cancelTask(task);
  }

  /// OS 側にこの巻の転送（待機・走行・一時停止中の再開データ・確定待ち）が
  /// 残っているか。
  ///
  /// 「更新あり」の取り直しを中断した巻は、台帳が旧世代の完了に戻っていても
  /// 転送は残っている。自動削除（#13）は完了行しか見ないので、これで除く
  /// （消すと取り直しの続きと旧世代がまとめて失われる）。
  bool hasPendingTransfer(int volumeId) => _memory.tasks.containsKey(volumeId);

  /// 起動時の照合（OS 側の転送と台帳の突き合わせ）が終わったとき完了する。
  ///
  /// それまでは [hasPendingTransfer] が OS 側に残った転送を知らない。
  Future<void> get reconciled => _ready.future;

  Future<bool> _hasResumeData(ArchiveTaskId task) async {
    try {
      return await _transport!.hasResumeData(task.toString());
    } on Object catch (error) {
      debugPrint('[downloads] resume data lookup failed: $error');
      return false;
    }
  }

  /// 中断 / 失敗したダウンロードを続きから再開する。
  Future<void> resume(int volumeId) async {
    await future;
    if (!ref.mounted) return;
    final current = state.value?[volumeId];
    if (current == null || !current.isResumable) return;

    // F3: 中断の処理の最中（台帳の書き込み〜OS との往復）。今 resume しても
    // 再開データがまだ無いので、止め終わってから [pause] が続きを取る。
    // **最初の await より前に**確かめる。台帳の書き込みを待つ間に中断の
    // 処理が終わると、下で再開データの無い resume をして断られ、書きかけを
    // 捨てて先頭から積み直すことになる。
    final deferToPause =
        _memory.tasks.containsKey(volumeId) &&
        _memory.pausing.contains(volumeId);
    if (deferToPause) _memory.resumeRequested.add(volumeId);
    _memory.attempts.reset(volumeId);
    await _save(
      current.copyWith(
        status: VolumeDownloadStatus.queued,
        clearFailureReason: true,
      ),
    );
    if (!ref.mounted || deferToPause) return;

    final task = _memory.tasks[volumeId];
    if (task != null) {
      // 台帳の書き込みを待つ間に中断が始まった。
      if (_memory.pausing.contains(volumeId)) {
        _memory.resumeRequested.add(volumeId);
        return;
      }
      if (_memory.liveTasks.contains(volumeId)) return;
      if (_deferResumeUntilPaused(volumeId)) return;
      if (await _tryResume(task)) return;
      _memory.clearTask(volumeId);
      await _cleanup.forgetQuietly(task);
      if (!ref.mounted) return;
    }
    // 再開データが無い（アプリの再起動で消えた / 失敗で捨てられた）ので積み直す。
    _scheduleSubmit(volumeId);
  }

  /// キャンセル / 削除（巻単位）。
  ///
  /// 転送を止めてから、一時ファイルも完了済みのアーカイブも台帳も消す。
  Future<void> remove(int volumeId) async {
    await future;
    if (!ref.mounted) return;

    final task = _memory.tasks[volumeId];
    _memory.clearTask(volumeId);
    _memory.attempts.reset(volumeId);
    _memory.persistThrottle.forget(volumeId);
    _memory.installed.remove(volumeId);

    // 先に台帳を消す。メモリ（state）からは await の**前に**消す（F4）。
    // DB の削除を待つ間に確定（[ArchiveInstaller]）が進むと、state に
    // 行が残っていれば completed を保存し、その保存が削除の後に届いて
    // 「実体の無いダウンロード済み」が次の起動で復活する。取り消しの
    // await の間に届いた完了も、行が無いので取り込まない。
    final store = _store;
    _forget(volumeId);
    await store?.deleteRow(volumeId);
    if (task != null) await _cleanup.cancelTask(task);
    await store?.deleteFiles(volumeId);
  }

  /// 端末内のダウンロードを全部捨てる（ログアウト。#15）。
  ///
  /// 手順（転送の記録 → 台帳 → ファイル）は**全部試してから**、最初の失敗を
  /// 投げ直す。途中で止めると「台帳は消えず ZIP も残る」を作り、投げなければ
  /// 破棄の印（`SessionPurgeJournal`）が消えて次の起動でやり直されない。
  Future<void> purgeAll() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    void fail(String label, Object error, StackTrace stackTrace) {
      debugPrint('[downloads] purge $label failed: $error');
      if (firstError != null) return;
      firstError = error;
      firstStackTrace = stackTrace;
    }

    try {
      await future;
    } on Object catch (error) {
      // 台帳の読み込みなどに失敗してキューを組み立てられなくても、破棄は進める
      // （ここで投げると前のユーザーの ZIP と転送の記録が何も消えない）。
      debugPrint('[downloads] purge: queue unavailable: $error');
    }
    if (!ref.mounted) return;
    _generation++;
    // タグが決まるまでは、届いたイベントをすべて前のセッションのものとして扱う。
    _sessionTag = null;
    _memory.reset();

    var store = _store;
    if (store == null) {
      try {
        store = await ref.read(downloadStoreProvider.future);
      } on Object catch (error, stackTrace) {
        fail('store', error, stackTrace);
      }
      if (!ref.mounted) return;
    }
    // 組み立ての前に失敗していても転送の記録は消す（Bearer が平文で入っている）。
    final ArchiveTransport transport =
        _transport ?? ref.read(archiveTransportProvider);
    if (store != null) {
      try {
        // タグを作り直す。前のユーザーの転送の完了が後から届いても、
        // タグが違うので取り込まない（ファイルも残さない）。
        _sessionTag = await store.rotateSessionTag();
      } on Object catch (error) {
        // 保存できなくても、このプロセスの間は新しいタグで動かす。null の
        // ままだと投入が黙って何もせず、次のユーザーのダウンロードが
        // 「ダウンロード待ち」のまま始まらない。前のセッションの転送は
        // 下の reset で消すので、次の起動で古いタグに戻っても取り込むものは無い。
        debugPrint('[downloads] rotate session tag failed: $error');
        _sessionTag = ArchiveTaskId.newNonce();
      }
    } else {
      _sessionTag = ArchiveTaskId.newNonce();
    }
    try {
      // ファイルより先に消す。タスクの記録には Bearer が平文で入っている。
      await transport.reset();
    } on Object catch (error, stackTrace) {
      fail('transport reset', error, stackTrace);
    }
    if (store != null) {
      try {
        await store.deleteAllRows();
      } on Object catch (error, stackTrace) {
        fail('rows', error, stackTrace);
      }
      try {
        await store.deleteAllFiles();
      } on Object catch (error, stackTrace) {
        fail('files', error, stackTrace);
      }
    }
    if (ref.mounted) state = const AsyncData({});
    if (firstError case final error?) {
      Error.throwWithStackTrace(error, firstStackTrace ?? StackTrace.current);
    }
  }

  // ---------------------------------------------------------------- 投入

  /// 投入を積む（積んだ順に 1 本ずつ流す）。
  void _scheduleSubmit(int volumeId) {
    if (!_memory.submitting.add(volumeId)) {
      // 投入の処理中（マニフェスト取得 / 投入の await 中）に中断 → 再開された
      // などで、もう一度頼まれた。今の処理はその中断を見て畳むかもしれないので、
      // 終わってから改めて確かめる（積めていれば何もしない）。
      _memory.submitAgain.add(volumeId);
      return;
    }
    final generation = _generation;
    final ready = _ready;
    final link = _memory.submitChain.then((_) async {
      try {
        // 起動時の照合が終わるまで待つ。照合の前は OS 側に同じ巻の転送が
        // 残っているか分からず、二重に積んだり書きかけを消したりしかねない。
        await ready.future;
        await _submit(volumeId, generation);
      } finally {
        if (generation == _generation) {
          _memory.submitting.remove(volumeId);
          // 今の処理で積めていれば（_memory.tasks にある）取り直さない。
          final download = ref.mounted ? (state.value?[volumeId]) : null;
          if (_memory.submitAgain.remove(volumeId) &&
              download != null &&
              download.isActive &&
              !_memory.tasks.containsKey(volumeId)) {
            _scheduleSubmit(volumeId);
          }
        }
      }
    });
    _memory.submitChain = link.catchError((Object _) {});
    _track(link);
  }

  /// 待機のまま OS に渡っていない巻を投入し直す（回線の復帰 / 前面復帰）。
  void _submitPending() {
    if (!ref.mounted || !_ready.isCompleted) return;
    for (final download in state.value?.values ?? const <VolumeDownload>[]) {
      if (!download.isActive) continue;
      final volumeId = download.volumeId;
      if (_memory.awaitingInstall.contains(volumeId)) {
        final task = _memory.tasks[volumeId];
        if (task != null) _installer.schedule(task);
        continue;
      }
      if (_memory.tasks.containsKey(volumeId)) continue;
      _scheduleSubmit(volumeId);
    }
  }

  Future<void> _submit(int volumeId, int generation) async {
    final store = _store;
    final transport = _transport;
    final tag = _sessionTag;
    if (store == null || transport == null || tag == null) return;
    if (_isStale(generation)) return;
    var download = state.value?[volumeId];
    if (download == null || !download.isActive) return;

    // マニフェストは Dio で取る（今のトークンが付き、401 は AuthInterceptor が
    // セッション失効として扱う。401 の扱いの経路を増やさない）。
    final api = ref.read(volumesApiProvider);
    final VolumeManifest manifest;
    try {
      manifest = await api.fetchManifest(volumeId);
    } on Object catch (error) {
      if (_isStale(generation)) return;
      // 圏外で積めなかった初回の巻は待機のまま残し、回線が戻ったら積み直す
      // （まとめて積んだ 30 巻が一斉に「失敗」にならないように）。取り直しは
      // 旧世代へ戻して理由を出す（通信エラーで手元の世代を捨てない・黙らない）。
      // OS の表示はオンラインのまま届かなかった（サーバーが落ちていた等）場合も
      // 待機のまま残り、次の契機（回線の復帰 / 前面復帰 / Wi-Fi 待ちの解除 /
      // 次の起動）まで積み直さない。自宅サーバーを時間で叩き続けないため、
      // 時間での再試行はあえて持たない。
      if (isOfflineError(error) && !_memory.installed.containsKey(volumeId)) {
        return;
      }
      await _fail(
        volumeId,
        downloadErrorMessage(error),
        generation: generation,
      );
      return;
    }
    if (_isStale(generation)) return;
    download = state.value?[volumeId];
    // マニフェストを待っている間に中断 / 削除された。
    if (download == null || !download.isActive) return;

    // 同じ巻の転送が既にある。
    final existing = _memory.tasks[volumeId];
    if (existing != null) {
      final sameGeneration =
          existing.filesVersion == manifest.filesVersion &&
          existing.sessionTag == tag;
      if (sameGeneration &&
          (_memory.liveTasks.contains(volumeId) ||
              _memory.installing.contains(volumeId) ||
              _memory.awaitingInstall.contains(volumeId))) {
        return;
      }
      if (sameGeneration) {
        // 中断した取り直しを「更新あり」から再開した場合など。続きから取る。
        if (_deferResumeUntilPaused(volumeId)) return;
        if (await _tryResume(existing)) return;
        if (_isStale(generation)) return;
        _memory.clearTask(volumeId);
        await _cleanup.forgetQuietly(existing);
      } else {
        // 更新で世代が変わった。旧世代の転送は要らない。
        await _cleanup.cancelTask(existing);
      }
      if (_isStale(generation)) return;
    }

    await store.ensureVolumeDirectory(volumeId);
    final archive = store.archiveFile(
      volumeId: volumeId,
      filesVersion: manifest.filesVersion,
    );
    // 同じ世代が既に手元にある（取り直しの空振り / rename 済みで確定前に落ちた）。
    // 落とし直さないが、マニフェストの保存と旧世代の掃除はやり直す。
    if (archive.existsSync() &&
        (manifest.archiveBytes == 0 ||
            archive.lengthSync() == manifest.archiveBytes)) {
      await _installer.finish(volumeId, manifest, generation: generation);
      return;
    }

    // 中断中（台帳が中断 / 取り直しの中断で完了に戻したもの）の巻は、再開
    // されるか分からないので空きを押さえない。押さえたままだと、止めた巻の
    // 残りのせいで入るはずの巻が「空き容量が足りません」になる（起動時の照合も
    // 中断中の転送は数えない）。9 分の時間切れなどの一時的な停止は台帳が
    // 待機中 / 取得中のままなので、引き続き押さえる。
    final ledger = state.value ?? const <int, VolumeDownload>{};
    final reservedByOthers = _memory.reservations.reservedByOthers(
      volumeId,
      isActive: (id) => ledger[id]?.isActive ?? false,
    );
    if (await _hasNotEnoughSpace(manifest.archiveBytes + reservedByOthers)) {
      await _fail(
        volumeId,
        '端末の空き容量が足りません（${formatBytes(manifest.archiveBytes)} 必要です）。',
        generation: generation,
      );
      return;
    }
    if (_isStale(generation)) return;

    // 前回の残り（転送が消えた後の書きかけ）は使えないので捨てる。
    await TransferCleanup.deleteQuietly(
      store.stagingFile(
        volumeId: volumeId,
        filesVersion: manifest.filesVersion,
      ),
    );
    // マニフェストは**投入前に**書く。アプリが死んでいる間に転送が終わっても、
    // 次の起動でネットワーク無しに確定（ページ数の検証）できるようにするため。
    // ページ解決（#11）は台帳の世代しか見ないので、先に書いても「読める」と
    // 誤認されることは無い。
    try {
      await store.writeManifest(manifest);
    } on FileSystemException catch (error) {
      await _fail(
        volumeId,
        fileSystemFailureMessage(error),
        generation: generation,
      );
      return;
    }

    // 転送には署名付き URL を渡し、`Authorization` を付けない（#22）。付けると
    // 転送タスクの記録にログイン用トークンが平文で残る。発行は Dio で行う
    // （マニフェストと同じく、401 は AuthInterceptor の 1 経路に任せる）。
    final Uri uri;
    try {
      final archiveUrl = await api.fetchArchiveUrl(volumeId);
      if (_isStale(generation)) return;
      // マニフェストを取ってから発行するまでの間に ZIP が差し替わった。この URL
      // で落とすとマニフェスト（ページ数の検証に使う）と世代がずれる。積み直すと
      // 差し替えが続く間は回り続けるので、理由を出してユーザーの再試行に任せる。
      if (archiveUrl.filesVersion != manifest.filesVersion) {
        await _fail(
          volumeId,
          transferFailureMessage(
            const TransferFailure(kind: TransferFailureKind.resumeMismatch),
          ),
          generation: generation,
        );
        return;
      }
      uri = Uri.parse(archiveUrl.url);
    } on Object catch (error) {
      if (_isStale(generation)) return;
      // マニフェストの取得の失敗と同じ扱い（圏外の初回は待機のまま残す）。
      if (isOfflineError(error) && !_memory.installed.containsKey(volumeId)) {
        return;
      }
      await _fail(
        volumeId,
        downloadErrorMessage(error),
        generation: generation,
      );
      return;
    }
    download = state.value?[volumeId];
    if (download == null || !download.isActive) return;

    // 投入のたびに新しい ID にする（[ArchiveTaskId] のノンス参照）。前の
    // 転送に残った Android の一時停止の印で、この転送が止まらないように。
    final task = ArchiveTaskId(
      volumeId: volumeId,
      filesVersion: manifest.filesVersion,
      sessionTag: tag,
      nonce: ArchiveTaskId.newNonce(),
    );
    // 投入の前に登録する（直後に届くイベントを「今の転送」と判断できるように）。
    _memory.tasks[volumeId] = task;
    _memory.liveTasks.add(volumeId);
    // 先頭から取る転送。前の転送が走った記録は引き継がない。
    _memory.hadProgress.remove(volumeId);
    _memory.reservations.reserve(volumeId, manifest.archiveBytes);
    _memory.persistThrottle.restart(volumeId);
    // 世代にかかわる項目（filesVersion / pageCount / archive_etag）は**検証が
    // 通ってから**台帳に書く（[ArchiveInstaller]）。取り直しの途中で落ちても、
    // 台帳は端末にある旧世代を指したままにしておく（#11 のページ解決が実体の
    // 無い世代を指さないように）。進捗表示に要る全体バイト数だけ先に入れる。
    await _save(
      download.copyWith(receivedBytes: 0, totalBytes: manifest.archiveBytes),
    );

    var accepted = false;
    try {
      accepted = await transport.enqueue(
        ArchiveTransferRequest(
          taskId: task.toString(),
          uri: uri,
          headers: const {},
          directory: store.stagingDirectoryRelative(volumeId),
          filename: DownloadStore.stagingFilename(manifest.filesVersion),
          creationTime: _nextCreationTime(),
        ),
      );
    } on Object catch (error) {
      debugPrint('[downloads] enqueue failed: $error');
    }

    // 投入を待っている間に中断 / 削除 / ログアウトされた。投入済みなら止める
    // （「中断中」と表示したまま数百 MB を落としきらせない）。
    if (_isStale(generation) ||
        _memory.tasks[volumeId] != task ||
        !(state.value?[volumeId]?.isActive ?? false)) {
      if (!accepted) return;
      if (_memory.tasks[volumeId] == task) {
        // まだ自分の転送だが台帳は中断済み。OS 側で一時停止できていれば
        // （[pause] が _memory.liveTasks から外した）再開データを残す。
        if (_memory.liveTasks.contains(volumeId)) {
          await _cleanup.cancelTask(task);
        }
        return;
      }
      // F1: 中断 / 削除 / ログアウトの取り消しは、OS がまだこのタスクを
      // 知らない間に届いて空振りしたかもしれない（Android は投入と取り消しを
      // 別々のコルーチンで処理し、知らない ID の取り消しを覚えておかない）。
      // 受け付けられたと分かった今、もう一度取り消す（何度送っても害は無い）。
      // 放っておくと誰も追っていない転送が数百 MB を落とし、同時実行の枠を
      // 塞いで後ろの巻を待たせる。
      _memory.cancelling.add(task.toString());
      try {
        await transport.cancel(task.toString());
      } on Object catch (error) {
        debugPrint('[downloads] cancel after enqueue failed: $error');
      }
      if (!_isStale(generation)) {
        await _cleanup.deleteStagingUnlessCurrent(task);
        await _cleanup.forgetQuietly(task);
      }
      return;
    }
    if (!accepted) {
      _memory.clearTask(volumeId);
      await _fail(volumeId, '転送を開始できませんでした。', generation: generation);
    }
  }

  /// holding queue は priority → creationTime（ミリ秒）の順に取り出し、
  /// 同じ時刻の順序は保証しない（F4）。積んだ順に巻を落とすため、
  /// 必ず 1ms 以上増やす。
  DateTime _nextCreationTime() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = now > _lastCreationMs ? now : _lastCreationMs + 1;
    _lastCreationMs = next;
    return DateTime.fromMillisecondsSinceEpoch(next);
  }

  // ---------------------------------------------------------------- 失敗

  /// 転送の失敗を解釈する（再試行するか・何と出すか）。
  Future<void> _applyFailure(
    ArchiveTaskId task,
    TransferFailure failure, {
    required int generation,
  }) async {
    final volumeId = task.volumeId;
    final action = failureActionFor(
      failure,
      isWaitingForWifi: () => _isWaitingForWifi,
    );
    switch (action) {
      case FailureAction.giveUp:
        // 待っても直らない（削除済み / セーフモードで配信されない / 容量不足）。
        _memory.clearTask(volumeId);
        await _cleanup.forgetQuietly(task);
        await _fail(
          volumeId,
          transferFailureMessage(failure),
          generation: generation,
        );

      case FailureAction.recheckSession:
        // F2: ネイティブの 401 は「タスクに焼き込んだ古いトークン」に対する
        // もので、今のトークンが失効したとは限らない。すぐにログアウト
        // （数 GB の破棄）させず、マニフェストを Dio で取り直して確かめる。
        // 本当に失効していれば AuthInterceptor → handleSessionExpired の
        // 1 経路に合流し、生きていれば新しいトークンで積み直せる。
        if (!await _countAttempt(task, failure, generation: generation)) {
          return;
        }
        _memory.clearTask(volumeId);
        await _cleanup.forgetQuietly(task);
        if (_isStale(generation)) return;
        _scheduleSubmit(volumeId);

      case FailureAction.reissueFromScratch:
        // 署名付き URL が使えなくなった（#22）か、ZIP が差し替わっていた。
        // - 403: 期限切れ（最長 24 時間。長く中断していた巻の再開など）/ 改ざん /
        //   発行元トークンの失効。発行し直せば取れる。ログインごと失効していれば、
        //   発行（Dio）が 401 になって AuthInterceptor の 1 経路に合流する。
        // - 409 / 再開時の ETag の不一致: 続きを足すと別世代が混ざる。
        // どちらも書きかけは使えないので、マニフェストから取り直して先頭から落とす。
        if (!await _countAttempt(task, failure, generation: generation)) {
          return;
        }
        _memory.clearTask(volumeId);
        await _cleanup.deleteStaging(task);
        await _cleanup.forgetQuietly(task);
        if (_isStale(generation)) return;
        // Android が残した書きかけの一時ファイルも掃除する（[_resubmit] と同じく
        // 投入より先に鎖に載せる）。
        _cleanup.scheduleTempSweep();
        _scheduleSubmit(volumeId);

      case FailureAction.resubmitUncounted:
        // F3: Wi-Fi 限定で Wi-Fi が切れた失敗は回数に数えない。積み直せば、
        // ネイティブが Wi-Fi に戻るまで待ってから取り始める（判断の詳細は
        // [failureActionFor]）。
        await _resubmit(task, generation: generation);

      case FailureAction.retryWithBackoff:
        if (!await _countAttempt(task, failure, generation: generation)) {
          return;
        }
        // 上限で失敗にする。待つ間隔は [retryBackoff]。
        await ref.read(downloadRetryDelayProvider)(
          retryBackoff(_memory.attempts.current(volumeId)),
        );
        if (_isStale(generation) || !_isCurrent(task)) return;
        await _resubmit(task, generation: generation);
    }
  }

  /// 試行を 1 回数える。上限に達したら失敗にして `false`。
  ///
  /// 失敗（failed）でパッケージは再開データを捨てている（F9）ので、転送の
  /// 記録も捨てる。「再開」は先頭から積み直しになる。
  Future<bool> _countAttempt(
    ArchiveTaskId task,
    TransferFailure failure, {
    required int generation,
  }) async {
    final volumeId = task.volumeId;
    if (_memory.attempts.count(volumeId)) return true;
    if (_memory.tasks[volumeId] == task) _memory.clearTask(volumeId);
    await _cleanup.forgetQuietly(task);
    await _fail(
      volumeId,
      transferFailureMessage(failure),
      generation: generation,
    );
    return false;
  }

  /// 失敗した転送を先頭から積み直す（F9）。
  ///
  /// パッケージは failed を最終状態として扱い、こちらに届く前に再開データを
  /// 捨てる（`base_downloader.dart` の `_clearPauseResumeInfo`）。Range で
  /// 続きを取れる見込みは無いので、再開を試さない（試すと「続きから取る」
  /// ように見えて実は先頭から、になるだけ）。Android が残した書きかけの
  /// 一時ファイルは [ArchiveTransport.sweepOrphanTempFiles] が消す。
  /// 圏外で失敗したものはパッケージ自身が「再試行待ち」で抱え、再開データも
  /// 残すので、ここには来ない。
  Future<void> _resubmit(ArchiveTaskId task, {required int generation}) async {
    if (_isStale(generation) || !_isCurrent(task)) return;
    _memory.clearTask(task.volumeId);
    await _cleanup.forgetQuietly(task);
    if (_isStale(generation)) return;
    // 積み直しは新しい一時ファイルに書く。他の巻が走り続けていても、置き去りの
    // 書きかけを掃除する（投入より先に鎖に載せ、空き容量の判定に間に合わせる）。
    _cleanup.scheduleTempSweep();
    _scheduleSubmit(task.volumeId);
  }

  /// 再開データがあれば続きから、無ければ積み直す（一時停止から戻すとき）。
  Future<void> _resumeOrSubmit(
    ArchiveTaskId task, {
    required int generation,
  }) async {
    if (_isStale(generation) || !_isCurrent(task)) return;
    if (await _tryResume(task)) return;
    if (_isStale(generation) || !_isCurrent(task)) return;
    _memory.clearTask(task.volumeId);
    await _cleanup.forgetQuietly(task);
    if (_isStale(generation)) return;
    _scheduleSubmit(task.volumeId);
  }

  /// 一時停止を受け付けてもらい、止め終わりの paused を待っている巻なら、
  /// 届いてから続きを取るよう予約して `true`。
  ///
  /// 再開データは paused と一緒に届くので、その前の resume は断られる
  /// （パッケージの `resume` は再開データが無ければ `false`）。断られて
  /// 積み直すと書きかけを捨てて先頭からになる。
  bool _deferResumeUntilPaused(int volumeId) {
    if (!_memory.pausedEventPending.contains(volumeId)) return false;
    _memory.resumeOnPaused.add(volumeId);
    return true;
  }

  Future<bool> _tryResume(ArchiveTaskId task) async {
    var resumed = false;
    try {
      resumed = await _transport!.resume(task.toString());
    } on Object catch (error) {
      debugPrint('[downloads] resume failed: $error');
    }
    if (resumed && _memory.tasks[task.volumeId] == task) {
      _memory.liveTasks.add(task.volumeId);
    }
    return resumed;
  }

  // ---------------------------------------------------------------- 台帳

  Future<void> _fail(
    int volumeId,
    String reason, {
    required int generation,
    bool resetProgress = false,
  }) async {
    if (_isStale(generation)) return;
    final current = state.value?[volumeId];
    if (current == null) return;

    // 取り直しの失敗では、端末に残っている旧世代の「ダウンロード済み」へ戻す。
    // 通信エラーでオフラインに読めるものを失わせない（CLAUDE.md）。理由は
    // 残すので、UI は「更新の取得に失敗」として見せられる（黙って隠さない）。
    final installed = _takeInstalled(current);
    if (installed != null) {
      await _save(installed.copyWith(failureReason: reason));
      return;
    }

    await _save(
      current.copyWith(
        status: VolumeDownloadStatus.failed,
        receivedBytes: resetProgress ? 0 : null,
        failureReason: reason,
      ),
    );
    _cleanup.scheduleTempSweep();
  }

  /// 取り直しの起点になる「手元にある完了済みの世代」を覚える。
  ///
  /// 台帳が completed でも実体が無ければ戻る先にならないので、ZIP の実在を見る。
  void _rememberInstalled(VolumeDownload download) {
    final store = _store;
    final archive = store?.archiveFile(
      volumeId: download.volumeId,
      filesVersion: download.filesVersion,
    );
    if (!download.isCompleted || archive == null || !archive.existsSync()) {
      _memory.installed.remove(download.volumeId);
      return;
    }
    _memory.installed[download.volumeId] = download;
  }

  /// 中断として台帳を書く。
  ///
  /// 取り直しの中断なら「中断中」にはせず手元の旧世代へ戻す。新世代を指す
  /// 中断行にしてしまうと、実体のある旧世代を指す行が台帳から消えてしまい、
  /// オフラインで読めるはずの巻が読めなくなる（転送の再開データは残るので、
  /// もう一度「更新あり」を押せば続きから取り直せる）。
  Future<void> _savePaused(VolumeDownload current) async {
    final installed = _takeInstalled(current);
    if (installed != null) {
      await _save(installed);
      return;
    }
    await _save(current.copyWith(status: VolumeDownloadStatus.paused));
  }

  /// 取り直しの戻り先（手元にある旧世代の完了行）を取り出す。
  ///
  /// 普段は取り直しを始めたときに覚えた [DownloadQueueMemory.installed] を
  /// 使う。アプリの再起動でそれを忘れた後も、台帳の行は世代の項目（filesVersion / pageCount /
  /// archive_etag）を検証が通ってからしか書かないので旧世代を指したまま。
  /// その ZIP が実在すれば、そこから完了行を作り直す。作り直さないと、
  /// 再起動後の「更新を中止」や失敗で「中断中 / 失敗（旧世代が読める）」という
  /// 行になり、完了に戻る道が「再開」しか無くなる（「更新あり」も自動削除も
  /// 完了行しか見ない）。
  VolumeDownload? _takeInstalled(VolumeDownload current) {
    final remembered = _memory.installed.remove(current.volumeId);
    if (remembered != null) return remembered;
    if (current.isCompleted || !current.hasInstalledArchive) return null;
    final store = _store;
    if (store == null) return null;
    final archive = store.archiveFile(
      volumeId: current.volumeId,
      filesVersion: current.filesVersion,
    );
    final int bytes;
    try {
      if (!archive.existsSync()) return null;
      bytes = archive.lengthSync();
    } on FileSystemException {
      return null;
    }
    return current.copyWith(
      status: VolumeDownloadStatus.completed,
      // 進捗が新しい世代の大きさで上書きされているので、実体の大きさに戻す。
      receivedBytes: bytes,
      totalBytes: bytes,
      clearFailureReason: true,
      // 旧世代の確定時刻は再起動で失われている（完了以外の行には残さない）。
      // 早く消す側に倒さないよう、戻した時刻から数える。
      completedAt: store.now(),
    );
  }

  // ---------------------------------------------------------------- 小道具

  /// 通知の許可を、最初にダウンロードを積んだときに一度だけ求める。
  ///
  /// 起動時に聞くと「何の通知か」が分からない。断られても転送は続く。
  void _checkNotificationPermissionOnce() {
    if (_notificationChecked) return;
    _notificationChecked = true;
    final transport = _transport;
    if (transport == null) return;
    final settings = ref.read(downloadSettingsStoreProvider);
    _track(
      Future<void>(() async {
        if (await settings.readNotificationPermissionRequested()) return;
        await settings.markNotificationPermissionRequested();
        await transport.requestNotificationPermission();
      }),
    );
  }

  Future<bool> _readWifiOnly() async {
    try {
      return await ref.read(downloadWifiOnlyProvider.future);
    } on Object {
      // 読めなければモバイル回線で数百 MB を使わない側に倒す。
      return true;
    }
  }

  bool get _isWaitingForWifi =>
      ref.mounted &&
      ref.read(downloadGateProvider) == DownloadGate.waitingForWifi;

  bool _isCurrent(ArchiveTaskId task) =>
      _memory.tasks[task.volumeId] == task &&
      (state.value?[task.volumeId]?.isActive ?? false);

  /// 投げっぱなしの処理を追跡する（例外はログに出して握る。UI に漏らさない）。
  void _track(Future<void> work) {
    late final Future<void> tracked;
    tracked = work
        .catchError((Object error, StackTrace stack) {
          debugPrint('[downloads] $error\n$stack');
        })
        .whenComplete(() => _pending.remove(tracked));
    _pending.add(tracked);
  }

  Future<void> _save(VolumeDownload download) async {
    _emit(download);
    await _store?.save(download);
  }

  void _emit(VolumeDownload? download) {
    if (download == null || !ref.mounted) return;
    final next = {...?state.value, download.volumeId: download};
    state = AsyncData(next);
  }

  void _forget(int volumeId) {
    if (!ref.mounted) return;
    final next = <int, VolumeDownload>{...?state.value}..remove(volumeId);
    state = AsyncData(next);
  }

  bool _isStale(int generation) => generation != _generation || !ref.mounted;

  /// [_QueueHost] から `ref` / `state` を読むための中継（protected のため）。
  Ref get _ref => ref;
  Map<int, VolumeDownload>? get _ledger => state.value;

  Future<bool> _hasNotEnoughSpace(int requiredBytes) async {
    if (requiredBytes <= 0) return false;
    final free = await ref.read(freeSpaceProbeProvider)();
    // 取得できない端末では止めない（誤検知でダウンロードを塞がない）。
    if (free == null) return false;
    return free < requiredBytes + freeSpaceMarginBytes;
  }
}

/// 部品から [DownloadQueue] へ戻る窓口（#32）。
///
/// `DownloadQueue` 自身に [DownloadQueueHost] を実装させると、台帳の書き込みなど
/// が Notifier の公開メソッドになってしまうため、内部クラスで中継する。
class _QueueHost implements DownloadQueueHost {
  _QueueHost(this._queue);

  final DownloadQueue _queue;

  @override
  Ref get ref => _queue._ref;

  @override
  bool get mounted => _queue._ref.mounted;

  @override
  int get generation => _queue._generation;

  @override
  bool isStale(int generation) => _queue._isStale(generation);

  @override
  Completer<void> get ready => _queue._ready;

  @override
  DownloadStore? get store => _queue._store;

  @override
  ArchiveTransport? get transport => _queue._transport;

  @override
  String? get sessionTag => _queue._sessionTag;

  @override
  Map<int, VolumeDownload>? get ledger => _queue._ledger;

  @override
  bool isCurrent(ArchiveTaskId task) => _queue._isCurrent(task);

  @override
  void track(Future<void> work) => _queue._track(work);

  @override
  void emit(VolumeDownload? download) => _queue._emit(download);

  @override
  Future<void> save(VolumeDownload download) => _queue._save(download);

  @override
  Future<void> savePaused(VolumeDownload current) =>
      _queue._savePaused(current);

  @override
  Future<void> fail(
    int volumeId,
    String reason, {
    required int generation,
    bool resetProgress = false,
  }) => _queue._fail(
    volumeId,
    reason,
    generation: generation,
    resetProgress: resetProgress,
  );

  @override
  void scheduleSubmit(int volumeId) => _queue._scheduleSubmit(volumeId);

  @override
  void scheduleInstall(ArchiveTaskId task) => _queue._installer.schedule(task);

  @override
  Future<void> resumeOrSubmit(ArchiveTaskId task, {required int generation}) =>
      _queue._resumeOrSubmit(task, generation: generation);

  @override
  Future<void> applyFailure(
    ArchiveTaskId task,
    TransferFailure failure, {
    required int generation,
  }) => _queue._applyFailure(task, failure, generation: generation);
}
