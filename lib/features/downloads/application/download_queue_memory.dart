import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/archive_transport.dart';
import '../data/download_store.dart';
import '../domain/archive_task_id.dart';
import '../domain/volume_download.dart';
import 'download_failure_policy.dart';
import 'download_progress_book.dart';

/// [DownloadQueue] とその部品（照合 / イベントの reducer / 確定 / 後始末）が
/// 共有する、メモリ上の可変状態。
///
/// 持ち主は `DownloadQueue` で、部品には同じインスタンスを渡す（#32）。
/// 部品ごとに状態を分けないのは、巻ごとの印（今の転送・走行中・確定待ちなど）を
/// 複数の部品が同じ await の合間に読み書きするため。分けると「どちらが正か」が
/// 曖昧になり、[clearTask] の取りこぼしで古い印が残る。
///
/// 再構築 / ログアウト（`purgeAll`）では [reset] でまとめて捨てる。
class DownloadQueueMemory {
  /// 取り直しを始めた時点で端末にあった「完了済みの世代」。
  ///
  /// 「更新あり」の取り直しが失敗 / 中断しても、台帳はここへ戻す。
  /// 通信の失敗で手元のキャッシュ（オフラインで読める旧世代）を捨てないため
  /// （落とし直しに失敗した瞬間に、読める ZIP を指す行が台帳から消えてしまう）。
  final installed = <int, VolumeDownload>{};

  /// 進捗を DB へ書く間引き（最後に書いた受信バイト数）。
  final persistThrottle = ProgressPersistThrottle();

  /// 巻ごとの「今の転送」。
  ///
  /// 走行中だけでなく、一時停止中（再開データがある）・再試行待ちも含む。
  /// ここに無い転送のイベントは、古い世代や取り消し済みのものとして扱う。
  final tasks = <int, ArchiveTaskId>{};

  /// OS 側で待機中 / 走行中の巻（二重に積まない判定に使う）。
  final liveTasks = <int>{};

  /// OS 側で実際に走っている（`running` / 進捗が届いた）巻。
  ///
  /// 一時停止できるのはこれだけ（F11）。Android のパッケージは、holding
  /// queue や Wi-Fi 待ちで待機しているだけのタスクにも「止めた」と返す
  /// （印を付けるだけ）ので、待機中のものは取り消しに回す。
  final runningTasks = <int>{};

  /// 今の転送が一度でも走った（`running` / 進捗 / paused が届いた）巻。
  ///
  /// 待機中の巻を中断するとき、取り消すか一時停止の印に任せるかを決める
  /// （F11）。Android の時間切れ（`BDPlugin.doEnqueue` へ直接渡す）と
  /// Wi-Fi 設定の変更（`localResumeData`）による再投入は、再開データを
  /// ネイティブ側にしか持たず Dart の保存領域に載せない。パッケージの
  /// 再開データの有無だけで決めると、その巻の中断が取り消しになり、
  /// 書きかけを捨てて先頭から落とし直しになる。印を付けておけば、走り
  /// 出したときにネイティブの再開データで続きを取れる状態のまま止まる。
  /// 新しく積んだ（先頭から取る）とき・転送を手放したときに外す。
  final hadProgress = <int>{};

  /// OS に一時停止を頼んでいる最中の巻（その往復の間に「再開」が押されうる）。
  final pausing = <int>{};

  /// 一時停止を頼んでいる最中に「再開」が押された巻（F3）。
  final resumeRequested = <int>{};

  /// 一時停止を頼んでいる最中に、OS から paused が届いた巻。
  final pausedSeen = <int>{};

  /// OS から paused が届いたら続きを取る巻（止め終わる前に「再開」された）。
  final resumeOnPaused = <int>{};

  /// 一時停止を受け付けてもらったが、まだ paused が届いていない巻。
  ///
  /// 「止めた」はネイティブが受け付けただけで、再開データは止め終わりの
  /// paused と一緒に届く。その前に resume すると断られ、先頭から積み直しに
  /// なる。
  final pausedEventPending = <int>{};

  /// 起動時の照合の前に届いた完了（taskId）。
  ///
  /// 照合の一覧（記録）に載っていなくても、完了が届いたなら書き上がった
  /// ZIP がある。照合がそれを孤児として掃除しないよう、一覧に足す（F6）。
  final earlyCompleted = <String>{};

  /// 投入の処理中にもう一度頼まれた巻（終わったら改めて投入を確かめる）。
  final submitAgain = <int>{};

  /// 転送は終わったが、確定（検証・rename）がまだの巻。
  ///
  /// マニフェストが手元に無く、オフラインで確定できなかったものが残る。
  /// 回線が戻ったらやり直す。
  final awaitingInstall = <int>{};

  /// 確定の処理に載っている巻（二重に積まない）。
  final installing = <int>{};

  /// 投入の処理に載っている巻（二重に積まない）。
  final submitting = <int>{};

  /// 自分で取り消した転送。届いた canceled を「通知の Cancel ボタン」と
  /// 取り違えないために覚えておく。
  final cancelling = <String>{};

  /// 巻ごとの転送の試行回数（再試行の上限）。
  final attempts = DownloadAttempts();

  /// OS に渡して未確定の巻の残りバイト数（空き容量の判定に含める。F7）。
  final reservations = SpaceReservations();

  /// 投入を積んだ順に 1 本ずつ流す（`creationTime` の順番を崩さない）。
  /// 一時ファイルの掃除も同じ鎖に載せる（`TransferCleanup.scheduleTempSweep`）。
  Future<void> submitChain = Future.value();

  /// 一時ファイルの掃除が鎖に載って、まだ始まっていない（重ねて載せない）。
  bool tempSweepQueued = false;

  /// 転送のイベントを届いた順に 1 つずつ処理する。
  Future<void> eventChain = Future.value();

  /// 確定（検証・rename）を 1 巻ずつ行う（同じ巻の完了の再送と競らせない）。
  Future<void> installChain = Future.value();

  /// 巻の「今の転送」を手放す（その転送に付いた印をすべて外す）。
  ///
  /// 試行回数（[attempts]）・取り直しの戻り先（[installed]）・進捗の間引き・
  /// 投入 / 中断の処理中の印は外さない。それぞれ、積み直しをまたいで数える /
  /// 失敗時に旧世代へ戻す / 処理中の側が自分で外すもののため。
  void clearTask(int volumeId) {
    tasks.remove(volumeId);
    liveTasks.remove(volumeId);
    runningTasks.remove(volumeId);
    hadProgress.remove(volumeId);
    awaitingInstall.remove(volumeId);
    installing.remove(volumeId);
    reservations.release(volumeId);
    resumeRequested.remove(volumeId);
    pausedSeen.remove(volumeId);
    resumeOnPaused.remove(volumeId);
    pausedEventPending.remove(volumeId);
  }

  /// すべて捨てる（再構築 / ログアウト）。鎖も新しくする。
  void reset() {
    installed.clear();
    persistThrottle.clear();
    tasks.clear();
    liveTasks.clear();
    runningTasks.clear();
    hadProgress.clear();
    pausing.clear();
    resumeRequested.clear();
    pausedSeen.clear();
    resumeOnPaused.clear();
    pausedEventPending.clear();
    earlyCompleted.clear();
    submitAgain.clear();
    awaitingInstall.clear();
    installing.clear();
    submitting.clear();
    cancelling.clear();
    attempts.clear();
    reservations.clear();
    submitChain = Future.value();
    tempSweepQueued = false;
    eventChain = Future.value();
    installChain = Future.value();
  }
}

/// 部品から `DownloadQueue`（調停役）へ戻る窓口。
///
/// 台帳（state）の書き込み・世代の判定・投入 / 確定 / 再試行の予約は
/// 調停役だけが持つ。部品はここを通して頼み、自分では state を触らない。
/// `DownloadQueue` の公開 API を増やさないよう、実装は download_queue.dart の
/// 内部クラスにする。
abstract interface class DownloadQueueHost {
  Ref get ref;

  /// `ref.mounted`。
  bool get mounted;

  /// 破棄の世代（`purgeAll` と再構築のたびに進む）。
  int get generation;

  /// 世代が変わった / 破棄された。
  bool isStale(int generation);

  /// 起動時の照合が終わったときに完了する（再構築で作り直される）。
  Completer<void> get ready;

  DownloadStore? get store;
  ArchiveTransport? get transport;

  /// 今のログインセッションのタグ（`null` は破棄の途中）。
  String? get sessionTag;

  /// 台帳（`state.value`）。
  Map<int, VolumeDownload>? get ledger;

  /// [task] が巻の「今の転送」で、台帳も待機中 / 取得中のままか。
  bool isCurrent(ArchiveTaskId task);

  /// 投げっぱなしの処理を追跡する（例外はログに出して握る）。
  void track(Future<void> work);

  /// state だけに反映する（DB へは書かない）。
  void emit(VolumeDownload? download);

  /// state と DB に書く。
  Future<void> save(VolumeDownload download);

  /// 中断として台帳を書く（取り直しなら旧世代へ戻す）。
  Future<void> savePaused(VolumeDownload current);

  /// 失敗として台帳を書く（取り直しなら旧世代へ戻す）。
  Future<void> fail(
    int volumeId,
    String reason, {
    required int generation,
    bool resetProgress = false,
  });

  void scheduleSubmit(int volumeId);
  void scheduleInstall(ArchiveTaskId task);

  /// 再開データがあれば続きから、無ければ積み直す。
  Future<void> resumeOrSubmit(ArchiveTaskId task, {required int generation});

  /// 転送の失敗を解釈する（再試行するか・何と出すか）。
  Future<void> applyFailure(
    ArchiveTaskId task,
    TransferFailure failure, {
    required int generation,
  });
}
