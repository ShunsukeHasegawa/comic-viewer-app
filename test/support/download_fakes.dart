import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:comic_laz/core/config/app_config.dart';
import 'package:comic_laz/core/device/app_resume_monitor.dart';
import 'package:comic_laz/core/device/connectivity_monitor.dart';
import 'package:comic_laz/core/device/network_kind_monitor.dart';
import 'package:comic_laz/data/api/volumes_api.dart';
import 'package:comic_laz/domain/models/archive_url.dart';
import 'package:comic_laz/domain/models/volume_manifest.dart';
import 'package:comic_laz/features/auth/data/auth_store.dart';
import 'package:comic_laz/features/downloads/application/download_queue.dart';
import 'package:comic_laz/features/downloads/application/download_settings.dart';
import 'package:comic_laz/features/downloads/data/archive_transport.dart';
import 'package:comic_laz/features/downloads/data/archive_verifier.dart';
import 'package:comic_laz/features/downloads/data/background_archive_transport.dart';
import 'package:comic_laz/features/downloads/data/download_store.dart';
import 'package:comic_laz/features/downloads/data/free_space_probe.dart';
import 'package:comic_laz/features/downloads/domain/archive_task_id.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/offline/application/offline_detail_warmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'auth_fakes.dart';
import 'cache_fakes.dart';
import 'progress_fakes.dart';

/// ネットワークを触らない [VolumesApi]（マニフェストと署名付き URL）。
///
/// ZIP 本体は OS の転送（[FakeArchiveTransport]）が運ぶ。
class FakeVolumesApi implements VolumesApi {
  FakeVolumesApi({required this.manifest, required this.archiveBytes});

  /// 既定のマニフェスト。
  VolumeManifest manifest;

  /// 巻ごとのマニフェスト（無ければ [manifest]）。
  final manifests = <int, VolumeManifest>{};

  /// 完成形の ZIP（[FakeArchiveTransport.completeWith] に渡す既定値）。
  Uint8List archiveBytes;

  /// マニフェスト取得で投げる例外。
  Object? manifestError;

  /// マニフェストを返す前に実行する処理（取得の準備中に中断を差し込む /
  /// 401 を受けた AuthInterceptor の振る舞いを模す）。
  Future<void> Function()? onManifest;

  /// 署名付き URL の発行で投げる例外。
  Object? archiveUrlError;

  /// 発行する URL の `files_version`。`null` ならその巻のマニフェストと同じ
  /// （マニフェストを取ってから発行するまでに ZIP が差し替わった場合を模す）。
  int? archiveUrlFilesVersion;

  int manifestCalls = 0;
  int archiveUrlCalls = 0;

  @override
  Future<VolumeManifest> fetchManifest(int volumeId) async {
    manifestCalls++;
    await onManifest?.call();
    if (manifestError case final error?) throw error;
    return manifests[volumeId] ?? manifest;
  }

  /// 発行のたびに署名の違う URL を返す（発行し直したことをテストで見分ける）。
  @override
  Future<ArchiveUrl> fetchArchiveUrl(int volumeId) async {
    archiveUrlCalls++;
    if (archiveUrlError case final error?) throw error;
    final filesVersion =
        archiveUrlFilesVersion ??
        (manifests[volumeId] ?? manifest).filesVersion;
    return ArchiveUrl(
      url: archiveUrlOf(
        volumeId,
        filesVersion: filesVersion,
        signature: 'sig-$archiveUrlCalls',
      ),
      filesVersion: filesVersion,
    );
  }

  static String archiveUrlOf(
    int volumeId, {
    required int filesVersion,
    required String signature,
  }) =>
      '${DownloadHarness.apiBaseUrl}/api/v2/volumes/$volumeId/archive'
      '?expires=1759924800&t=1&v=$filesVersion&signature=$signature';
}

/// プラットフォームチャネルに触らない [ArchiveTransport]。
///
/// 呼ばれた操作を記録し、OS から届くイベントはテストから流す
/// （[emit] / [completeWith]）。**画面のテストでも本物の `FileDownloader` を
/// 作らせない**よう、`testOverrides` の既定にもなっている。
///
/// キューの判断が本物のパッケージの振る舞いに依存するところは、同じように
/// 振る舞わせる（都合のよい値を返すフェイクだと、実機でだけ壊れる）:
/// - 再開データは paused を流したときにできる（ネイティブが止め終わってから
///   届く）。それまでの [resume] は `false`（`BaseDownloader.resume` は再開
///   データが無ければ断る）。failed / canceled / completed を流すと捨てる
///   （`_clearPauseResumeInfo`）。[resume] しても最終状態までは残る。
/// - [pause] は、待機しているだけのタスクにも `true` を返す（Android の
///   `pauseTaskWithId` は印を付けるだけ）。印（[pauseMarks]）は ID ごとに
///   残り、取り消しでも投入でも消えない。消えるのは、その ID の転送が
///   実際に止まったとき（印を見た paused を流したとき）だけ。
/// - 再開データが Dart に届くのは、印を見て止まった paused だけ
///   （`processResumeData`）。印の無い paused（9 分の時間切れ）や Wi-Fi
///   設定の変更による再投入では、再開データはネイティブ側にしか無い。
/// - [enqueue] の途中（[onEnqueue]）に届いた [cancel] は空振りする（ネイティブは
///   まだタスクを知らず、知らない ID の取り消しを覚えておかない）。
class FakeArchiveTransport implements ArchiveTransport {
  FakeArchiveTransport({this.supportDirectory, List<String>? log})
    : log = log ?? [];

  /// 転送先の基準（application support）。[completeWith] が書き込む先。
  final Directory? supportDirectory;

  /// 呼び出し順の記録（ファイル削除との前後を確かめる）。
  final List<String> log;

  final _events = StreamController<TransferEvent>.broadcast();

  final startCalls = <({bool wifiOnly, TransferNotificationTexts texts})>[];
  final wifiOnlyCalls = <bool>[];
  final enqueued = <ArchiveTransferRequest>[];
  final paused = <String>[];
  final resumed = <String>[];
  final canceled = <String>[];
  final forgotten = <String>[];

  /// [forgetForeign] で捨てた ID（書き戻されても消し直す方）。
  final foreignForgotten = <String>[];
  int resetCount = 0;
  int snapshotCalls = 0;
  int notificationRequests = 0;
  int foregroundRefreshes = 0;

  /// [sweepOrphanTempFiles] の呼び出し（`staleOnly` の値）。
  final tempSweepModes = <bool>[];

  int get tempSweeps => tempSweepModes.length;

  /// [snapshot] が返す一覧（起動時の照合の入力）。
  List<TransferSnapshot> snapshotResult = const [];

  bool enqueueResult = true;
  bool pauseResult = true;
  bool resumeResult = true;

  /// [enqueue] の途中で起こすこと（投入の await の隙を作る）。
  Future<void> Function(ArchiveTransferRequest request)? onEnqueue;

  /// [pause] の途中で起こすこと（一時停止の往復の隙を作る）。
  Future<void> Function(String taskId)? onPause;

  /// [sweepOrphanTempFiles] の途中で起こすこと（掃除の await の隙を作る）。
  Future<void> Function()? onSweep;

  /// [start] の途中で起こすこと（起動時に届く、閉じている間の完了）。
  Future<void> Function()? onStart;

  /// [reset] の途中で起こすこと（ログアウトの await の隙を作る）。
  Future<void> Function()? onReset;

  /// ネイティブが受け付けて、まだ終わっていないタスク。
  final _native = <String>{};

  /// 再開データがあるタスク。
  final _resumeData = <String>{};

  /// Android の一時停止の印（`BDPlugin.pausedTaskIds`）。
  final _pauseMarks = <String>{};

  /// 一時停止の印が残っている ID（この ID の転送は走り出すとすぐ止まる）。
  Set<String> get pauseMarks => {..._pauseMarks};

  /// ネイティブが受け付けて、取り消されずに残っているタスク（誰も追って
  /// いない転送が裏で走り続けていないかを確かめる）。
  Set<String> get nativeTaskIds => {..._native};

  @override
  Stream<TransferEvent> get events => _events.stream;

  @override
  Future<void> start({
    required bool wifiOnly,
    required TransferNotificationTexts texts,
  }) async {
    log.add('start');
    startCalls.add((wifiOnly: wifiOnly, texts: texts));
    await onStart?.call();
  }

  @override
  Future<void> setWifiOnly(bool value) async => wifiOnlyCalls.add(value);

  @override
  Future<bool> enqueue(ArchiveTransferRequest request) async {
    log.add('enqueue ${request.taskId}');
    enqueued.add(request);
    await onEnqueue?.call(request);
    // ネイティブが受け付けるのは呼び出しが返る直前（この間の取り消しは空振り）。
    if (enqueueResult) {
      _native.add(request.taskId);
      _resumeData.remove(request.taskId);
    }
    return enqueueResult;
  }

  @override
  Future<bool> pause(String taskId) async {
    paused.add(taskId);
    await onPause?.call(taskId);
    if (pauseResult) _pauseMarks.add(taskId);
    return pauseResult;
  }

  @override
  Future<bool> resume(String taskId) async {
    resumed.add(taskId);
    if (!_resumeData.contains(taskId)) return false;
    return resumeResult;
  }

  @override
  Future<bool> hasResumeData(String taskId) async =>
      _resumeData.contains(taskId);

  @override
  Future<void> cancel(String taskId) async {
    log.add('cancel $taskId');
    canceled.add(taskId);
    _native.remove(taskId);
  }

  @override
  Future<List<TransferSnapshot>> snapshot() async {
    snapshotCalls++;
    // 一時停止中として残っている転送には再開データがある。
    for (final snapshot in snapshotResult) {
      if (snapshot.hasResumeData || snapshot.state == TransferState.paused) {
        _resumeData.add(snapshot.taskId);
      }
    }
    return snapshotResult;
  }

  @override
  Future<void> forget(String taskId) async {
    forgotten.add(taskId);
    _resumeData.remove(taskId);
  }

  @override
  Future<void> forgetForeign(String taskId) async {
    forgotten.add(taskId);
    foreignForgotten.add(taskId);
    _resumeData.remove(taskId);
  }

  @override
  Future<void> sweepOrphanTempFiles({bool staleOnly = false}) async {
    log.add('sweep');
    tempSweepModes.add(staleOnly);
    await onSweep?.call();
    log.add('sweep done');
  }

  @override
  Future<void> reset() async {
    log.add('reset');
    resetCount++;
    await onReset?.call();
  }

  @override
  Future<bool> requestNotificationPermission() async {
    notificationRequests++;
    return true;
  }

  @override
  Future<void> refreshForegroundMode() async => foregroundRefreshes++;

  /// OS から届くイベントを流す。
  ///
  /// 本物と同じく、終わった（失敗 / 取り消し / 完了）タスクはネイティブから
  /// 消え、失敗と取り消しでは再開データも捨てられる。paused で Dart に
  /// 再開データが届くのは、一時停止の印を見て止まったときだけ。
  void emit(TransferEvent event) {
    if (event case TransferStateChanged(:final taskId, :final state)) {
      switch (state) {
        case TransferState.failed ||
            TransferState.canceled ||
            TransferState.completed:
          _native.remove(taskId);
          _resumeData.remove(taskId);
        case TransferState.paused:
          // 印を見て止まった（ユーザーの一時停止）ときだけ再開データが届く。
          if (_pauseMarks.remove(taskId)) _resumeData.add(taskId);
        case _:
      }
    }
    _events.add(event);
  }

  /// [volumeId] の直近の投入。
  ArchiveTransferRequest requestOf(int volumeId) => enqueued.lastWhere(
    (request) => ArchiveTaskId.tryParse(request.taskId)?.volumeId == volumeId,
  );

  /// [volumeId] の直近の投入の taskId。
  String taskIdOf(int volumeId) => requestOf(volumeId).taskId;

  /// [taskId] の転送が書き込む先（`downloads/{id}/{v}.zip.download`）。
  File stagingFileOf(String taskId) {
    final task = ArchiveTaskId.tryParse(taskId)!;
    return File(
      p.join(
        supportDirectory!.path,
        'downloads',
        '${task.volumeId}',
        DownloadStore.stagingFilename(task.filesVersion),
      ),
    );
  }

  /// [volumeId] の直近の転送を、[bytes] を書き終えて完了させる。
  void completeWith(int volumeId, List<int> bytes) =>
      completeTask(taskIdOf(volumeId), bytes);

  /// [taskId] の転送を完了させる（本物と同じく、書き終えてから completed）。
  void completeTask(String taskId, List<int> bytes) {
    final file = stagingFileOf(taskId);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    emit(TransferStateChanged(taskId, TransferState.completed));
  }

  /// [volumeId] の直近の転送の状態を変える。
  void setState(int volumeId, TransferState state) =>
      emit(TransferStateChanged(taskIdOf(volumeId), state));

  /// [volumeId] の直近の転送を失敗させる。
  void fail(
    int volumeId,
    TransferFailureKind kind, {
    String message = '',
    int? httpCode,
  }) => emit(
    TransferStateChanged(
      taskIdOf(volumeId),
      TransferState.failed,
      failure: TransferFailure(
        kind: kind,
        httpCode: httpCode,
        message: message,
      ),
    ),
  );
}

/// 後片付けの途中に別の処理を割り込ませられる [DownloadStore]。
///
/// ログアウトの破棄や完了の確定は複数の `await` に跨るので、「削除の後に書き戻す」
/// 「確定の直前に取り消す」といった競合はゲートで作らないと再現しない
/// （イベントループの順序に任せたテストは落ち方が安定しない）。
class GatedDownloadStore extends DownloadStore {
  GatedDownloadStore({
    required super.database,
    required super.directories,
    super.now,
    List<String>? log,
  }) : log = log ?? [];

  /// 呼び出し順の記録（転送の reset との前後を確かめる）。
  final List<String> log;

  /// `deleteAllFiles` に入る前に待たせる（破棄の途中を作る）。
  Completer<void>? beforeDeleteAllFiles;

  /// `deleteOtherVersions` に入る前に待たせる（rename 済み・確定前を作る）。
  Completer<void>? beforeDeleteOtherVersions;

  /// `deleteRow` が DB から消し終えた後、呼び出し元へ戻る前に待たせる
  /// （削除の await の隙に別の処理の保存を差し込む）。
  Completer<void>? afterDeleteRow;

  /// `rotateSessionTag` を失敗させる（ログアウト時に DB へ書けなかった）。
  bool failRotateSessionTag = false;

  /// `deleteAllRows` を失敗させる（ログアウト時に台帳を消せなかった）。
  bool failDeleteAllRows = false;

  /// `loadAll` を失敗させる（台帳が読めず、キューを組み立てられない）。
  bool failLoadAll = false;

  @override
  Future<void> deleteAllRows() {
    log.add('deleteAllRows');
    if (failDeleteAllRows) return Future.error(StateError('db locked'));
    return super.deleteAllRows();
  }

  @override
  Future<Map<int, VolumeDownload>> loadAll() {
    if (failLoadAll) return Future.error(StateError('db broken'));
    return super.loadAll();
  }

  @override
  Future<String> rotateSessionTag() {
    if (failRotateSessionTag) {
      return Future.error(const FileSystemException('disk full'));
    }
    return super.rotateSessionTag();
  }

  /// 次の `save` に入る前に待たせる（台帳の書き込みの await の隙を作る）。
  /// 使われたら `null` に戻る（入ったことを確かめるのに使える）。
  Completer<void>? beforeSave;

  @override
  Future<void> save(VolumeDownload download) async {
    final gate = beforeSave;
    beforeSave = null;
    if (gate != null) await gate.future;
    await super.save(download);
  }

  @override
  Future<void> deleteRow(int volumeId) async {
    await super.deleteRow(volumeId);
    log.add('deleteRow $volumeId');
    final gate = afterDeleteRow;
    afterDeleteRow = null;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> deleteAllFiles() async {
    log.add('deleteAllFiles');
    final gate = beforeDeleteAllFiles;
    beforeDeleteAllFiles = null;
    if (gate != null) await gate.future;
    await super.deleteAllFiles();
  }

  @override
  Future<void> deleteOtherVersions({
    required int volumeId,
    required int keepFilesVersion,
  }) async {
    final gate = beforeDeleteOtherVersions;
    beforeDeleteOtherVersions = null;
    if (gate != null) await gate.future;
    await super.deleteOtherVersions(
      volumeId: volumeId,
      keepFilesVersion: keepFilesVersion,
    );
  }
}

/// メモリ DB + 一時ディレクトリで動くダウンロード一式。
///
/// OS の転送・回線・前面復帰・トークンはすべてフェイク（プラットフォーム
/// チャネルとネットワークを触らない）。
class DownloadHarness {
  DownloadHarness._({
    required this.cache,
    required this.store,
    required this.api,
    required this.transport,
    required this.log,
  });

  factory DownloadHarness.create({
    required VolumeManifest manifest,
    required Uint8List archiveBytes,
  }) {
    final cache = CacheHarness.create();
    final log = <String>[];
    return DownloadHarness._(
      cache: cache,
      log: log,
      store: GatedDownloadStore(
        database: cache.database,
        directories: cache.directories,
        now: cache.clock.now,
        log: log,
      ),
      api: FakeVolumesApi(manifest: manifest, archiveBytes: archiveBytes),
      transport: FakeArchiveTransport(
        supportDirectory: cache.directories.support,
        log: log,
      ),
    );
  }

  /// API の配信元（Bearer を付けてよい相手の判定）。
  static const apiBaseUrl = 'http://localhost:8000';

  final CacheHarness cache;
  final GatedDownloadStore store;
  final FakeVolumesApi api;
  final FakeArchiveTransport transport;

  /// 転送とストアの呼び出し順。
  final List<String> log;

  /// 回線（既定は Wi-Fi。Wi-Fi 限定の設定は本物の drift で持つ）。
  final network = FakeNetworkKindMonitor();

  /// 圏外からの復帰。
  final connectivity = FakeConnectivityMonitor();

  /// 前面復帰。
  final lifecycle = FakeAppResumeMonitor();

  /// 転送に焼き込まれるトークン。
  final authStore = FakeAuthStore(token: 'token-1');

  /// 空き容量（`null` は「分からない」= 本番の既定と同じ）。
  int? freeSpace;

  /// 検証の差し替え（`null` なら本物の ZIP 検証を使う）。
  ArchiveVerifier? verifier;

  /// バックオフで待った時間。
  final delays = <Duration>[];

  /// 待ち時間の間に起こすこと（待っている間の回線の切り替えなど）。
  Future<void> Function()? duringDelay;

  /// 完了後に「オフライン用の詳細を控える」導線が呼ばれたタイトル（#11）。
  ///
  /// 本物は `/api/v2/books/{id}` を叩くので、テストでは記録だけにする。
  final warmedBooks = <int>[];

  List<Override> overrides() => [
    ...cache.overrides(),
    appConfigProvider.overrideWithValue(
      AppConfig.from(apiBaseUrl: apiBaseUrl, flavor: 'development'),
    ),
    authStoreProvider.overrideWithValue(authStore),
    downloadStoreProvider.overrideWith((ref) async => store),
    volumesApiProvider.overrideWithValue(api),
    archiveTransportProvider.overrideWithValue(transport),
    networkKindMonitorProvider.overrideWithValue(network),
    connectivityMonitorProvider.overrideWithValue(connectivity),
    appResumeMonitorProvider.overrideWithValue(lifecycle),
    offlineDetailWarmerProvider.overrideWithValue(
      (bookId) async => warmedBooks.add(bookId),
    ),
    // 待ち時間は記録だけして進める（テストを実時間で待たせない）。
    downloadRetryDelayProvider.overrideWithValue((duration) async {
      delays.add(duration);
      await duringDelay?.call();
    }),
    freeSpaceProbeProvider.overrideWithValue(() async => freeSpace),
    if (verifier case final verifier?)
      archiveVerifierProvider.overrideWithValue(verifier),
  ];

  File archiveFile({int? volumeId, int? filesVersion}) => store.archiveFile(
    volumeId: volumeId ?? api.manifest.id,
    filesVersion: filesVersion ?? api.manifest.filesVersion,
  );

  File stagingFile({int? volumeId, int? filesVersion}) => store.stagingFile(
    volumeId: volumeId ?? api.manifest.id,
    filesVersion: filesVersion ?? api.manifest.filesVersion,
  );
}

/// キューが落ち着く（進行中の処理が無くなる）まで待つ。
///
/// 回数ではなく**キューが抱えている処理**で待つ。このテストは実ファイルへの
/// 書き込みと本物の ZIP 検証を通すので、必要な非同期の段数がマシンの負荷で
/// 変わる（固定回数の `pumpEventQueue` では、重いときだけ待ち切れずに落ちる）。
/// フェイクの転送が流したイベントは次のマイクロタスクで届くので、処理が
/// 空になった後も 1 周回して、新しく始まったものが無いことを確かめる。
Future<void> settleDownloads(ProviderContainer container) async {
  try {
    await container.read(downloadQueueProvider.future);
  } on Object {
    return;
  }
  final queue = container.read(downloadQueueProvider.notifier);
  for (var round = 0; round < 100; round++) {
    await pumpEventQueue();
    await queue.idle;
    await pumpEventQueue();
    if (!queue.hasPendingWork) return;
  }
}

/// テスト用の ZIP（ページ画像 [pages] 枚）。
///
/// 検証は本物の [verifyArchivePages] に通したいので、実際に ZIP を作る。
Uint8List zipWithPages(int pages, {int bytesPerPage = 64}) {
  final archive = Archive();
  for (var i = 0; i < pages; i++) {
    archive.add(
      ArchiveFile.bytes(
        '${(i + 1).toString().padLeft(3, '0')}.jpg',
        List<int>.filled(bytesPerPage, 0x42 + i),
      ),
    );
  }
  return ZipEncoder().encodeBytes(archive);
}

/// テスト用のマニフェスト。
VolumeManifest testManifest({
  int id = 340,
  int bookId = 12,
  int filesVersion = 111,
  required int archiveBytes,
  int pageCount = 3,
  String? archiveEtag = 'a1b2-c3d4',
}) => VolumeManifest(
  id: id,
  bookId: bookId,
  filesVersion: filesVersion,
  archiveBytes: archiveBytes,
  archiveEtag: archiveEtag,
  pageCount: pageCount,
  pages: [
    for (var i = 0; i < pageCount; i++)
      VolumeManifestPage(index: i, extension: 'jpg', bytes: 64),
  ],
);

/// ネットワークもディスクも触らないダウンロードキュー（画面のテスト用）。
class StubDownloadQueue extends DownloadQueue {
  StubDownloadQueue({
    Map<int, VolumeDownload> initial = const {},
    this.applyRemovals = false,
    this.removeError,
    Set<int> failingRemovals = const {},
  }) : initial = {...initial},
       failingRemovals = {...failingRemovals};

  /// 画面へ配る初期状態（`purgeAll` で空にするので変更可能な複製を持つ）。
  final Map<int, VolumeDownload> initial;

  /// 操作を `state` にも反映する（削除後に容量表示が減ることを画面で
  /// 確かめるため）。既定は記録だけ（既存のテストの前提を変えない）。
  ///
  /// - `remove` は行を消す
  /// - `pause` は取得中 / 待機中を中断に（取り直しなら旧世代の completed に戻す）
  /// - `resume` / `enqueue` は待機中に
  /// - `purgeAll` は空に
  final bool applyRemovals;

  /// `remove` で投げる例外（`null` なら [failingRemovals] に既定の例外）。
  ///
  /// [failingRemovals] が空なら全巻、そうでなければその巻だけで投げる。
  final Object? removeError;

  /// `remove` の途中で待たせる（削除の途中で画面を離れる操作の再現）。
  Future<void> Function(int volumeId)? onRemove;

  /// `remove` を失敗させる巻。
  final Set<int> failingRemovals;

  /// OS 側に転送が残っている巻（[hasPendingTransfer] が返す）。
  final pendingTransfers = <int>{};

  @override
  bool hasPendingTransfer(int volumeId) => pendingTransfers.contains(volumeId);

  @override
  Future<void> get reconciled => Future.value();

  final enqueued = <({int volumeId, int bookId})>[];
  final paused = <int>[];
  final resumed = <int>[];
  final removed = <int>[];

  @override
  Future<Map<int, VolumeDownload>> build() async => initial;

  @override
  Future<void> enqueue({required int volumeId, required int bookId}) async {
    enqueued.add((volumeId: volumeId, bookId: bookId));
    if (!applyRemovals) return;
    final existing = state.value?[volumeId];
    _put(
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
          ),
    );
  }

  @override
  Future<void> pause(int volumeId) async {
    paused.add(volumeId);
    if (!applyRemovals) return;
    final existing = state.value?[volumeId];
    if (existing == null || !existing.isActive) return;
    // 本物は取り直しの中断で旧世代の completed へ戻す（`_savePaused`）。
    _put(
      existing.copyWith(
        status: existing.hasInstalledArchive
            ? VolumeDownloadStatus.completed
            : VolumeDownloadStatus.paused,
      ),
    );
  }

  @override
  Future<void> resume(int volumeId) async {
    resumed.add(volumeId);
    if (!applyRemovals) return;
    final existing = state.value?[volumeId];
    if (existing == null) return;
    _put(
      existing.copyWith(
        status: VolumeDownloadStatus.queued,
        clearFailureReason: true,
      ),
    );
  }

  @override
  Future<void> remove(int volumeId) async {
    await onRemove?.call(volumeId);
    final error =
        removeError ??
        (failingRemovals.isEmpty
            ? null
            : const FileSystemException('remove failed'));
    if (error != null &&
        (failingRemovals.isEmpty || failingRemovals.contains(volumeId))) {
      throw error;
    }
    removed.add(volumeId);
    if (!applyRemovals) return;
    state = AsyncData({...?state.value}..remove(volumeId));
  }

  @override
  Future<void> purgeAll() async {
    initial.clear();
    if (applyRemovals) state = const AsyncData({});
  }

  void _put(VolumeDownload download) {
    state = AsyncData({...?state.value, download.volumeId: download});
  }

  /// ダウンロードの状態変化をテストから流す（完了を契機にする導線の検証用）。
  void emit(VolumeDownload download) {
    state = AsyncData({...?state.value, download.volumeId: download});
  }
}

/// drift を触らない「Wi-Fi 接続時のみ」の設定（画面のテスト用）。
class StubDownloadWifiOnly extends DownloadWifiOnly {
  StubDownloadWifiOnly({this.initial = true});

  final bool initial;

  @override
  Future<bool> build() async => initial;

  @override
  Future<void> set(bool value) async => state = AsyncData(value);
}

/// 台帳を読み終えないキュー（圏外コールドスタートの読み込み中を模す）。
///
/// 台帳の読み込みは `path_provider` とディレクトリ作成を待つので、一覧
/// （drift の控え）より遅れる。その間に「ダウンロード済みが 0 件」と
/// 言い切らないことを確かめるために使う（#11）。
class LoadingDownloadQueue extends DownloadQueue {
  final _ledger = Completer<Map<int, VolumeDownload>>();

  @override
  Future<Map<int, VolumeDownload>> build() => _ledger.future;

  /// 読み込みを終わらせる。
  void finish([Map<int, VolumeDownload> downloads = const {}]) =>
      _ledger.complete(downloads);
}
