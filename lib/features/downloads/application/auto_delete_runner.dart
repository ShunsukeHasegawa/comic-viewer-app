import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/device/app_resume_monitor.dart';
import '../../../domain/models/book_detail.dart';
import '../../offline/application/offline_metadata_gateway.dart';
import '../../progress/data/progress_store.dart';
import '../../viewer/application/viewer_controller.dart';
import '../data/free_space_probe.dart';
import '../domain/auto_delete_plan.dart';
import '../domain/volume_download.dart';
import 'auto_delete_settings.dart';
import 'download_queue.dart';

part 'auto_delete_runner.g.dart';

/// 巻がいまビューアで開かれているか。
typedef OpenVolumeCheck = bool Function(int volumeId);

/// ビューアの状態が生きている巻を「開いている」とみなす。
///
/// ビューアのコントローラは画面を離れると破棄されるので、存在していれば
/// 読んでいる最中（または閉じる途中）。その巻の ZIP を消すとページが
/// 真っ黒になる。
@Riverpod(keepAlive: true)
OpenVolumeCheck openVolumeCheck(Ref ref) =>
    (volumeId) => ref.exists(viewerControllerProvider(volumeId));

/// 自動削除の時計（テストから時刻を決められるようにする）。
typedef AutoDeleteClock = DateTime Function();

@Riverpod(keepAlive: true)
AutoDeleteClock autoDeleteClock(Ref ref) => DateTime.now;

/// 自動削除を走らせるきっかけ。
enum AutoDeleteTrigger {
  /// 起動時（台帳を読み終えてから 1 回）。
  appStart,

  /// 前面復帰（前回から [AutoDeleteRunner.resumeInterval] 以内なら走らない）。
  resumed,

  /// 設定を変えた直後（間引かない。結果は画面が SnackBar で知らせる）。
  settingsChanged,
}

/// ダウンロード済みの巻の自動削除（#13）。**自動削除はここだけが行う**。
///
/// state は直近の実行で消した結果（何も消していなければ前の値のまま）。
@Riverpod(keepAlive: true)
class AutoDeleteRunner extends _$AutoDeleteRunner {
  /// 前面復帰で走り直すまでの間隔。
  ///
  /// ポリシーは日単位なので 1 時間で十分。復帰のたびに全タイトルの控えを
  /// 読み直さない。
  static const resumeInterval = Duration(hours: 1);

  /// 走っている実行（1 本ずつにする。削除が重なると同じ巻を 2 回消しに行く）。
  Future<AutoDeleteResult?>? _running;

  /// 最後に走り始めた時刻（前面復帰の間引き用）。
  DateTime? _lastStartedAt;

  @override
  AutoDeleteResult? build() {
    // 監視は read（watch にすると作り直しで起動時の 1 回がまた走る）。
    final subscription = ref
        .read(appResumeMonitorProvider)
        .onResumed
        .listen((_) => _runQuietly(AutoDeleteTrigger.resumed));
    ref.onDispose(subscription.cancel);
    // build の中で state を触らないよう、起動時の 1 回は次のマイクロタスクへ。
    scheduleMicrotask(() => _runQuietly(AutoDeleteTrigger.appStart));
    return null;
  }

  /// 背景の実行。画面が無いので失敗はログに残すだけにする（次の契機でやり直す）。
  void _runQuietly(AutoDeleteTrigger trigger) {
    if (!ref.mounted) return;
    unawaited(
      run(trigger).then<void>(
        (_) {},
        onError: (Object error) =>
            debugPrint('[auto-delete] ${trigger.name} failed: $error'),
      ),
    );
  }

  /// 自動削除を 1 回走らせる。消した結果（何も消さなければ `null`）を返す。
  ///
  /// 設定や台帳が読めなければ例外を投げる（1 巻の削除の失敗は投げずに次へ進む）。
  Future<AutoDeleteResult?> run(AutoDeleteTrigger trigger) async {
    final now = ref.read(autoDeleteClockProvider)();
    if (trigger == AutoDeleteTrigger.resumed) {
      final last = _lastStartedAt;
      if (last != null && now.difference(last) < resumeInterval) return null;
    }

    final running = _running;
    if (running != null) {
      // 設定の変更は、走っている実行が古い設定を読んでいるかもしれないので、
      // 終わるのを待ってから新しい設定でもう一度走らせる。
      if (trigger != AutoDeleteTrigger.settingsChanged) return running;
      try {
        await running;
      } on Object {
        // 前の実行の失敗はその呼び出し元が扱う。
      }
      if (!ref.mounted) return null;
      return run(trigger);
    }

    _lastStartedAt = now;
    final execution = _execute();
    _running = execution;
    try {
      return await execution;
    } finally {
      if (identical(_running, execution)) _running = null;
    }
  }

  Future<AutoDeleteResult?> _execute() async {
    final settings = await ref.read(
      autoDeleteSettingsControllerProvider.future,
    );
    if (!ref.mounted || !settings.isEnabled) return null;

    // 台帳の読み込みと起動時の照合の開始を待つ（読み込み中に「台帳が空」と
    // 判断しない）。
    await ref.read(downloadQueueProvider.future);
    if (!ref.mounted) return null;
    // 照合が終わるまでは、OS 側に残った取り直しの転送（中断中）が分からない
    // （[DownloadQueue.hasPendingTransfer]）。照合で台帳も書き換わるので、
    // 終わってから読み直す。
    await ref.read(downloadQueueProvider.notifier).reconciled;
    if (!ref.mounted) return null;
    final ledger = ref.read(downloadQueueProvider).value ?? const {};

    final store = ref.read(autoDeleteSettingsStoreProvider);
    final gateway = ref.read(offlineMetadataGatewayProvider);
    final progress = await ref.read(progressStoreProvider).loadAll();
    if (!ref.mounted) return null;

    final finishedOnServer = <int>{};
    for (final bookId in ledgerBookIds(ledger)) {
      try {
        final detail = await gateway.readBookDetail(bookId);
        for (final volume in detail?.volumes ?? const <BookVolume>[]) {
          if (volume.isFinished) finishedOnServer.add(volume.id);
        }
      } on Object catch (error) {
        // 1 タイトルの控えが読めなくても、他のタイトルは判断できる。
        // 読了が分からない巻は消さない側（未読扱い）に倒れる。
        debugPrint('[auto-delete] read detail $bookId failed: $error');
      }
      if (!ref.mounted) return null;
    }

    final int? freeBytes;
    if (settings.lowSpace.bytes != null) {
      freeBytes = await ref.read(freeSpaceProbeProvider)();
      if (!ref.mounted) return null;
    } else {
      freeBytes = null;
    }

    final seen = await store.readFinishedSeen();
    if (!ref.mounted) return null;
    final isOpen = ref.read(openVolumeCheckProvider);
    final now = ref.read(autoDeleteClockProvider)();
    final plan = planAutoDelete(
      settings,
      AutoDeleteInputs(
        ledger: ledger,
        progress: progress,
        finishedOnServer: finishedOnServer,
        finishedSeen: seen,
        openVolumeIds: {
          for (final volumeId in ledger.keys)
            if (isOpen(volumeId)) volumeId,
        },
        now: now,
        freeBytes: freeBytes,
      ),
    );

    if (!mapEquals(plan.finishedSeen, seen)) {
      await store.writeFinishedSeen(plan.finishedSeen);
      if (!ref.mounted) return null;
    }

    final queue = ref.read(downloadQueueProvider.notifier);
    var volumes = 0;
    var bytes = 0;
    for (final volumeId in plan.all) {
      if (!ref.mounted) break;
      // 計画を立ててから消すまでの間に状態が変わっていないか確かめ直す
      // （取り直しが始まった / ビューアで開かれた巻は消さない）。
      final current = ref.read(downloadQueueProvider).value?[volumeId];
      if (current == null || current.status != VolumeDownloadStatus.completed) {
        continue;
      }
      if (isOpen(volumeId)) continue;
      // 「更新あり」の取り直しを中断した巻（台帳は旧世代の完了に戻っている）。
      // ユーザーは更新してまで持っておくつもりなので消さない。
      if (queue.hasPendingTransfer(volumeId)) continue;
      try {
        await queue.remove(volumeId);
        volumes++;
        bytes += current.totalBytes;
      } on Object catch (error) {
        // 次回の実行でやり直される。残りの巻は続けて消す。
        debugPrint('[auto-delete] remove $volumeId failed: $error');
      }
    }
    if (volumes == 0) return null;

    final result = AutoDeleteResult(at: now, volumes: volumes, bytes: bytes);
    try {
      await gateway.prune();
    } on Object catch (error) {
      // 控えの掃除は次の一覧の読み込みでもやり直される。
      debugPrint('[auto-delete] prune failed: $error');
    }
    try {
      // 消せた分だけ残す（設定画面が「前回の自動削除」として見せる = 黙って消さない）。
      await store.writeLastResult(result);
    } on Object catch (error) {
      debugPrint('[auto-delete] save result failed: $error');
    }
    if (ref.mounted) state = result;
    return result;
  }

  /// メモリ上の「前回の結果」を忘れる（記録を消した後に呼ぶ）。
  void forgetLastResult() => state = null;
}

/// 前回の自動削除（設定画面の表示用）。
///
/// このプロセスで消した結果があればそれを、無ければ保存してある記録を返す。
@riverpod
Future<AutoDeleteResult?> autoDeleteLastResult(Ref ref) async {
  final latest = ref.watch(autoDeleteRunnerProvider);
  if (latest != null) return latest;
  return ref.read(autoDeleteSettingsStoreProvider).readLastResult();
}

/// 自動削除の記録（気づいた時刻 + 前回の結果）を、保存分もメモリ上の分も消す。
typedef ClearAutoDeleteRecords = Future<void> Function();

@Riverpod(keepAlive: true)
ClearAutoDeleteRecords clearAutoDeleteRecords(Ref ref) => () async {
  await ref.read(autoDeleteSettingsStoreProvider).clearRecords();
  // 起動していない runner をここで作ると起動時の自動削除が走り出すので、
  // 生きているときだけ忘れさせる。
  if (ref.exists(autoDeleteRunnerProvider)) {
    ref.read(autoDeleteRunnerProvider.notifier).forgetLastResult();
  }
  // runner の state が元から null だと通知が起きず、表示が保存済みの記録を
  // 読んだままになる。
  ref.invalidate(autoDeleteLastResultProvider);
};
