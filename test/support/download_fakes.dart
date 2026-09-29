import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:comic_laz/core/device/network_kind_monitor.dart';
import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/data/api/volumes_api.dart';
import 'package:comic_laz/domain/models/volume_manifest.dart';
import 'package:comic_laz/features/downloads/application/download_queue.dart';
import 'package:comic_laz/features/downloads/application/download_settings.dart';
import 'package:comic_laz/features/downloads/data/archive_verifier.dart';
import 'package:comic_laz/features/downloads/data/download_store.dart';
import 'package:comic_laz/features/downloads/data/free_space_probe.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/offline/application/offline_detail_warmer.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cache_fakes.dart';
import 'progress_fakes.dart';

/// 1 回の `downloadArchive` 呼び出しでの振る舞い。
///
/// 「途中まで届いて切れた」「429 が返った」を作り分けるために使う。
class FakeArchiveStep {
  const FakeArchiveStep({this.bytes, this.error, this.onDelivered});

  /// この呼び出しで書き足すバイト数（`null` は最後まで）。
  final int? bytes;

  /// 書いたあとに投げる例外。
  final Object? error;

  /// 書いたあとに実行する処理（テストから中断 / キャンセルを差し込む）。
  final Future<void> Function()? onDelivered;
}

/// ネットワークを触らない [VolumesApi]。
///
/// `Range` の再開は本物と同じく**保存先ファイルの実サイズ**を起点にする
/// （テストが「どこから続きを取りに行ったか」を実ファイルで検証できる）。
class FakeVolumesApi implements VolumesApi {
  FakeVolumesApi({required this.manifest, required this.archiveBytes});

  /// 既定のマニフェスト。
  VolumeManifest manifest;

  /// 巻ごとのマニフェスト（無ければ [manifest]）。
  final manifests = <int, VolumeManifest>{};

  /// 完成形の ZIP。
  Uint8List archiveBytes;

  /// マニフェスト取得で投げる例外。
  Object? manifestError;

  /// マニフェストを返す前に実行する処理（取得の準備中に中断を差し込む）。
  Future<void> Function()? onManifest;

  int manifestCalls = 0;
  int archiveCalls = 0;

  /// 呼び出しごとの振る舞い（足りなくなったら最後のものを使い続ける）。
  List<FakeArchiveStep> steps = const [FakeArchiveStep()];

  /// 各呼び出しでサーバーに要求した開始位置。
  final requestedOffsets = <int>[];

  /// 各呼び出しで送った `If-Range`。
  final ifRangeEtags = <String?>[];

  @override
  Future<VolumeManifest> fetchManifest(int volumeId) async {
    manifestCalls++;
    await onManifest?.call();
    if (manifestError case final error?) throw error;
    return manifests[volumeId] ?? manifest;
  }

  @override
  Future<ArchiveDownloadResult> downloadArchive({
    required int volumeId,
    required File target,
    String? ifRangeEtag,
    ArchiveProgress? onProgress,
    CancelToken? cancelToken,
  }) async {
    archiveCalls++;
    final offset = target.existsSync() ? target.lengthSync() : 0;
    requestedOffsets.add(offset);
    ifRangeEtags.add(ifRangeEtag);

    final step = steps[math.min(archiveCalls - 1, steps.length - 1)];
    final end = math.min(
      archiveBytes.length,
      offset + (step.bytes ?? archiveBytes.length),
    );
    if (end > offset) {
      final sink = target.openSync(mode: FileMode.writeOnlyAppend);
      try {
        sink.writeFromSync(archiveBytes.sublist(offset, end));
      } finally {
        sink.closeSync();
      }
      onProgress?.call(end, archiveBytes.length);
    }

    await step.onDelivered?.call();
    if (cancelToken?.isCancelled ?? false) {
      throw const RequestCancelledException();
    }
    if (step.error case final error?) throw error;

    return ArchiveDownloadResult(
      receivedBytes: end,
      resumed: offset > 0,
      contentLength: archiveBytes.length,
    );
  }
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
  });

  /// `deleteAllFiles` に入る前に待たせる（破棄の途中を作る）。
  Completer<void>? beforeDeleteAllFiles;

  /// `deleteOtherVersions` に入る前に待たせる（rename 済み・確定前を作る）。
  Completer<void>? beforeDeleteOtherVersions;

  @override
  Future<void> deleteAllFiles() async {
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
class DownloadHarness {
  DownloadHarness._({
    required this.cache,
    required this.store,
    required this.api,
  });

  factory DownloadHarness.create({
    required VolumeManifest manifest,
    required Uint8List archiveBytes,
  }) {
    final cache = CacheHarness.create();
    return DownloadHarness._(
      cache: cache,
      store: GatedDownloadStore(
        database: cache.database,
        directories: cache.directories,
        now: cache.clock.now,
      ),
      api: FakeVolumesApi(manifest: manifest, archiveBytes: archiveBytes),
    );
  }

  final CacheHarness cache;
  final GatedDownloadStore store;
  final FakeVolumesApi api;

  /// 回線（既定は Wi-Fi。Wi-Fi 限定の設定は本物の drift で持つ）。
  final network = FakeNetworkKindMonitor();

  /// 空き容量（`null` は「分からない」= 本番の既定と同じ）。
  int? freeSpace;

  /// 検証の差し替え（`null` なら本物の ZIP 検証を使う）。
  ArchiveVerifier? verifier;

  /// バックオフで待った時間。
  final delays = <Duration>[];

  /// 待ち時間の間に起こすこと（待っている間の回線の切り替えなど）。
  Future<void> Function()? duringDelay;

  /// 空き容量を調べている間に起こすこと（取得を始める直前の割り込み）。
  Future<void> Function()? duringFreeSpaceProbe;

  /// 完了後に「オフライン用の詳細を控える」導線が呼ばれたタイトル（#11）。
  ///
  /// 本物は `/api/v2/books/{id}` を叩くので、テストでは記録だけにする。
  final warmedBooks = <int>[];

  List<Override> overrides({int concurrency = 1}) => [
    ...cache.overrides(),
    downloadStoreProvider.overrideWith((ref) async => store),
    volumesApiProvider.overrideWithValue(api),
    networkKindMonitorProvider.overrideWithValue(network),
    downloadConcurrencyProvider.overrideWithValue(concurrency),
    offlineDetailWarmerProvider.overrideWithValue(
      (bookId) async => warmedBooks.add(bookId),
    ),
    // 待ち時間は記録だけして進める（テストを実時間で待たせない）。
    downloadRetryDelayProvider.overrideWithValue((duration) async {
      delays.add(duration);
      await duringDelay?.call();
    }),
    freeSpaceProbeProvider.overrideWithValue(() async {
      await duringFreeSpaceProbe?.call();
      return freeSpace;
    }),
    if (verifier case final verifier?)
      archiveVerifierProvider.overrideWithValue(verifier),
  ];

  File archiveFile({int? filesVersion}) => store.archiveFile(
    volumeId: api.manifest.id,
    filesVersion: filesVersion ?? api.manifest.filesVersion,
  );

  File partFile({int? filesVersion}) => store.partFile(
    volumeId: api.manifest.id,
    filesVersion: filesVersion ?? api.manifest.filesVersion,
  );
}

/// キューが落ち着く（走行中・待機中が無くなる）まで待つ。
///
/// 固定回数の `pumpEventQueue` では足りないことがある。このテストは実ファイルへの
/// 書き込みと本物の ZIP 検証を通すので、必要な非同期の段数がマシンの負荷で変わる
/// （テストを並列に流すと顕著で、待ち切れないまま tearDown が DB を閉じてしまう）。
/// 回数ではなく**状態**で待てば、速いマシンでは早く抜け、遅いマシンでも取りこぼさない。
///
/// 意図的に取得を止めているテスト（ゲートで待たせる）では落ち着かないので、
/// [rounds] を使い切って戻る。そのときも「開始済みで止まっている」状態は作れている。
Future<void> settleDownloads(
  ProviderContainer container, {
  int rounds = 200,
}) async {
  for (var round = 0; round < rounds; round++) {
    await pumpEventQueue(times: 5);
    // `pumpEventQueue` はイベントループに譲るだけで**実時間を待たない**ので、
    // 実ファイルの読み書きと ZIP 検証が終わる前に 200 回を使い切ってしまう
    // （マシンが重いときだけ落ちる、原因の分かりにくいテストになる）。
    // 1 周ごとに僅かに実時間を進めて、I/O が完了する余地を作る。
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final downloads = container.read(downloadQueueProvider).value;
    // まだ build 中（null）なら落ち着いたとは言えない。
    if (downloads == null) continue;
    if (downloads.values.any((download) => download.isActive)) continue;
    // 台帳が落ち着いた後も、破棄された世代の後片付け（一時ファイルの削除）が
    // 残っていることがある。tearDown と競らせないよう少しだけ余分に回す。
    await pumpEventQueue(times: 10);
    return;
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
  StubDownloadQueue({Map<int, VolumeDownload> initial = const {}})
    : initial = {...initial};

  /// 画面へ配る初期状態（`purgeAll` で空にするので変更可能な複製を持つ）。
  final Map<int, VolumeDownload> initial;

  final enqueued = <({int volumeId, int bookId})>[];
  final paused = <int>[];
  final resumed = <int>[];
  final removed = <int>[];

  @override
  Future<Map<int, VolumeDownload>> build() async => initial;

  @override
  Future<void> enqueue({required int volumeId, required int bookId}) async {
    enqueued.add((volumeId: volumeId, bookId: bookId));
  }

  @override
  Future<void> pause(int volumeId) async => paused.add(volumeId);

  @override
  Future<void> resume(int volumeId) async => resumed.add(volumeId);

  @override
  Future<void> remove(int volumeId) async => removed.add(volumeId);

  @override
  Future<void> purgeAll() async => initial.clear();

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
