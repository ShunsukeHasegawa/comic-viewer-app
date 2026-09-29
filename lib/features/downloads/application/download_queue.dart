import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/device/app_resume_monitor.dart';
import '../../../core/device/connectivity_monitor.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/format.dart';
import '../../../data/api/volumes_api.dart';
import '../../../domain/models/volume_manifest.dart';
import '../../auth/data/auth_store.dart';
import '../../offline/application/offline_detail_warmer.dart';
import '../data/archive_transport.dart';
import '../data/archive_verifier.dart';
import '../data/background_archive_transport.dart';
import '../data/download_store.dart';
import '../data/free_space_probe.dart';
import '../domain/archive_task_id.dart';
import '../domain/volume_download.dart';
import 'download_settings.dart';

part 'download_queue.g.dart';

/// 再試行の待ち時間（テストから即時にできるようにする）。
typedef RetryDelay = Future<void> Function(Duration duration);

@Riverpod(keepAlive: true)
RetryDelay downloadRetryDelay(Ref ref) => Future<void>.delayed;

/// 1 巻あたりの転送の試行回数（初回を含む）。
const maxDownloadAttempts = 3;

/// 空き容量チェックの余裕分。
///
/// ぴったり入るだけの空きしか無い状態で始めると、OS やほかのアプリの書き込みで
/// 途中で詰まる。
const freeSpaceMarginBytes = 64 * 1024 * 1024;

/// 進捗を DB へ書く間隔（バイト）。
///
/// 毎回書くと 1 巻で数千回の UPDATE になる。再開位置は OS の転送が持って
/// いるので、DB の値は表示の復元用で多少古くてよい。
const progressPersistIntervalBytes = 4 * 1024 * 1024;

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
@Riverpod(keepAlive: true)
class DownloadQueue extends _$DownloadQueue {
  /// 取り直しを始めた時点で端末にあった「完了済みの世代」。
  ///
  /// 「更新あり」の取り直しが失敗 / 中断しても、台帳はここへ戻す。
  /// 通信の失敗で手元のキャッシュ（オフラインで読める旧世代）を捨てないため
  /// （落とし直しに失敗した瞬間に、読める ZIP を指す行が台帳から消えてしまう）。
  final _installed = <int, VolumeDownload>{};

  /// 最後に DB へ書いた受信バイト数。
  final _persistedBytes = <int, int>{};

  /// 巻ごとの「今の転送」。
  ///
  /// 走行中だけでなく、一時停止中（再開データがある）・再試行待ちも含む。
  /// ここに無い転送のイベントは、古い世代や取り消し済みのものとして扱う。
  final _tasks = <int, ArchiveTaskId>{};

  /// OS 側で待機中 / 走行中の巻（二重に積まない判定に使う）。
  final _liveTasks = <int>{};

  /// OS 側で実際に走っている（`running` / 進捗が届いた）巻。
  ///
  /// 一時停止できるのはこれだけ（F11）。Android のパッケージは、holding
  /// queue や Wi-Fi 待ちで待機しているだけのタスクにも「止めた」と返す
  /// （印を付けるだけ）ので、待機中のものは取り消しに回す。
  final _runningTasks = <int>{};

  /// OS に一時停止を頼んでいる最中の巻（その往復の間に「再開」が押されうる）。
  final _pausing = <int>{};

  /// 一時停止を頼んでいる最中に「再開」が押された巻（F3）。
  final _resumeRequested = <int>{};

  /// 一時停止を頼んでいる最中に、OS から paused が届いた巻。
  final _pausedSeen = <int>{};

  /// OS から paused が届いたら続きを取る巻（止め終わる前に「再開」された）。
  final _resumeOnPaused = <int>{};

  /// 起動時の照合の前に届いた完了（taskId）。
  ///
  /// 照合の一覧（記録）に載っていなくても、完了が届いたなら書き上がった
  /// ZIP がある。照合がそれを孤児として掃除しないよう、一覧に足す（F6）。
  final _earlyCompleted = <String>{};

  /// 投入の処理中にもう一度頼まれた巻（終わったら改めて投入を確かめる）。
  final _submitAgain = <int>{};

  /// 転送は終わったが、確定（検証・rename）がまだの巻。
  ///
  /// マニフェストが手元に無く、オフラインで確定できなかったものが残る。
  /// 回線が戻ったらやり直す。
  final _awaitingInstall = <int>{};

  /// 確定の処理に載っている巻（二重に積まない）。
  final _installing = <int>{};

  /// 投入の処理に載っている巻（二重に積まない）。
  final _submitting = <int>{};

  /// 自分で取り消した転送。届いた canceled を「通知の Cancel ボタン」と
  /// 取り違えないために覚えておく。
  final _cancelling = <String>{};

  /// 巻ごとの転送の試行回数（再試行の上限）。
  final _attempts = <int, int>{};

  /// OS に渡して未確定の巻の残りバイト数（空き容量の判定に含める。F7）。
  ///
  /// 空き容量を 1 巻ずつ見ると、まとめて積んだ 30 巻がどれも「入る」と
  /// 判定され、後半が転送の途中で容量不足になる。
  final _reservedBytes = <int, int>{};

  /// 進行中の非同期処理（テストで「落ち着くまで待つ」ために使う）。
  final _pending = <Future<void>>{};

  /// 投入を積んだ順に 1 本ずつ流す（`creationTime` の順番を崩さない）。
  Future<void> _submitChain = Future.value();

  /// 転送のイベントを届いた順に 1 つずつ処理する。
  Future<void> _eventChain = Future.value();

  /// 確定（検証・rename）を 1 巻ずつ行う（同じ巻の完了の再送と競らせない）。
  Future<void> _installChain = Future.value();

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
    _resetMemory();
    final ready = _ready = Completer<void>();
    ref.onDispose(() {
      if (!ready.isCompleted) ready.complete();
    });

    final transport = ref.watch(archiveTransportProvider);
    _transport = transport;
    // 先に購読する。`start` の中で、アプリが死んでいる間に終わった転送の
    // 完了が届く。
    final events = transport.events.listen(_onEvent);
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
    final resumed = ref
        .read(appResumeMonitorProvider)
        .onResumed
        .listen((_) => _submitPending());
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
              // 同じ ID で積み直すので、走っていたとしても同じ転送になる。
              debugPrint('[downloads] snapshot failed: $error');
              snapshots = const [];
            }
            if (_isStale(generation)) return;
            await _reconcile(snapshots, generation);
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
    _attempts.remove(volumeId);
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
    if (_installing.contains(volumeId) || _awaitingInstall.contains(volumeId)) {
      return;
    }
    final task = _tasks[volumeId];

    // 止める意図を**先に台帳へ書く**（F1）。OS から届く paused は、台帳が
    // 中断になっているかどうかで「ユーザーが止めた」か「9 分の時間切れ /
    // Wi-Fi の切り替えによる一時的なもの」かを見分ける。
    await _savePaused(current);
    if (task == null || !ref.mounted) return;
    // 投入の処理（マニフェスト取得中）はここで止めなくても、台帳を見て畳む。

    var paused = false;
    // 走っている転送だけを一時停止する（F11）。待機中のものに頼むと、Android は
    // 「止めた」と返したまま待機に残し、後で走り出して同時実行の枠を使う。
    if (_runningTasks.contains(volumeId)) {
      _pausing.add(volumeId);
      try {
        paused = await _transport!.pause(task.toString());
      } on Object catch (error) {
        debugPrint('[downloads] pause failed: $error');
      } finally {
        _pausing.remove(volumeId);
      }
      if (!ref.mounted) return;
    }
    final pausedSeen = _pausedSeen.remove(volumeId);
    final resumeRequested = _resumeRequested.remove(volumeId);
    // 止めている間に削除 / 積み直し / ログアウトされた。後はそちらに任せる。
    if (_tasks[volumeId] != task) return;

    if (resumeRequested) {
      // F3: OS に止めてもらっている間に「再開」が押された（台帳は待機中に
      // 戻っている）。再開データは止め終わってから届くので、paused が
      // 届いてから続きを取る。放置すると、ネイティブは止まったまま表示だけ
      // 「待機中」で動かなくなる。止められなかったなら、そのまま走り続ける。
      if (!paused) return;
      _liveTasks.remove(volumeId);
      _runningTasks.remove(volumeId);
      if (pausedSeen) {
        await _resumeOrSubmit(task, generation: _generation);
      } else {
        _resumeOnPaused.add(volumeId);
      }
      return;
    }
    if (paused) {
      _liveTasks.remove(volumeId);
      _runningTasks.remove(volumeId);
      return;
    }
    // 走っていない（holding queue で待っているだけ / 再試行待ち）転送は
    // 一時停止できないので取り消す。中断中の表示のまま落としきらせない。
    await _cancelTask(task);
  }

  /// 中断 / 失敗したダウンロードを続きから再開する。
  Future<void> resume(int volumeId) async {
    await future;
    if (!ref.mounted) return;
    final current = state.value?[volumeId];
    if (current == null || !current.isResumable) return;

    _attempts.remove(volumeId);
    await _save(
      current.copyWith(
        status: VolumeDownloadStatus.queued,
        clearFailureReason: true,
      ),
    );
    if (!ref.mounted) return;

    final task = _tasks[volumeId];
    if (task != null) {
      // F3: 中断の最中（OS へ一時停止を頼んでいる往復の間）。今 resume しても
      // 再開データがまだ無いので、止め終わってから [pause] が続きを取る。
      if (_pausing.contains(volumeId)) {
        _resumeRequested.add(volumeId);
        return;
      }
      if (_liveTasks.contains(volumeId)) return;
      if (await _tryResume(task)) return;
      _clearTask(volumeId);
      await _forgetQuietly(task);
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

    final task = _tasks[volumeId];
    _clearTask(volumeId);
    _attempts.remove(volumeId);
    _persistedBytes.remove(volumeId);
    _installed.remove(volumeId);

    // 先に台帳を消す。メモリ（state）からは await の**前に**消す（F4）。
    // DB の削除を待つ間に確定（[_finish] / [_complete]）が進むと、state に
    // 行が残っていれば completed を保存し、その保存が削除の後に届いて
    // 「実体の無いダウンロード済み」が次の起動で復活する。取り消しの
    // await の間に届いた完了も、行が無いので取り込まない。
    final store = _store;
    _forget(volumeId);
    await store?.deleteRow(volumeId);
    if (task != null) await _cancelTask(task);
    await store?.deleteFiles(volumeId);
  }

  /// 端末内のダウンロードを全部捨てる（ログアウト。#15）。
  Future<void> purgeAll() async {
    await future;
    _generation++;
    // タグが決まるまでは、届いたイベントをすべて前のセッションのものとして扱う。
    _sessionTag = null;
    _resetMemory();

    final store = _store;
    final transport = _transport;
    if (store != null) {
      try {
        // タグを作り直す。前のユーザーの転送の完了が後から届いても、
        // タグが違うので取り込まない（ファイルも残さない）。
        _sessionTag = await store.rotateSessionTag();
      } on Object catch (error) {
        debugPrint('[downloads] rotate session tag failed: $error');
      }
    }
    if (transport != null) {
      try {
        // ファイルより先に消す。タスクの記録には Bearer が平文で入っている。
        await transport.reset();
      } on Object catch (error) {
        debugPrint('[downloads] transport reset failed: $error');
      }
    }
    if (store != null) {
      await store.deleteAllRows();
      await store.deleteAllFiles();
    }
    if (!ref.mounted) return;
    state = const AsyncData({});
  }

  // ---------------------------------------------------------------- 投入

  /// 投入を積む（積んだ順に 1 本ずつ流す）。
  void _scheduleSubmit(int volumeId) {
    if (!_submitting.add(volumeId)) {
      // 投入の処理中（マニフェスト取得 / 投入の await 中）に中断 → 再開された
      // などで、もう一度頼まれた。今の処理はその中断を見て畳むかもしれないので、
      // 終わってから改めて確かめる（積めていれば何もしない）。
      _submitAgain.add(volumeId);
      return;
    }
    final generation = _generation;
    final ready = _ready;
    final link = _submitChain.then((_) async {
      try {
        // 起動時の照合が終わるまで待つ。照合の前は OS 側に同じ巻の転送が
        // 残っているか分からず、二重に積んだり書きかけを消したりしかねない。
        await ready.future;
        await _submit(volumeId, generation);
      } finally {
        if (generation == _generation) {
          _submitting.remove(volumeId);
          // 今の処理で積めていれば（_tasks にある）取り直さない。
          final download = ref.mounted ? (state.value?[volumeId]) : null;
          if (_submitAgain.remove(volumeId) &&
              download != null &&
              download.isActive &&
              !_tasks.containsKey(volumeId)) {
            _scheduleSubmit(volumeId);
          }
        }
      }
    });
    _submitChain = link.catchError((Object _) {});
    _track(link);
  }

  /// 待機のまま OS に渡っていない巻を投入し直す（回線の復帰 / 前面復帰）。
  void _submitPending() {
    if (!ref.mounted || !_ready.isCompleted) return;
    for (final download in state.value?.values ?? const <VolumeDownload>[]) {
      if (!download.isActive) continue;
      final volumeId = download.volumeId;
      if (_awaitingInstall.contains(volumeId)) {
        final task = _tasks[volumeId];
        if (task != null) _scheduleInstall(task);
        continue;
      }
      if (_tasks.containsKey(volumeId)) continue;
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
      if (_isOffline(error) && !_installed.containsKey(volumeId)) return;
      await _fail(volumeId, _messageOf(error), generation: generation);
      return;
    }
    if (_isStale(generation)) return;
    download = state.value?[volumeId];
    // マニフェストを待っている間に中断 / 削除された。
    if (download == null || !download.isActive) return;

    // 同じ巻の転送が既にある。
    final existing = _tasks[volumeId];
    if (existing != null) {
      final sameGeneration =
          existing.filesVersion == manifest.filesVersion &&
          existing.sessionTag == tag;
      if (sameGeneration &&
          (_liveTasks.contains(volumeId) ||
              _installing.contains(volumeId) ||
              _awaitingInstall.contains(volumeId))) {
        return;
      }
      if (sameGeneration) {
        // 中断した取り直しを「更新あり」から再開した場合など。続きから取る。
        if (await _tryResume(existing)) return;
        if (_isStale(generation)) return;
        _clearTask(volumeId);
        await _forgetQuietly(existing);
      } else {
        // 更新で世代が変わった。旧世代の転送は要らない。
        await _cancelTask(existing);
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
      await _finish(volumeId, manifest, generation: generation);
      return;
    }

    final reservedByOthers = _reservedBytes.entries
        .where((entry) => entry.key != volumeId)
        .fold<int>(0, (sum, entry) => sum + entry.value);
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
    await _deleteQuietly(
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
      await _fail(volumeId, _fileSystemMessage(error), generation: generation);
      return;
    }

    final uri = api.archiveUri(volumeId);
    final headers = await _authHeaders(uri);
    if (_isStale(generation)) return;
    download = state.value?[volumeId];
    if (download == null || !download.isActive) return;

    final task = ArchiveTaskId(
      volumeId: volumeId,
      filesVersion: manifest.filesVersion,
      sessionTag: tag,
    );
    // 投入の前に登録する（直後に届くイベントを「今の転送」と判断できるように）。
    _tasks[volumeId] = task;
    _liveTasks.add(volumeId);
    _reservedBytes[volumeId] = manifest.archiveBytes;
    _persistedBytes[volumeId] = 0;
    // 世代にかかわる項目（filesVersion / pageCount / archive_etag）は**検証が
    // 通ってから**台帳に書く（[_complete]）。取り直しの途中で落ちても、台帳は
    // 端末にある旧世代を指したままにしておく（#11 のページ解決が実体の無い
    // 世代を指さないように）。進捗表示に要る全体バイト数だけ先に入れる。
    await _save(
      download.copyWith(receivedBytes: 0, totalBytes: manifest.archiveBytes),
    );

    var accepted = false;
    try {
      accepted = await transport.enqueue(
        ArchiveTransferRequest(
          taskId: task.toString(),
          uri: uri,
          headers: headers,
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
        _tasks[volumeId] != task ||
        !(state.value?[volumeId]?.isActive ?? false)) {
      if (!accepted) return;
      if (_tasks[volumeId] == task) {
        // まだ自分の転送だが台帳は中断済み。OS 側で一時停止できていれば
        // （[pause] が _liveTasks から外した）再開データを残す。
        if (_liveTasks.contains(volumeId)) await _cancelTask(task);
        return;
      }
      // F1: 中断 / 削除 / ログアウトの取り消しは、OS がまだこのタスクを
      // 知らない間に届いて空振りしたかもしれない（Android は投入と取り消しを
      // 別々のコルーチンで処理し、知らない ID の取り消しを覚えておかない）。
      // 受け付けられたと分かった今、もう一度取り消す（何度送っても害は無い）。
      // 放っておくと誰も追っていない転送が数百 MB を落とし、同時実行の枠を
      // 塞いで後ろの巻を待たせる。
      _cancelling.add(task.toString());
      try {
        await transport.cancel(task.toString());
      } on Object catch (error) {
        debugPrint('[downloads] cancel after enqueue failed: $error');
      }
      if (!_isStale(generation)) {
        await _deleteStagingUnlessCurrent(task);
        await _forgetQuietly(task);
      }
      return;
    }
    if (!accepted) {
      _clearTask(volumeId);
      await _fail(volumeId, '転送を開始できませんでした。', generation: generation);
    }
  }

  /// Bearer は API と同じ配信元にだけ付ける（将来 CDN / 署名付き URL に
  /// なったときに、他のホストへトークンを送らない）。
  Future<Map<String, String>> _authHeaders(Uri uri) async {
    if (!ref.read(appConfigProvider).isApiOrigin(uri)) return const {};
    try {
      final token = await ref.read(authStoreProvider).readToken();
      if (token == null || token.isEmpty) return const {};
      return {'Authorization': 'Bearer $token'};
    } on Object catch (error) {
      // 読めなければ付けずに送る（401 は確認の経路で扱う）。
      debugPrint('[downloads] token read failed: $error');
      return const {};
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

  // ---------------------------------------------------------------- イベント

  void _onEvent(TransferEvent event) {
    final ready = _ready;
    final generation = _generation;
    if (!ready.isCompleted &&
        event is TransferStateChanged &&
        event.state == TransferState.completed) {
      // 照合の前に届いた完了。照合の一覧に載っていなくても書き上がった ZIP が
      // あるので、照合に教えて孤児として掃除させない（F6）。
      _earlyCompleted.add(event.taskId);
    }
    final link = _eventChain.then((_) async {
      await ready.future;
      if (_isStale(generation)) return;
      await _handleEvent(event, generation);
    });
    _eventChain = link.catchError((Object _) {});
    _track(link);
  }

  Future<void> _handleEvent(TransferEvent event, int generation) async {
    final task = ArchiveTaskId.tryParse(event.taskId);
    final tag = _sessionTag;
    if (task == null || tag == null || task.sessionTag != tag) {
      // 前のセッション（ログアウト前）の転送、または壊れた ID。取り込まない。
      await _discardForeign(event, task);
      return;
    }
    final isCurrent = _tasks[task.volumeId] == task;
    switch (event) {
      case TransferProgressed(:final received, :final total):
        if (isCurrent) _onProgress(task.volumeId, received, total);
      case TransferStateChanged(:final state, :final failure):
        await _onStateChanged(
          task,
          state,
          failure,
          isCurrent: isCurrent,
          generation: generation,
        );
    }
  }

  Future<void> _onStateChanged(
    ArchiveTaskId task,
    TransferState transferState,
    TransferFailure? failure, {
    required bool isCurrent,
    required int generation,
  }) async {
    final volumeId = task.volumeId;
    final download = state.value?[volumeId];
    switch (transferState) {
      case TransferState.enqueued || TransferState.waitingToRetry:
        if (!isCurrent) return;
        _liveTasks.add(volumeId);
        _runningTasks.remove(volumeId);
        // 「待機中」。Wi-Fi 待ちかどうかの表示は DownloadGate が出す。
        if (download != null &&
            download.isActive &&
            download.status != VolumeDownloadStatus.queued) {
          await _save(download.copyWith(status: VolumeDownloadStatus.queued));
        }
      case TransferState.running:
        if (!isCurrent) return;
        _liveTasks.add(volumeId);
        _runningTasks.add(volumeId);
        if (download != null &&
            download.isActive &&
            download.status != VolumeDownloadStatus.downloading) {
          await _save(
            download.copyWith(status: VolumeDownloadStatus.downloading),
          );
        }
      case TransferState.paused:
        // F1: 台帳が「中断」ならユーザーが止めたもの（既に書いてある）。
        // 台帳が待機中 / 取得中のままなら、9 分の時間切れや Wi-Fi 設定の
        // 反映による一時的な停止で、ネイティブがすぐ再投入する。どちらも
        // 台帳は変えない（「中断中」にすると、勝手に止まったように見える）。
        if (!isCurrent) return;
        // 時間切れの再投入が走り出すまでは一時停止できない（F11）。
        _runningTasks.remove(volumeId);
        if (_pausing.contains(volumeId)) _pausedSeen.add(volumeId);
        if (_resumeOnPaused.remove(volumeId)) {
          // F3: 止め終わる前に「再開」が押されていた。再開データが揃ったので
          // 続きを取る。
          if (download != null && download.isActive) {
            _track(_resumeOrSubmit(task, generation: generation));
          }
          return;
        }
        if (!(download?.isActive ?? false)) _liveTasks.remove(volumeId);
      case TransferState.canceled:
        final expected = _cancelling.remove(task.toString());
        if (isCurrent && !expected && download != null && download.isActive) {
          // 通知の Cancel ボタン（Dart を経由しない取り消し）。ユーザーが
          // 止めたので中断として扱う。取り直しなら旧世代へ戻し、完了済みの
          // ZIP と台帳は消さない（削除は画面の操作だけにする）。
          _clearTask(volumeId);
          await _savePaused(download);
          await _deleteStaging(task);
          await _forgetQuietly(task);
          return;
        }
        // 自分で取り消したもの。同じ ID で積み直していれば（isCurrent）触らない。
        if (isCurrent && !expected) _clearTask(volumeId);
        if (isCurrent && expected) return;
        await _deleteStagingUnlessCurrent(task);
        await _forgetQuietly(task);
      case TransferState.failed || TransferState.notFound:
        if (!isCurrent) {
          await _deleteStagingUnlessCurrent(task);
          await _forgetQuietly(task);
          return;
        }
        _liveTasks.remove(volumeId);
        _runningTasks.remove(volumeId);
        if (download == null || !download.isActive) {
          _clearTask(volumeId);
          await _forgetQuietly(task);
          return;
        }
        // 再試行の待ち時間でイベントの処理（次の巻の進捗など）を止めない。
        _track(
          _applyFailure(
            task,
            failure ?? const TransferFailure(kind: TransferFailureKind.other),
            generation: generation,
          ),
        );
      case TransferState.completed:
        if (isCurrent) {
          _liveTasks.remove(volumeId);
          _runningTasks.remove(volumeId);
        }
        _scheduleInstall(task);
    }
  }

  /// 他のセッションの転送（または壊れた ID）を片付ける。
  Future<void> _discardForeign(TransferEvent event, ArchiveTaskId? task) async {
    final terminal =
        event is TransferStateChanged &&
        (event.state == TransferState.completed ||
            event.state == TransferState.failed ||
            event.state == TransferState.canceled ||
            event.state == TransferState.notFound);
    if (!terminal) {
      // まだ動いている。止める（止まったら canceled で戻ってくる）。
      if (_cancelling.add(event.taskId)) {
        try {
          await _transport?.cancel(event.taskId);
        } on Object catch (error) {
          debugPrint('[downloads] cancel foreign failed: $error');
        }
      }
      return;
    }
    _cancelling.remove(event.taskId);
    if (task != null) await _deleteStagingUnlessCurrent(task);
    // 記録には前のユーザーの Bearer が入っている。パッケージはこの更新の
    // 書き込みを非同期に積んでから通知してくるので、消した後に書き戻される
    // ことがある。書き戻されても消し直す方で捨てる（#15）。
    await _forgetForeignQuietly(event.taskId);
  }

  void _onProgress(int volumeId, int received, int? total) {
    final current = state.value?[volumeId];
    if (current == null || !current.isActive) return;
    final totalBytes = total != null && total > 0 ? total : current.totalBytes;
    final next = current.copyWith(
      status: VolumeDownloadStatus.downloading,
      receivedBytes: received,
      totalBytes: totalBytes,
    );
    _emit(next);
    // 進捗が届く = 走っている（`running` を取りこぼしても一時停止できる）。
    _liveTasks.add(volumeId);
    _runningTasks.add(volumeId);
    if (totalBytes > 0) {
      _reservedBytes[volumeId] = math.max(0, totalBytes - received);
    }

    final persisted = _persistedBytes[volumeId] ?? 0;
    if ((received - persisted).abs() < progressPersistIntervalBytes) return;
    _persistedBytes[volumeId] = received;
    final store = _store;
    if (store != null) _track(store.save(next));
  }

  // ---------------------------------------------------------------- 失敗

  /// 転送の失敗を解釈する（再試行するか・何と出すか）。
  Future<void> _applyFailure(
    ArchiveTaskId task,
    TransferFailure failure, {
    required int generation,
  }) async {
    final volumeId = task.volumeId;
    switch (failure.kind) {
      case TransferFailureKind.forbidden ||
          TransferFailureKind.notFound ||
          TransferFailureKind.fileSystem:
        // 待っても直らない（権限 / 削除済み / 容量不足）。
        _clearTask(volumeId);
        await _forgetQuietly(task);
        await _fail(volumeId, _failureMessage(failure), generation: generation);

      case TransferFailureKind.unauthorized:
        // F2: ネイティブの 401 は「タスクに焼き込んだ古いトークン」に対する
        // もので、今のトークンが失効したとは限らない。すぐにログアウト
        // （数 GB の破棄）させず、マニフェストを Dio で取り直して確かめる。
        // 本当に失効していれば AuthInterceptor → handleSessionExpired の
        // 1 経路に合流し、生きていれば新しいトークンで積み直せる。
        if (!await _countAttempt(task, failure, generation: generation)) {
          return;
        }
        _clearTask(volumeId);
        await _forgetQuietly(task);
        if (_isStale(generation)) return;
        _scheduleSubmit(volumeId);

      case TransferFailureKind.resumeMismatch:
        // 再開しようとしたら ZIP が差し替わっていた。続きを足すと別世代が
        // 混ざるので、マニフェストから取り直して先頭から落とす。
        if (!await _countAttempt(task, failure, generation: generation)) {
          return;
        }
        _clearTask(volumeId);
        await _deleteStaging(task);
        await _forgetQuietly(task);
        if (_isStale(generation)) return;
        _scheduleSubmit(volumeId);

      case TransferFailureKind.connection || TransferFailureKind.other
          when _isWaitingForWifi:
        // F3: Wi-Fi 限定で Wi-Fi が切れた失敗は回数に数えない（数えると
        // Wi-Fi が 3 回途切れるだけで「失敗」になる）。積み直せば、ネイティブが
        // Wi-Fi に戻るまで待ってから取り始める。
        // `other` も含めるのは、Android では Wi-Fi の制約が外れると WorkManager
        // がワーカーを止め、その失敗が connection ではなく理由無し / 一般の
        // 例外（CancellationException）として届くため（モバイル回線が生きて
        // いるので、パッケージの「オフラインなら再試行待ち」も効かない）。
        await _resubmit(task, generation: generation);

      case TransferFailureKind.connection ||
          TransferFailureKind.server ||
          TransferFailureKind.tooManyRequests ||
          TransferFailureKind.other:
        if (!await _countAttempt(task, failure, generation: generation)) {
          return;
        }
        // 2 秒 → 4 秒。自宅サーバーを叩き続けない。429 の Retry-After は
        // 見ない（パッケージの失敗の更新に応答ヘッダーが載る保証が無い）ので、
        // 5xx と同じ間隔で待ち、上限で失敗にする。
        final attempt = _attempts[volumeId] ?? 1;
        await ref.read(downloadRetryDelayProvider)(
          Duration(seconds: 1 << attempt),
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
    final attempt = (_attempts[volumeId] ?? 0) + 1;
    _attempts[volumeId] = attempt;
    if (attempt < maxDownloadAttempts) return true;
    _attempts.remove(volumeId);
    if (_tasks[volumeId] == task) _clearTask(volumeId);
    await _forgetQuietly(task);
    await _fail(volumeId, _failureMessage(failure), generation: generation);
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
    _clearTask(task.volumeId);
    await _forgetQuietly(task);
    if (_isStale(generation)) return;
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
    _clearTask(task.volumeId);
    await _forgetQuietly(task);
    if (_isStale(generation)) return;
    _scheduleSubmit(task.volumeId);
  }

  Future<bool> _tryResume(ArchiveTaskId task) async {
    var resumed = false;
    try {
      resumed = await _transport!.resume(task.toString());
    } on Object catch (error) {
      debugPrint('[downloads] resume failed: $error');
    }
    if (resumed && _tasks[task.volumeId] == task) {
      _liveTasks.add(task.volumeId);
    }
    return resumed;
  }

  // ---------------------------------------------------------------- 確定

  void _scheduleInstall(ArchiveTaskId task) {
    final volumeId = task.volumeId;
    final isCurrent = _tasks[volumeId] == task;
    if (isCurrent) {
      if (_installing.contains(volumeId)) return;
      _awaitingInstall.remove(volumeId);
      _installing.add(volumeId);
    }
    final generation = _generation;
    final link = _installChain.then((_) async {
      try {
        await _install(task, generation);
      } finally {
        if (generation == _generation && _tasks[volumeId] == task) {
          _installing.remove(volumeId);
        }
      }
    });
    _installChain = link.catchError((Object _) {});
    _track(link);
  }

  /// 転送が終わった巻を検証して確定する。
  ///
  /// 冪等にする（F9）。完了は `start` のたびに再送されうるし、rename の後・
  /// forget の前に落ちると、次の起動でも同じ完了が届く。
  Future<void> _install(ArchiveTaskId task, int generation) async {
    final store = _store;
    if (store == null || _isStale(generation)) return;
    final volumeId = task.volumeId;
    final staging = store.stagingFile(
      volumeId: volumeId,
      filesVersion: task.filesVersion,
    );
    final archive = store.archiveFile(
      volumeId: volumeId,
      filesVersion: task.filesVersion,
    );

    final download = state.value?[volumeId];
    // 既に確定済み（完了の再送）。
    if (download != null &&
        download.isCompleted &&
        download.filesVersion == task.filesVersion &&
        archive.existsSync()) {
      if (_tasks[volumeId] == task) _clearTask(volumeId);
      await _deleteStaging(task);
      await _forgetQuietly(task);
      return;
    }
    // 削除 / 中断 / 別世代の積み直しと競合した完了。取り込まない
    // （消した巻を「ダウンロード済み」として復活させない）。
    if (download == null || !download.isActive || _tasks[volumeId] != task) {
      if (_tasks[volumeId] == task) _clearTask(volumeId);
      await _deleteStagingUnlessCurrent(task);
      await _forgetQuietly(task);
      return;
    }

    var manifest = await store.readManifest(
      volumeId: volumeId,
      filesVersion: task.filesVersion,
    );
    if (manifest == null) {
      try {
        manifest = await ref.read(volumesApiProvider).fetchManifest(volumeId);
      } on Object catch (error) {
        if (_isStale(generation) || !_isCurrent(task)) return;
        // オフラインで確定できない。書き上がったデータは残し、回線が戻ったら
        // やり直す（数百 MB を落とし直させない）。
        debugPrint('[downloads] manifest for install failed: $error');
        _awaitingInstall.add(volumeId);
        final current = state.value?[volumeId];
        if (current != null && current.status != VolumeDownloadStatus.queued) {
          await _save(current.copyWith(status: VolumeDownloadStatus.queued));
        }
        return;
      }
      if (_isStale(generation) || !_isCurrent(task)) return;
      if (manifest.filesVersion != task.filesVersion) {
        // 転送の間にサーバー側の ZIP が差し替わった。検証できないので取り直す。
        _clearTask(volumeId);
        await _deleteStaging(task);
        await _forgetQuietly(task);
        if (!_isStale(generation)) _scheduleSubmit(volumeId);
        return;
      }
    }
    if (_isStale(generation) || !_isCurrent(task)) return;

    // rename の後・確定の前に落ちた（書きかけは既に本番のファイル名になって
    // いる）。検証済みのものしか rename しないので、そのまま確定し直す。
    if (!staging.existsSync() &&
        archive.existsSync() &&
        (manifest.archiveBytes == 0 ||
            archive.lengthSync() == manifest.archiveBytes)) {
      await _finish(volumeId, manifest, generation: generation);
      if (_tasks[volumeId] == task) _clearTask(volumeId);
      _attempts.remove(volumeId);
      await _forgetQuietly(task);
      return;
    }

    final failure = await _verify(manifest, staging);
    if (_isStale(generation) || !_isCurrent(task)) return;
    if (failure != null) {
      // 転送中に ZIP が差し替わった（files_version が変わった）なら、壊れた
      // のではないので自動で取り直す。同じなら本当に壊れているので止める
      // （自動で取り直し続けると自宅サーバーを叩き続ける）。
      VolumeManifest? latest;
      try {
        latest = await ref.read(volumesApiProvider).fetchManifest(volumeId);
      } on Object {
        latest = null;
      }
      if (_isStale(generation) || !_isCurrent(task)) return;
      _clearTask(volumeId);
      await _deleteQuietly(staging);
      await _forgetQuietly(task);
      if (latest != null && latest.filesVersion != task.filesVersion) {
        if (!_isStale(generation)) _scheduleSubmit(volumeId);
        return;
      }
      _persistedBytes[volumeId] = 0;
      await _fail(
        volumeId,
        failure,
        generation: generation,
        resetProgress: true,
      );
      return;
    }

    try {
      if (archive.existsSync()) await archive.delete();
      // 検証が通ってから初めて本番のファイル名にする。途中のデータが
      // 「ダウンロード済み」と認識されることは無い。
      await staging.rename(archive.path);
    } on FileSystemException catch (error) {
      // 削除と競合して書きかけが先に消えた（F2）。ユーザーの操作を
      // 「保存できませんでした」の失敗で上書きしない。
      final current = _isCurrent(task);
      if (_tasks[volumeId] == task) _clearTask(volumeId);
      await _deleteQuietly(staging);
      await _forgetQuietly(task);
      if (!current) return;
      await _fail(volumeId, _fileSystemMessage(error), generation: generation);
      return;
    }

    await _finish(volumeId, manifest, generation: generation);
    if (_tasks[volumeId] == task) _clearTask(volumeId);
    _attempts.remove(volumeId);
    await _forgetQuietly(task);
    _sweepTempFilesIfIdle();
  }

  /// ZIP が本番のファイル名で手元にある巻を確定する。
  Future<void> _finish(
    int volumeId,
    VolumeManifest manifest, {
    required int generation,
  }) async {
    final store = _store;
    if (store == null || _isStale(generation)) return;
    // マニフェストは早期完了の経路でも必ず書く。rename 済み・マニフェスト未保存
    // で落ちた巻をそのまま「ダウンロード済み」に確定させると、{v}.json が無い
    // まま固定されて #11 のページ解決が恒久的にできなくなる。
    try {
      await store.writeManifest(manifest);
    } on FileSystemException catch (error) {
      if (!(state.value?.containsKey(volumeId) ?? false)) {
        // 削除と競合した（ディレクトリが先に消えた）。失敗として書き戻さない。
        if (!_isStale(generation)) await store.deleteFiles(volumeId);
        return;
      }
      await _fail(volumeId, _fileSystemMessage(error), generation: generation);
      return;
    }
    await store.deleteOtherVersions(
      volumeId: volumeId,
      keepFilesVersion: manifest.filesVersion,
    );

    final download = state.value?[volumeId];
    if (download == null) {
      // 確定の途中で削除された。削除の後片付け（ディレクトリごと消す）が
      // rename / マニフェストの書き込みと競合して残ったものを消す
      // （台帳に無い実体を端末に残さない）。
      if (!_isStale(generation)) await store.deleteFiles(volumeId);
      return;
    }
    final archive = store.archiveFile(
      volumeId: volumeId,
      filesVersion: manifest.filesVersion,
    );
    final total = manifest.archiveBytes > 0
        ? manifest.archiveBytes
        : (archive.existsSync() ? archive.lengthSync() : 0);
    await _complete(
      download.copyWith(receivedBytes: total, totalBytes: total),
      manifest,
      generation: generation,
    );
  }

  /// 落としたものが本物か確かめる。通らなければ理由を返す。
  Future<String?> _verify(VolumeManifest manifest, File staging) async {
    final actual = staging.existsSync() ? staging.lengthSync() : 0;
    if (manifest.archiveBytes > 0 && actual != manifest.archiveBytes) {
      return 'ダウンロードしたデータのサイズが一致しません'
          '（${formatBytes(actual)} / ${formatBytes(manifest.archiveBytes)}）。';
    }

    final int pages;
    try {
      pages = await ref.read(archiveVerifierProvider)(staging);
    } on ArchiveVerificationException catch (error) {
      return error.message;
    } on Object catch (error) {
      return 'ダウンロードしたファイルを検証できませんでした（$error）。';
    }

    if (manifest.pageCount > 0 && pages != manifest.pageCount) {
      return 'ページ数が一致しません（$pages / ${manifest.pageCount} ページ）。';
    }
    return null;
  }

  // ---------------------------------------------------------------- 照合

  /// 起動時に、OS 側の転送と台帳を突き合わせる。
  ///
  /// | 台帳 | 自分のタグの転送 | 処理 |
  /// | --- | --- | --- |
  /// | 待機 / 取得中 | 待機 / 走行中 | そのまま見守る |
  /// | 待機 / 取得中 | 完了 | 確定する |
  /// | 待機 / 取得中 | 一時停止 | 再開。だめなら積み直す |
  /// | 待機 / 取得中 | 失敗 | 失敗として解釈する（回数は数え直す） |
  /// | 待機 / 取得中 | 取り消し | 通知の Cancel。中断にする |
  /// | 待機 / 取得中 | 無し / 消えた | 積み直す（新しいトークンで） |
  /// | 中断 / 失敗 | 一時停止 | 再開データとして残す |
  /// | 中断 / 失敗 / 完了 | それ以外 | 止めて捨てる |
  /// | 無し | 何か | 止めて捨てる |
  /// | 何でも | 別のタグ | 止めて捨てる |
  ///
  /// プラグインの自動再投入は使わない（古いトークンのまま、この照合と並んで
  /// 積み直すので二重になる。F5）。
  Future<void> _reconcile(
    List<TransferSnapshot> snapshots,
    int generation,
  ) async {
    final store = _store;
    if (store == null) return;
    final tag = _sessionTag;

    // 照合の前に届いた完了を一覧に反映する（F6）。記録が消えていても、
    // 完了が届いたなら書き上がった ZIP がある（下の sweep で孤児として消さない）。
    final early = {..._earlyCompleted};
    _earlyCompleted.clear();
    final merged = [
      for (final snapshot in snapshots)
        if (early.remove(snapshot.taskId))
          TransferSnapshot(
            taskId: snapshot.taskId,
            state: TransferState.completed,
          )
        else
          snapshot,
      for (final taskId in early)
        TransferSnapshot(taskId: taskId, state: TransferState.completed),
    ];

    final foreign = <(TransferSnapshot, ArchiveTaskId?)>[];
    final byVolume = <int, List<(ArchiveTaskId, TransferSnapshot)>>{};
    for (final snapshot in merged) {
      final task = ArchiveTaskId.tryParse(snapshot.taskId);
      if (task == null || tag == null || task.sessionTag != tag) {
        foreign.add((snapshot, task));
        continue;
      }
      (byVolume[task.volumeId] ??= []).add((task, snapshot));
    }

    final installs = <ArchiveTaskId>[];
    final resumes = <ArchiveTaskId>[];
    final failures = <ArchiveTaskId>[];
    final discards = <(TransferSnapshot, ArchiveTaskId?)>[];
    for (final MapEntry(key: volumeId, value: tasks) in byVolume.entries) {
      // 同じ巻に世代違いが残っていたら、新しい世代だけを見る。
      tasks.sort((a, b) => b.$1.filesVersion.compareTo(a.$1.filesVersion));
      for (final (task, snapshot) in tasks.skip(1)) {
        discards.add((snapshot, task));
      }
      final (task, snapshot) = tasks.first;
      final download = state.value?[volumeId];

      if (download == null || download.isCompleted) {
        discards.add((snapshot, task));
        continue;
      }
      if (!download.isActive) {
        // ユーザーが止めた転送の再開データは残す（「再開」で続きから取る）。
        if (snapshot.state == TransferState.paused) {
          _tasks[volumeId] = task;
        } else {
          discards.add((snapshot, task));
        }
        continue;
      }
      switch (snapshot.state) {
        case TransferState.enqueued ||
            TransferState.running ||
            TransferState.waitingToRetry:
          _tasks[volumeId] = task;
          _liveTasks.add(volumeId);
          _reservedBytes[volumeId] = math.max(
            0,
            download.totalBytes - download.receivedBytes,
          );
          if (snapshot.state == TransferState.running) {
            _runningTasks.add(volumeId);
            await _save(
              download.copyWith(status: VolumeDownloadStatus.downloading),
            );
          }
        case TransferState.completed:
          _tasks[volumeId] = task;
          installs.add(task);
        case TransferState.paused:
          _tasks[volumeId] = task;
          resumes.add(task);
        case TransferState.failed:
          _tasks[volumeId] = task;
          _attempts.remove(volumeId);
          failures.add(task);
        case TransferState.canceled:
          // アプリが死んでいる間に通知の Cancel ボタンで止められた。
          discards.add((snapshot, task));
          await _savePaused(download);
        case TransferState.notFound:
          // プロセスごと殺されて消えた（holding queue の中身はメモリにしか
          // 無い）。下で新しいトークンで積み直す。
          discards.add((snapshot, task));
      }
      if (_isStale(generation)) return;
    }

    // 自分の転送を登録してから捨てる（同じ巻・同じ世代の書き込み先を、
    // 別セッションの転送の後始末で消さないため）。
    for (final (snapshot, task) in discards) {
      await _discardSnapshot(snapshot, task);
    }
    for (final (snapshot, task) in foreign) {
      await _discardSnapshot(snapshot, task, foreign: true);
    }
    if (_isStale(generation)) return;

    await store.sweep(
      ledger: state.value ?? const {},
      liveStagingPaths: {
        for (final MapEntry(key: volumeId, value: task) in _tasks.entries)
          store
              .stagingFile(volumeId: volumeId, filesVersion: task.filesVersion)
              .path,
      },
    );
    if (_isStale(generation)) return;
    // 失敗で置き去りになったパッケージの一時ファイル（F9）。積み直しを
    // 始める前に、何も走っていなければ消す。
    if (_liveTasks.isEmpty) await _sweepTempFiles();
    if (_isStale(generation)) return;

    for (final task in installs) {
      _scheduleInstall(task);
    }
    for (final task in resumes) {
      _track(_resumeOrSubmit(task, generation: generation));
    }
    for (final task in failures) {
      _track(
        _applyFailure(
          task,
          const TransferFailure(kind: TransferFailureKind.other),
          generation: generation,
        ),
      );
    }
    for (final download in state.value?.values ?? const <VolumeDownload>[]) {
      if (download.isActive && !_tasks.containsKey(download.volumeId)) {
        _scheduleSubmit(download.volumeId);
      }
    }
  }

  Future<void> _discardSnapshot(
    TransferSnapshot snapshot,
    ArchiveTaskId? task, {
    bool foreign = false,
  }) async {
    final alive =
        snapshot.state == TransferState.enqueued ||
        snapshot.state == TransferState.running ||
        snapshot.state == TransferState.waitingToRetry ||
        snapshot.state == TransferState.paused;
    if (alive) {
      _cancelling.add(snapshot.taskId);
      try {
        await _transport?.cancel(snapshot.taskId);
      } on Object catch (error) {
        debugPrint('[downloads] cancel failed: $error');
      }
    }
    if (task != null) await _deleteStagingUnlessCurrent(task);
    if (foreign) {
      // ログアウトの直後に落ちて、取り消しの書き戻しが残った記録など（#15）。
      await _forgetForeignQuietly(snapshot.taskId);
    } else {
      await _forgetQuietly(snapshot.taskId);
    }
  }

  // ---------------------------------------------------------------- 後始末

  /// 転送を取り消し、書きかけと記録も捨てる。
  Future<void> _cancelTask(ArchiveTaskId task) async {
    if (_tasks[task.volumeId] == task) _clearTask(task.volumeId);
    _cancelling.add(task.toString());
    try {
      await _transport?.cancel(task.toString());
    } on Object catch (error) {
      debugPrint('[downloads] cancel failed: $error');
    }
    await _deleteStagingUnlessCurrent(task);
    await _forgetQuietly(task);
  }

  void _clearTask(int volumeId) {
    _tasks.remove(volumeId);
    _liveTasks.remove(volumeId);
    _runningTasks.remove(volumeId);
    _awaitingInstall.remove(volumeId);
    _installing.remove(volumeId);
    _reservedBytes.remove(volumeId);
    _resumeRequested.remove(volumeId);
    _pausedSeen.remove(volumeId);
    _resumeOnPaused.remove(volumeId);
  }

  Future<void> _forgetQuietly(Object task) async {
    try {
      await _transport?.forget(task.toString());
    } on Object catch (error) {
      debugPrint('[downloads] forget failed: $error');
    }
  }

  /// 前のセッションの転送の記録を、書き戻されても消し直す方で捨てる（#15）。
  Future<void> _forgetForeignQuietly(String taskId) async {
    try {
      await _transport?.forgetForeign(taskId);
    } on Object catch (error) {
      debugPrint('[downloads] forget foreign failed: $error');
    }
  }

  /// 何も走らせていない・積もうとしていないときに、置き去りの一時ファイルを
  /// 消す（F9）。走っている転送の書きかけを消さないよう、最後の判断は
  /// 転送側（ネイティブの一覧）でもう一度する。
  void _sweepTempFilesIfIdle() {
    if (!ref.mounted || _liveTasks.isNotEmpty || _submitting.isNotEmpty) {
      return;
    }
    _track(_sweepTempFiles());
  }

  Future<void> _sweepTempFiles() async {
    try {
      await _transport?.sweepOrphanTempFiles();
    } on Object catch (error) {
      debugPrint('[downloads] temp sweep failed: $error');
    }
  }

  Future<void> _deleteStaging(ArchiveTaskId task) async {
    final store = _store;
    if (store == null) return;
    await _deleteQuietly(
      store.stagingFile(
        volumeId: task.volumeId,
        filesVersion: task.filesVersion,
      ),
    );
  }

  /// 同じ巻・同じ世代の「今の転送」が同じファイルに書いているなら消さない。
  Future<void> _deleteStagingUnlessCurrent(ArchiveTaskId task) async {
    final current = _tasks[task.volumeId];
    if (current != null && current.filesVersion == task.filesVersion) return;
    await _deleteStaging(task);
  }

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
    final installed = _installed.remove(volumeId);
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
    _sweepTempFilesIfIdle();
  }

  Future<void> _complete(
    VolumeDownload download,
    VolumeManifest manifest, {
    required int generation,
  }) async {
    if (_isStale(generation)) return;
    // 取り消し（[remove]）と競合した確定を書き戻さない。実体を消した後に
    // completed の行だけ復活すると、読めない「ダウンロード済み」が UI に出る。
    if (!(state.value?.containsKey(download.volumeId) ?? false)) return;
    _persistedBytes.remove(download.volumeId);
    _installed.remove(download.volumeId);
    await _save(
      download.copyWith(
        status: VolumeDownloadStatus.completed,
        filesVersion: manifest.filesVersion,
        pageCount: manifest.pageCount,
        archiveEtag: manifest.archiveEtag,
        clearFailureReason: true,
      ),
    );
    _warmOfflineDetail(download.bookId);
  }

  /// 圏外でも詳細が開けるように、このタイトルの詳細を控える（#11）。
  ///
  /// 詳細画面（autoDispose）に任せると「ダウンロードを始めてすぐ一覧へ戻る」
  /// だけで控えが作られず、圏外で一覧には出るのに詳細が開けないタイトルになる。
  /// キューの完了は画面に依存しないので、ここから控える。表示を待たせないし、
  /// 失敗しても取得自体は成功として扱う（次にオンラインで詳細を開けば控えられる）。
  void _warmOfflineDetail(int bookId) {
    if (!ref.mounted) return;
    final warm = ref.read(offlineDetailWarmerProvider);
    unawaited(warm(bookId).catchError((Object _) {}));
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
      _installed.remove(download.volumeId);
      return;
    }
    _installed[download.volumeId] = download;
  }

  /// 中断として台帳を書く。
  ///
  /// 取り直しの中断なら「中断中」にはせず手元の旧世代へ戻す。新世代を指す
  /// 中断行にしてしまうと、実体のある旧世代を指す行が台帳から消えてしまい、
  /// オフラインで読めるはずの巻が読めなくなる（転送の再開データは残るので、
  /// もう一度「更新あり」を押せば続きから取り直せる）。
  Future<void> _savePaused(VolumeDownload current) async {
    final installed = _installed.remove(current.volumeId);
    if (installed != null) {
      await _save(installed);
      return;
    }
    await _save(current.copyWith(status: VolumeDownloadStatus.paused));
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
      _tasks[task.volumeId] == task &&
      (state.value?[task.volumeId]?.isActive ?? false);

  void _resetMemory() {
    _installed.clear();
    _persistedBytes.clear();
    _tasks.clear();
    _liveTasks.clear();
    _runningTasks.clear();
    _pausing.clear();
    _resumeRequested.clear();
    _pausedSeen.clear();
    _resumeOnPaused.clear();
    _earlyCompleted.clear();
    _submitAgain.clear();
    _awaitingInstall.clear();
    _installing.clear();
    _submitting.clear();
    _cancelling.clear();
    _attempts.clear();
    _reservedBytes.clear();
    _submitChain = Future.value();
    _eventChain = Future.value();
    _installChain = Future.value();
  }

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

  Future<bool> _hasNotEnoughSpace(int requiredBytes) async {
    if (requiredBytes <= 0) return false;
    final free = await ref.read(freeSpaceProbeProvider)();
    // 取得できない端末では止めない（誤検知でダウンロードを塞がない）。
    if (free == null) return false;
    return free < requiredBytes + freeSpaceMarginBytes;
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // 消せなくても次の起動の掃除（sweep）が拾う。
    }
  }

  /// 回線が無い / 届かない失敗か（待てば直る見込みがある）。
  static bool _isOffline(Object error) =>
      error is NetworkException || error is ApiTimeoutException;

  static String _messageOf(Object error) => switch (error) {
    final ApiException error => error.message,
    final FileSystemException error => _fileSystemMessage(error),
    _ => 'ダウンロードに失敗しました。',
  };

  static String _failureMessage(TransferFailure failure) =>
      switch (failure.kind) {
        TransferFailureKind.unauthorized =>
          const UnauthorizedException().message,
        TransferFailureKind.forbidden => const ForbiddenException().message,
        TransferFailureKind.notFound => const NotFoundException().message,
        TransferFailureKind.server => const ServerException(
          statusCode: 500,
        ).message,
        TransferFailureKind.tooManyRequests =>
          const TooManyRequestsException().message,
        TransferFailureKind.connection => const NetworkException().message,
        TransferFailureKind.resumeMismatch =>
          'ダウンロード中にサーバー側のデータが更新されました。もう一度お試しください。',
        TransferFailureKind.fileSystem =>
          _isOutOfSpace(failure.message)
              ? _outOfSpaceMessage
              : '端末にデータを保存できませんでした。',
        TransferFailureKind.other => 'ダウンロードに失敗しました。',
      };

  static const _outOfSpaceMessage = '端末の空き容量が足りません。不要なデータを削除してからやり直してください。';

  /// ネイティブの失敗は errno を持たないので、文言で容量不足を見分ける。
  static bool _isOutOfSpace(String message) {
    final lower = message.toLowerCase();
    return lower.contains('enospc') ||
        lower.contains('no space') ||
        lower.contains('not enough space') ||
        lower.contains('insufficient');
  }

  /// 端末側の書き込み失敗。容量不足（ENOSPC）だけは原因を明示する。
  static String _fileSystemMessage(FileSystemException error) {
    // errno 28 = ENOSPC（Android / iOS / Linux / macOS 共通）。
    // Windows は ERROR_DISK_FULL(112) / ERROR_HANDLE_DISK_FULL(39)。
    const outOfSpace = {28, 39, 112};
    if (outOfSpace.contains(error.osError?.errorCode)) {
      return _outOfSpaceMessage;
    }
    return '端末にデータを保存できませんでした。';
  }
}
