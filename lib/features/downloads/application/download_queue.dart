import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/format.dart';
import '../../../data/api/volumes_api.dart';
import '../../../domain/models/volume_manifest.dart';
import '../../offline/application/offline_detail_warmer.dart';
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

  /// 取り直しを始めた時点で端末にあった「完了済みの世代」。
  ///
  /// 「更新あり」の取り直しが失敗 / 中断しても、台帳はここへ戻す。
  /// 通信の失敗で手元のキャッシュ（オフラインで読める旧世代）を捨てないため
  /// （落とし直しに失敗した瞬間に、読める ZIP を指す行が台帳から消えてしまう）。
  final _installed = <int, VolumeDownload>{};

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
    _installed.clear();

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
    // 取得はまだ始まっていない（マニフェスト取得中 / 待機中）。ここで中断を
    // 台帳に書けば、[_run] が続きを流さずに畳む。
    await _savePaused(current);
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
    _installed.clear();

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
    // マニフェスト取得の間は [CancelToken] がまだ無いので、[pause] は台帳の
    // status だけを書き換えて戻る。ここで status を見ないと「中断中」と表示した
    // まま数百 MB を落としきってしまう（モバイル回線を勝手に使い切らせない）。
    if (!download.isActive) return;

    // 世代にかかわる項目（filesVersion / pageCount / archive_etag）は**検証が
    // 通ってから**台帳に書く（[_complete]）。取り直しの途中で落ちても、台帳は
    // 端末にある旧世代を指したままにしておきたい（#11 のページ解決が実体の無い
    // 世代を指さないようにする）。進捗表示に必要な全体バイト数だけ先に入れる。
    download = download.copyWith(totalBytes: manifest.archiveBytes);

    await store.ensureVolumeDirectory(volumeId);
    final archive = store.archiveFile(
      volumeId: volumeId,
      filesVersion: manifest.filesVersion,
    );
    final part = store.partFile(
      volumeId: volumeId,
      filesVersion: manifest.filesVersion,
    );

    // 同じ世代が既に手元にある（取り直しの空振り / rename 済みで確定前に落ちた）。
    // 落とし直さないが、マニフェストの保存と旧世代の掃除は下でやり直す。
    final alreadyHave =
        archive.existsSync() &&
        (manifest.archiveBytes == 0 ||
            archive.lengthSync() == manifest.archiveBytes);

    if (!alreadyHave) {
      final received = part.existsSync() ? part.lengthSync() : 0;
      _persistedBytes[volumeId] = received;
      await _save(download.copyWith(receivedBytes: received));

      // 一時ファイルが既に全長ぶん溜まっている（検証 / rename の直前で OS に
      // 殺された）場合は取りに行かない。`Range: bytes={全長}-` はサーバー
      // （Symfony / nginx）が 416 を返し、それは再試行対象外なので再開するたび
      // 同じ失敗になって永久に完了できなくなる。多すぎる場合も検証へ回す
      // （サイズ不一致で一時ファイルを捨て、次の取得がやり直せる）。
      final hasEverything =
          manifest.archiveBytes > 0 && received >= manifest.archiveBytes;

      if (!hasEverything) {
        if (await _hasNotEnoughSpace(manifest.archiveBytes - received)) {
          await _fail(
            volumeId,
            '端末の空き容量が足りません（${formatBytes(manifest.archiveBytes - received)} 必要です）。',
            generation: generation,
          );
          return;
        }

        if (!await _fetch(volumeId, manifest, part, generation: generation)) {
          return;
        }
        if (_isStale(generation)) {
          await _deleteQuietly(part);
          return;
        }
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
      } on FileSystemException catch (error) {
        await _deleteQuietly(part);
        await _fail(
          volumeId,
          _fileSystemMessage(error),
          generation: generation,
        );
        return;
      }
    }

    // マニフェストは早期完了の経路でも必ず書く。rename 済み・マニフェスト未保存
    // で落ちた巻をそのまま「ダウンロード済み」に確定させると、{v}.json が無い
    // まま固定されて #11 のページ解決が恒久的にできなくなる。
    try {
      await store.writeManifest(manifest);
    } on FileSystemException catch (error) {
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
        await _handleStop(volumeId, part, generation: generation);
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
          await _handleStop(volumeId, part, generation: generation);
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

  Future<void> _handleStop(
    int volumeId,
    File part, {
    required int generation,
  }) async {
    final intent = _stopIntents.remove(volumeId) ?? _StopIntent.pause;
    if (intent == _StopIntent.cancel) {
      await _deleteEverything(volumeId);
      return;
    }

    // ログアウト（[purgeAll]）と競合した取得もここへ来る。キャンセル例外は破棄の
    // 途中（`await` の隙）に届くので、世代を見ずに書き戻すと前のユーザーの行が
    // 削除の後に復活する（次の起動で「中断中」として一覧に出てしまう。#15）。
    if (_isStale(generation)) return;

    final current = state.value?[volumeId];
    if (current == null) return;
    final received = part.existsSync() ? part.lengthSync() : 0;
    await _savePaused(current, receivedBytes: received);
  }

  Future<void> _deleteEverything(int volumeId) async {
    final store = _store;
    if (store != null) {
      await store.deleteRow(volumeId);
      await store.deleteFiles(volumeId);
    }
    _persistedBytes.remove(volumeId);
    _installed.remove(volumeId);
    _forget(volumeId);
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
  }

  /// 検証に失敗したら一時ファイルごと捨てる（中途半端なデータを残さない）。
  Future<void> _failVerification(
    int volumeId,
    File part,
    String reason, {
    required int generation,
  }) async {
    await _deleteQuietly(part);
    _persistedBytes[volumeId] = 0;
    await _fail(volumeId, reason, generation: generation, resetProgress: true);
  }

  Future<void> _complete(
    VolumeDownload download,
    VolumeManifest manifest, {
    required int generation,
  }) async {
    if (_isStale(generation)) return;
    // 取り消し（[remove]）と競合した取得を書き戻さない。実体を消した後に
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
  /// オフラインで読めるはずの巻が読めなくなる（一時ファイルは残るので、
  /// もう一度「更新あり」を押せば続きから取り直せる）。
  Future<void> _savePaused(VolumeDownload current, {int? receivedBytes}) async {
    final installed = _installed.remove(current.volumeId);
    if (installed != null) {
      await _save(installed);
      return;
    }
    await _save(
      current.copyWith(
        status: VolumeDownloadStatus.paused,
        receivedBytes: receivedBytes,
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
