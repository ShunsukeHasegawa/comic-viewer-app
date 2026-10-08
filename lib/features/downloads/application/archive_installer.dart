import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/utils/format.dart';
import '../../../data/api/volumes_api.dart';
import '../../../domain/models/volume_manifest.dart';
import '../../offline/application/offline_detail_warmer.dart';
import '../data/archive_verifier.dart';
import '../domain/archive_task_id.dart';
import '../domain/volume_download.dart';
import 'download_failure_policy.dart';
import 'download_queue_memory.dart';
import 'transfer_cleanup.dart';

/// 転送が終わった巻の確定（検証・`.zip.download` からの rename・台帳の完了）
/// （#32）。
///
/// 1 巻ずつ鎖に載せて行う（同じ巻の完了の再送と競らせない）。検証が通って
/// から初めて本番のファイル名にし、世代にかかわる台帳の項目もそこで書く
/// （途中のデータを「ダウンロード済み」と認識させない。#11）。
class ArchiveInstaller {
  ArchiveInstaller(this._memory, this._host, this._cleanup);

  final DownloadQueueMemory _memory;
  final DownloadQueueHost _host;
  final TransferCleanup _cleanup;

  /// 確定を鎖に載せる。
  void schedule(ArchiveTaskId task) {
    final volumeId = task.volumeId;
    final isCurrent = _memory.tasks[volumeId] == task;
    if (isCurrent) {
      if (_memory.installing.contains(volumeId)) return;
      _memory.awaitingInstall.remove(volumeId);
      _memory.installing.add(volumeId);
    }
    final generation = _host.generation;
    final link = _memory.installChain.then((_) async {
      try {
        await _install(task, generation);
      } finally {
        if (generation == _host.generation && _memory.tasks[volumeId] == task) {
          _memory.installing.remove(volumeId);
        }
      }
    });
    _memory.installChain = link.catchError((Object _) {});
    _host.track(link);
  }

  /// 転送が終わった巻を検証して確定する。
  ///
  /// 冪等にする（F9）。完了は `start` のたびに再送されうるし、rename の後・
  /// forget の前に落ちると、次の起動でも同じ完了が届く。
  Future<void> _install(ArchiveTaskId task, int generation) async {
    final store = _host.store;
    if (store == null || _host.isStale(generation)) return;
    final volumeId = task.volumeId;
    final staging = store.stagingFile(
      volumeId: volumeId,
      filesVersion: task.filesVersion,
    );
    final archive = store.archiveFile(
      volumeId: volumeId,
      filesVersion: task.filesVersion,
    );

    var download = _host.ledger?[volumeId];
    if (download != null &&
        download.status == VolumeDownloadStatus.paused &&
        _memory.tasks[volumeId] == task) {
      // 中断した「今の転送」の完了 = 止める前に書き上がっていた（中断と
      // ネイティブの完了の競合。`pause` は止められなかった転送を取り消さずに
      // 残す）。捨てると数百 MB を先頭から落とし直すことになるので確定する。
      // 削除 / 別世代の積み直し / ログアウトなら今の転送から外れているので、
      // 下で取り込まずに捨てる。
      download = download.copyWith(status: VolumeDownloadStatus.queued);
      await _host.save(download);
      if (_host.isStale(generation)) return;
    } else if (download != null &&
        download.isCompleted &&
        download.filesVersion < task.filesVersion &&
        _memory.tasks[volumeId] == task) {
      // 中断した「更新あり」の取り直しが、止める前に書き上がっていた。取り直しの
      // 中断は台帳を旧世代（完了）へ戻している（`savePaused`）ので、上の
      // 「中断」の分岐には来ない。捨てると次の「更新あり」で数百 MB を先頭から
      // 落とし直すので確定する。検証に落ちたら旧世代へ戻せるよう覚えておく。
      _memory.installed[volumeId] = download;
      download = download.copyWith(status: VolumeDownloadStatus.queued);
      await _host.save(download);
      if (_host.isStale(generation)) return;
    }
    // 既に確定済み（完了の再送）。
    if (download != null &&
        download.isCompleted &&
        download.filesVersion == task.filesVersion &&
        archive.existsSync()) {
      if (_memory.tasks[volumeId] == task) _memory.clearTask(volumeId);
      await _cleanup.deleteStaging(task);
      await _cleanup.forgetQuietly(task);
      return;
    }
    // 削除 / 中断 / 別世代の積み直しと競合した完了。取り込まない
    // （消した巻を「ダウンロード済み」として復活させない）。
    if (download == null ||
        !download.isActive ||
        _memory.tasks[volumeId] != task) {
      if (_memory.tasks[volumeId] == task) _memory.clearTask(volumeId);
      await _cleanup.deleteStagingUnlessCurrent(task);
      await _cleanup.forgetQuietly(task);
      return;
    }

    var manifest = await store.readManifest(
      volumeId: volumeId,
      filesVersion: task.filesVersion,
    );
    if (manifest == null) {
      try {
        manifest = await _host.ref
            .read(volumesApiProvider)
            .fetchManifest(volumeId);
      } on Object catch (error) {
        if (_host.isStale(generation) || !_host.isCurrent(task)) return;
        // オフラインで確定できない。書き上がったデータは残し、回線が戻ったら
        // やり直す（数百 MB を落とし直させない）。
        debugPrint('[downloads] manifest for install failed: $error');
        _memory.awaitingInstall.add(volumeId);
        final current = _host.ledger?[volumeId];
        if (current != null && current.status != VolumeDownloadStatus.queued) {
          await _host.save(
            current.copyWith(status: VolumeDownloadStatus.queued),
          );
        }
        return;
      }
      if (_host.isStale(generation) || !_host.isCurrent(task)) return;
      if (manifest.filesVersion != task.filesVersion) {
        // 転送の間にサーバー側の ZIP が差し替わった。検証できないので取り直す。
        _memory.clearTask(volumeId);
        await _cleanup.deleteStaging(task);
        await _cleanup.forgetQuietly(task);
        if (!_host.isStale(generation)) _host.scheduleSubmit(volumeId);
        return;
      }
    }
    if (_host.isStale(generation) || !_host.isCurrent(task)) return;

    // rename の後・確定の前に落ちた（書きかけは既に本番のファイル名になって
    // いる）。検証済みのものしか rename しないので、そのまま確定し直す。
    if (!staging.existsSync() &&
        archive.existsSync() &&
        (manifest.archiveBytes == 0 ||
            archive.lengthSync() == manifest.archiveBytes)) {
      await finish(volumeId, manifest, generation: generation);
      if (_memory.tasks[volumeId] == task) _memory.clearTask(volumeId);
      _memory.attempts.reset(volumeId);
      await _cleanup.forgetQuietly(task);
      return;
    }

    final failure = await _verify(manifest, staging);
    if (_host.isStale(generation) || !_host.isCurrent(task)) return;
    if (failure != null) {
      // 転送中に ZIP が差し替わった（files_version が変わった）なら、壊れた
      // のではないので自動で取り直す。同じなら本当に壊れているので止める
      // （自動で取り直し続けると自宅サーバーを叩き続ける）。
      VolumeManifest? latest;
      try {
        latest = await _host.ref
            .read(volumesApiProvider)
            .fetchManifest(volumeId);
      } on Object {
        latest = null;
      }
      if (_host.isStale(generation) || !_host.isCurrent(task)) return;
      _memory.clearTask(volumeId);
      await TransferCleanup.deleteQuietly(staging);
      await _cleanup.forgetQuietly(task);
      if (latest != null && latest.filesVersion != task.filesVersion) {
        if (!_host.isStale(generation)) _host.scheduleSubmit(volumeId);
        return;
      }
      _memory.persistThrottle.restart(volumeId);
      await _host.fail(
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
      final current = _host.isCurrent(task);
      if (_memory.tasks[volumeId] == task) _memory.clearTask(volumeId);
      await TransferCleanup.deleteQuietly(staging);
      await _cleanup.forgetQuietly(task);
      if (!current) return;
      await _host.fail(
        volumeId,
        fileSystemFailureMessage(error),
        generation: generation,
      );
      return;
    }

    await finish(volumeId, manifest, generation: generation);
    if (_memory.tasks[volumeId] == task) _memory.clearTask(volumeId);
    _memory.attempts.reset(volumeId);
    await _cleanup.forgetQuietly(task);
    _cleanup.scheduleTempSweep();
  }

  /// ZIP が本番のファイル名で手元にある巻を確定する。
  ///
  /// 投入の時点で同じ世代が既に手元にあった（取り直しの空振り / rename 済みで
  /// 確定前に落ちた）ときも、調停役からここを呼ぶ。
  Future<void> finish(
    int volumeId,
    VolumeManifest manifest, {
    required int generation,
  }) async {
    final store = _host.store;
    if (store == null || _host.isStale(generation)) return;
    // マニフェストは早期完了の経路でも必ず書く。rename 済み・マニフェスト未保存
    // で落ちた巻をそのまま「ダウンロード済み」に確定させると、{v}.json が無い
    // まま固定されて #11 のページ解決が恒久的にできなくなる。
    try {
      await store.writeManifest(manifest);
    } on FileSystemException catch (error) {
      if (!(_host.ledger?.containsKey(volumeId) ?? false)) {
        // 削除と競合した（ディレクトリが先に消えた）。失敗として書き戻さない。
        if (!_host.isStale(generation)) await store.deleteFiles(volumeId);
        return;
      }
      await _host.fail(
        volumeId,
        fileSystemFailureMessage(error),
        generation: generation,
      );
      return;
    }
    await store.deleteOtherVersions(
      volumeId: volumeId,
      keepFilesVersion: manifest.filesVersion,
    );

    final download = _host.ledger?[volumeId];
    if (download == null) {
      // 確定の途中で削除された。削除の後片付け（ディレクトリごと消す）が
      // rename / マニフェストの書き込みと競合して残ったものを消す
      // （台帳に無い実体を端末に残さない）。
      if (!_host.isStale(generation)) await store.deleteFiles(volumeId);
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
      pages = await _host.ref.read(archiveVerifierProvider)(staging);
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

  Future<void> _complete(
    VolumeDownload download,
    VolumeManifest manifest, {
    required int generation,
  }) async {
    if (_host.isStale(generation)) return;
    // 取り消し（`remove`）と競合した確定を書き戻さない。実体を消した後に
    // completed の行だけ復活すると、読めない「ダウンロード済み」が UI に出る。
    if (!(_host.ledger?.containsKey(download.volumeId) ?? false)) return;
    _memory.persistThrottle.forget(download.volumeId);
    _memory.installed.remove(download.volumeId);
    await _host.save(
      download.copyWith(
        status: VolumeDownloadStatus.completed,
        filesVersion: manifest.filesVersion,
        pageCount: manifest.pageCount,
        archiveEtag: manifest.archiveEtag,
        clearFailureReason: true,
        // この世代の確定時刻。自動削除は、これより前の読了の記録（前回の
        // ダウンロードや前のセッションのもの）で落とし直した巻を消さない。
        completedAt: _host.store?.now() ?? DateTime.now(),
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
    if (!_host.mounted) return;
    final warm = _host.ref.read(offlineDetailWarmerProvider);
    unawaited(warm(bookId).catchError((Object _) {}));
  }
}
