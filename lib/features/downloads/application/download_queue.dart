import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/format.dart';
import '../../../data/api/volumes_api.dart';
import '../../../domain/models/volume_manifest.dart';
import '../data/archive_verifier.dart';
import '../data/download_store.dart';
import '../data/free_space_probe.dart';
import '../domain/volume_download.dart';

part 'download_queue.g.dart';

/// 同時に走らせるダウンロードの数。
///
/// 自宅サーバーは HDD なので、並列に ZIP を読ませるとシークだらけになって
/// 全体が遅くなる（1 巻 = 1 ファイルのシーケンシャル read が一番速い）。
/// 既定は 1。テストや将来の設定から変えられるよう provider にしておく。
@Riverpod(keepAlive: true)
int downloadConcurrency(Ref ref) => 1;

/// 再試行の待ち時間（テストから即時にできるようにする）。
typedef RetryDelay = Future<void> Function(Duration duration);

@Riverpod(keepAlive: true)
RetryDelay downloadRetryDelay(Ref ref) => Future<void>.delayed;

/// 1 巻あたりの再試行回数（初回を含む）。
const maxDownloadAttempts = 3;

/// `Retry-After` が異常に大きい場合の上限。
const maxRetryAfter = Duration(minutes: 5);

/// 空き容量チェックの余裕分。
///
/// ぴったり入るだけの空きしか無い状態で始めると、OS やほかのアプリの書き込みで
/// 途中で詰まる。
const freeSpaceMarginBytes = 64 * 1024 * 1024;

/// 進捗を DB へ書く間隔（バイト）。
///
/// 毎チャンク書くと 1 巻で数千回の UPDATE になる。再開位置は一時ファイルの
/// 実サイズを正とするので、DB の値が多少古くても再開はずれない。
const progressPersistIntervalBytes = 4 * 1024 * 1024;

/// 取得を止める理由（後始末が変わる）。
enum _StopIntent {
  /// 一時ファイルを残して中断する。
  pause,

  /// 一時ファイルも台帳も捨てる。
  cancel,
}

/// 巻単位のダウンロードキュー。
///
/// - 同時実行数を [downloadConcurrency] に制限する
/// - 中断・再開は `Range`（一時ファイルの実サイズを起点にする）
/// - 失敗は指数バックオフで再試行。429 は `Retry-After` に従う
/// - 完了前に検証（サイズ / ZIP として開けるか / ページ数）し、
///   通ったものだけ `.part` から本番のファイル名へ rename する
@Riverpod(keepAlive: true)
class DownloadQueue extends _$DownloadQueue {
  /// 走行中の取得をキャンセルするためのトークン。
  final _cancelTokens = <int, CancelToken>{};

  /// 止めたあとの後始末の指定（中断 / キャンセル）。
  final _stopIntents = <int, _StopIntent>{};

  /// 走行中の巻 ID。
  final _running = <int>{};

  /// 最後に DB へ書いた受信バイト数。
  final _persistedBytes = <int, int>{};

  /// 破棄の世代。[purgeAll] のたびに進む。
  ///
  /// ログアウトより前に始まった取得が、破棄の後に完了して前のユーザーの
  /// データを書き戻さないようにするための仕切り。
  int _generation = 0;

  DownloadStore? _store;

  @override
  Future<Map<int, VolumeDownload>> build() async {
    // Notifier は再構築でも同じインスタンスが使い回されるため、
    // 前回の走行を必ず畳んでから作り直す。
    _cancelAll();
    _running.clear();
    _persistedBytes.clear();

    final store = await ref.watch(downloadStoreProvider.future);
    _store = store;
    ref.onDispose(_cancelAll);

    final loaded = await store.loadAll();
    final restored = <int, VolumeDownload>{};
    for (final entry in loaded.entries) {
      // アプリが落ちた時点で「取得中」だったものは中断に戻す。
      // 起動と同時に自動再開はしない（HDD サーバーへ一斉に取りに行かせない。
      // モバイル回線で勝手に数百 MB 落とさない）。一時ファイルは残すので、
      // ユーザーが再開すれば途中から続く。
      final download = entry.value.isActive
          ? entry.value.copyWith(status: VolumeDownloadStatus.paused)
          : entry.value;
      if (download != entry.value) await store.save(download);
      restored[entry.key] = download;
    }
    return restored;
  }

  /// ダウンロードを積む（既に走っているものは無視）。
  ///
  /// 「更新あり」の取り直しも同じ入口。マニフェストを取り直すので、
  /// 呼び出し側は `files_version` を知らなくてよい。
  Future<void> enqueue({required int volumeId, required int bookId}) async {
    await future;
    if (!ref.mounted) return;

    final existing = state.value?[volumeId];
    if (existing != null && existing.isActive) return;

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
    _pump();
  }

  /// 中断する（一時ファイルは残す）。
  Future<void> pause(int volumeId) async {
    await future;
    if (!ref.mounted) return;

    final token = _cancelTokens[volumeId];
    if (token != null) {
      // 後始末は走行中のタスク（[_handleStop]）が行う。
      _stopIntents[volumeId] = _StopIntent.pause;
      token.cancel('paused');
      return;
    }

    final current = state.value?[volumeId];
    if (current == null || !current.isActive) return;
    await _save(current.copyWith(status: VolumeDownloadStatus.paused));
  }

  /// 中断 / 失敗したダウンロードを続きから再開する。
  Future<void> resume(int volumeId) async {
    await future;
    if (!ref.mounted) return;
    final current = state.value?[volumeId];
    if (current == null || !current.isResumable) return;
    await enqueue(volumeId: volumeId, bookId: current.bookId);
  }

  /// キャンセル / 削除（巻単位）。
  ///
  /// 走行中なら止めてから、一時ファイルも完了済みのアーカイブも台帳も消す。
  Future<void> remove(int volumeId) async {
    await future;
    if (!ref.mounted) return;

    final token = _cancelTokens[volumeId];
    if (token != null) {
      _stopIntents[volumeId] = _StopIntent.cancel;
      token.cancel('cancelled');
      return;
    }
    await _deleteEverything(volumeId);
  }

  /// 端末内のダウンロードを全部捨てる（ログアウト）。
  Future<void> purgeAll() async {
    await future;
    _generation++;
    _cancelAll();
    _running.clear();
    _persistedBytes.clear();

    final store = _store;
    if (store != null) {
      await store.deleteAllRows();
      await store.deleteAllFiles();
    }
    if (!ref.mounted) return;
    state = const AsyncData({});
  }

  // ---------------------------------------------------------------- 実行

  /// 空いている枠に待機中のダウンロードを載せる。
  void _pump() {
    final limit = ref.read(downloadConcurrencyProvider);
    while (_running.length < limit) {
      final next = _nextQueued();
      if (next == null) return;
      _running.add(next);
      unawaited(
        _run(next).whenComplete(() {
          _running.remove(next);
          if (ref.mounted) _pump();
        }),
      );
    }
  }

  int? _nextQueued() {
    for (final download in state.value?.values ?? const <VolumeDownload>[]) {
      if (download.status != VolumeDownloadStatus.queued) continue;
      if (_running.contains(download.volumeId)) continue;
      return download.volumeId;
    }
    return null;
  }

  Future<void> _run(int volumeId) async {
    final store = _store;
    final generation = _generation;
    if (store == null) return;

    var download = state.value?[volumeId];
    if (download == null) return;
    await _save(download.copyWith(status: VolumeDownloadStatus.downloading));

    final VolumeManifest manifest;
    try {
      manifest = await ref.read(volumesApiProvider).fetchManifest(volumeId);
    } on Object catch (error) {
      await _fail(volumeId, _messageOf(error), generation: generation);
      return;
    }
    if (_isStale(generation)) return;

    download = state.value?[volumeId];
    if (download == null) return;
    download = download.copyWith(
      filesVersion: manifest.filesVersion,
      totalBytes: manifest.archiveBytes,
      pageCount: manifest.pageCount,
      archiveEtag: manifest.archiveEtag,
    );

    await store.ensureVolumeDirectory(volumeId);
    final archive = store.archiveFile(
      volumeId: volumeId,
      filesVersion: manifest.filesVersion,
    );
    final part = store.partFile(
      volumeId: volumeId,
      filesVersion: manifest.filesVersion,
    );

    // 同じ世代が既に手元にある（取り直しの空振り）。落とし直さない。
    if (archive.existsSync() &&
        (manifest.archiveBytes == 0 ||
            archive.lengthSync() == manifest.archiveBytes)) {
      await _complete(download, manifest, generation: generation);
      return;
    }

    final received = part.existsSync() ? part.lengthSync() : 0;
    _persistedBytes[volumeId] = received;
    await _save(download.copyWith(receivedBytes: received));

    if (await _hasNotEnoughSpace(manifest.archiveBytes - received)) {
      await _fail(
        volumeId,
        '端末の空き容量が足りません（${formatBytes(manifest.archiveBytes - received)} 必要です）。',
        generation: generation,
      );
      return;
    }

    if (!await _fetch(volumeId, manifest, part, generation: generation)) return;
    if (_isStale(generation)) {
      await _deleteQuietly(part);
      return;
    }

    final verified = await _verify(
      volumeId,
      manifest,
      part,
      generation: generation,
    );
    if (!verified) return;

    try {
      if (archive.existsSync()) await archive.delete();
      // 検証が通ってから初めて本番のファイル名にする。途中のデータが
      // 「ダウンロード済み」と認識されることは無い。
      await part.rename(archive.path);
      await store.writeManifest(manifest);
    } on FileSystemException catch (error) {
      await _deleteQuietly(part);
      await _fail(volumeId, _fileSystemMessage(error), generation: generation);
      return;
    }
    await store.deleteOtherVersions(
      volumeId: volumeId,
      keepFilesVersion: manifest.filesVersion,
    );

    final total = manifest.archiveBytes > 0
        ? manifest.archiveBytes
        : archive.lengthSync();
    await _complete(
      download.copyWith(receivedBytes: total, totalBytes: total),
      manifest,
      generation: generation,
    );
  }

  /// アーカイブを取得する。成功したら `true`。
  ///
  /// 中断 / キャンセル / 失敗の後始末はこの中で終わらせる。
  Future<bool> _fetch(
    int volumeId,
    VolumeManifest manifest,
    File part, {
    required int generation,
  }) async {
    final api = ref.read(volumesApiProvider);

    for (var attempt = 1; ; attempt++) {
      final token = CancelToken();
      _cancelTokens[volumeId] = token;
      try {
        await api.downloadArchive(
          volumeId: volumeId,
          target: part,
          ifRangeEtag: manifest.archiveEtag,
          cancelToken: token,
          onProgress: (received, total) => _onProgress(volumeId, received),
        );
        return true;
      } on RequestCancelledException {
        await _handleStop(volumeId, part);
        return false;
      } on FileSystemException catch (error) {
        // 保存先の失敗（容量不足など）。取り直しても直らないので再試行しない。
        await _fail(
          volumeId,
          _fileSystemMessage(error),
          generation: generation,
        );
        return false;
      } on ApiException catch (error) {
        if (!_isRetryable(error) || attempt >= maxDownloadAttempts) {
          await _fail(volumeId, error.message, generation: generation);
          return false;
        }
        await ref.read(downloadRetryDelayProvider)(_backoff(error, attempt));
        if (!ref.mounted || _isStale(generation)) return false;
        // 待っている間に止められていたら、再試行せずに後始末する。
        if (_stopIntents.containsKey(volumeId)) {
          await _handleStop(volumeId, part);
          return false;
        }
        _emit(
          state.value?[volumeId]?.copyWith(
            status: VolumeDownloadStatus.downloading,
          ),
        );
      } finally {
        _cancelTokens.remove(volumeId);
      }
    }
  }

  /// 落としたものが本物か確かめる。通らなければ一時ファイルごと捨てる。
  Future<bool> _verify(
    int volumeId,
    VolumeManifest manifest,
    File part, {
    required int generation,
  }) async {
    final actual = part.existsSync() ? part.lengthSync() : 0;
    if (manifest.archiveBytes > 0 && actual != manifest.archiveBytes) {
      await _failVerification(
        volumeId,
        part,
        'ダウンロードしたデータのサイズが一致しません'
        '（${formatBytes(actual)} / ${formatBytes(manifest.archiveBytes)}）。',
        generation: generation,
      );
      return false;
    }

    final int pages;
    try {
      pages = await ref.read(archiveVerifierProvider)(part);
    } on ArchiveVerificationException catch (error) {
      await _failVerification(
        volumeId,
        part,
        error.message,
        generation: generation,
      );
      return false;
    } on Object catch (error) {
      await _failVerification(
        volumeId,
        part,
        'ダウンロードしたファイルを検証できませんでした（$error）。',
        generation: generation,
      );
      return false;
    }

    if (manifest.pageCount > 0 && pages != manifest.pageCount) {
      await _failVerification(
        volumeId,
        part,
        'ページ数が一致しません（$pages / ${manifest.pageCount} ページ）。',
        generation: generation,
      );
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------- 後始末

  Future<void> _handleStop(int volumeId, File part) async {
    final intent = _stopIntents.remove(volumeId) ?? _StopIntent.pause;
    if (intent == _StopIntent.cancel) {
      await _deleteEverything(volumeId);
      return;
    }

    final current = state.value?[volumeId];
    if (current == null) return;
    final received = part.existsSync() ? part.lengthSync() : 0;
    await _save(
      current.copyWith(
        status: VolumeDownloadStatus.paused,
        receivedBytes: received,
      ),
    );
  }

  Future<void> _deleteEverything(int volumeId) async {
    final store = _store;
    if (store != null) {
      await store.deleteRow(volumeId);
      await store.deleteFiles(volumeId);
    }
    _persistedBytes.remove(volumeId);
    _forget(volumeId);
  }

  Future<void> _fail(
    int volumeId,
    String reason, {
    required int generation,
  }) async {
    if (_isStale(generation)) return;
    final current = state.value?[volumeId];
    if (current == null) return;
    await _save(
      current.copyWith(
        status: VolumeDownloadStatus.failed,
        failureReason: reason,
      ),
    );
  }

  /// 検証に失敗したら一時ファイルごと捨てる（中途半端なデータを残さない）。
  Future<void> _failVerification(
    int volumeId,
    File part,
    String reason, {
    required int generation,
  }) async {
    await _deleteQuietly(part);
    final current = state.value?[volumeId];
    if (current != null) {
      _persistedBytes[volumeId] = 0;
      if (!_isStale(generation)) {
        await _save(
          current.copyWith(
            status: VolumeDownloadStatus.failed,
            receivedBytes: 0,
            failureReason: reason,
          ),
        );
        return;
      }
    }
    await _fail(volumeId, reason, generation: generation);
  }

  Future<void> _complete(
    VolumeDownload download,
    VolumeManifest manifest, {
    required int generation,
  }) async {
    if (_isStale(generation)) return;
    _persistedBytes.remove(download.volumeId);
    await _save(
      download.copyWith(
        status: VolumeDownloadStatus.completed,
        filesVersion: manifest.filesVersion,
        pageCount: manifest.pageCount,
        clearFailureReason: true,
      ),
    );
  }

  // ---------------------------------------------------------------- 小道具

  void _onProgress(int volumeId, int received) {
    final current = state.value?[volumeId];
    if (current == null) return;
    final next = current.copyWith(receivedBytes: received);
    _emit(next);

    final persisted = _persistedBytes[volumeId] ?? 0;
    if (received - persisted < progressPersistIntervalBytes) return;
    _persistedBytes[volumeId] = received;
    unawaited(_store?.save(next).catchError((Object _) {}) ?? Future.value());
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

  void _cancelAll() {
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) token.cancel('disposed');
    }
    _cancelTokens.clear();
    _stopIntents.clear();
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
      // 消せなくても次の取得が上書きする。
    }
  }

  /// 時間を置けば直る見込みがある失敗か。
  static bool _isRetryable(ApiException error) => switch (error) {
    NetworkException() => true,
    ApiTimeoutException() => true,
    ServerException() => true,
    TooManyRequestsException() => true,
    _ => false,
  };

  /// 待ち時間。429 はサーバーの指示（`Retry-After`）に従う。
  static Duration _backoff(ApiException error, int attempt) {
    if (error is TooManyRequestsException) {
      final retryAfter = error.retryAfter;
      if (retryAfter != null) {
        return retryAfter > maxRetryAfter ? maxRetryAfter : retryAfter;
      }
    }
    // 2 秒 → 4 秒 →（上限まで）。自宅サーバーを叩き続けない。
    return Duration(seconds: 1 << attempt);
  }

  static String _messageOf(Object error) => switch (error) {
    final ApiException error => error.message,
    final FileSystemException error => _fileSystemMessage(error),
    _ => 'ダウンロードに失敗しました。',
  };

  /// 端末側の書き込み失敗。容量不足（ENOSPC）だけは原因を明示する。
  static String _fileSystemMessage(FileSystemException error) {
    // errno 28 = ENOSPC（Android / iOS / Linux / macOS 共通）。
    // Windows は ERROR_DISK_FULL(112) / ERROR_HANDLE_DISK_FULL(39)。
    const outOfSpace = {28, 39, 112};
    if (outOfSpace.contains(error.osError?.errorCode)) {
      return '端末の空き容量が足りません。不要なデータを削除してからやり直してください。';
    }
    return '端末にデータを保存できませんでした。';
  }
}
