import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'archive_transport.dart';

/// パッケージが作る一時ファイルの名前の先頭。
///
/// Android で `useCacheDir: never` にすると、一時ファイルは application
/// support の直下に `com.bbflight.background_downloader<乱数>` の名前で
/// 作られる。完了すると目的のファイル名へ移るが、失敗・取り消しでは
/// 残ることがある（パッケージの CONFIG.md が掃除をアプリに求めている）。
const transferTempFilePrefix = 'com.bbflight.background_downloader';

/// 転送が走っている間に消してよい一時ファイルの古さ（最後に書き込まれてから）。
///
/// 走行中の転送は書きかけを受信のたびに書き足すので、更新時刻は常に新しい。
/// パッケージの読み取りのタイムアウト（Android の既定 60 秒）より長く
/// 何も書かれていなければ、その転送はもう失敗して終わっている。余裕を
/// 見て 2 分にする。一時停止中 / 再試行待ちで続きに使う書きかけは、
/// 古くても再開データが指しているので残す（`keepPaths`）。
const transferTempStaleAge = Duration(minutes: 2);

/// [directories] の直下にあるパッケージの一時ファイルを消す。
///
/// [keepPaths] に入っているもの（一時停止中の転送の再開データが指す書きかけ）は
/// 残す。[olderThan] を渡すと、それより最近に書き込まれたものも残す
/// （[now] はテスト用）。消したファイルの数を返す。
///
/// 通信の失敗で終わった転送は、パッケージが再開データを捨てる一方で
/// Android の一時ファイル（巻 1 冊ぶん、数百 MB）を残す。何も指さなくなった
/// それを消さないと、失敗のたびに端末の容量が減っていく。
///
/// **走っている転送があるときは [olderThan] を渡す**こと。走行中の書きかけも
/// 同じ名前で、消すと完了時の移動が失敗する（呼び出し側が確かめる）。
Future<int> deleteTransferTempFiles(
  Iterable<Directory> directories, {
  Set<String> keepPaths = const {},
  Duration? olderThan,
  DateTime? now,
}) async {
  final keep = {for (final path in keepPaths) p.normalize(path)};
  final cutoff = olderThan == null
      ? null
      : (now ?? DateTime.now()).subtract(olderThan);
  var deleted = 0;
  for (final directory in directories) {
    if (!directory.existsSync()) continue;
    final List<FileSystemEntity> entries;
    try {
      entries = directory.listSync(followLinks: false);
    } on FileSystemException catch (error) {
      debugPrint('[transfer] temp dir list failed: $error');
      continue;
    }
    for (final entity in entries) {
      if (entity is! File) continue;
      if (!p.basename(entity.path).startsWith(transferTempFilePrefix)) continue;
      if (keep.contains(p.normalize(entity.path))) continue;
      try {
        if (cutoff != null && entity.lastModifiedSync().isAfter(cutoff)) {
          continue;
        }
        await entity.delete();
        deleted++;
      } on FileSystemException catch (error) {
        debugPrint('[transfer] temp file delete failed: $error');
      }
    }
  }
  return deleted;
}

/// 一時ファイルの掃除をどこまでするか。
enum TempSweepScope {
  /// 消さない（続きに使う書きかけを Dart から見分けられない）。
  none,

  /// しばらく書き込まれていないもの（[transferTempStaleAge]）だけを消す。
  stale,

  /// どの転送も指していないものをすべて消す。
  all,
}

/// ネイティブの転送の一覧（[snapshots]）から、掃除の範囲を決める。
///
/// 年齢で消してよいのは、生きている転送が**すべて走っている**ときだけ。
/// 走っている転送は受信のたびに自分の書きかけを書き足すので、古いものは
/// 自分のものではない。待機中（enqueued / 再試行待ち）の転送が 1 本でも
/// あれば消さない。Android の時間切れ（`BDPlugin.doEnqueue` へ直接渡す）や
/// Wi-Fi 設定の変更（`localResumeData`）で再投入された転送は、再開データを
/// ネイティブ側にしか持たず Dart の保存領域に載らない（`keepPaths` に
/// 入らない）。Wi-Fi を待つ間は書きかけが書き足されずに古くなるので、
/// 年齢で消すと、走り出したときに続きを取れず先頭から落とし直しになる
/// （巻 1 冊ぶん、数百 MB）。置き去りの書きかけは、待機中の転送が無く
/// なった後の掃除（失敗 / 完了 / 次の起動）で消える。
///
/// 一時停止中の転送は数えない（再開データが Dart にあり `keepPaths` で残す）。
/// [staleOnly] は呼び出し側の判断（投入済みで未確定の巻がある）で、
/// ネイティブが何も知らなくても年齢で絞る。
TempSweepScope tempSweepScopeFor(
  Iterable<TransferSnapshot> snapshots, {
  required bool staleOnly,
}) {
  final alive = [
    for (final snapshot in snapshots)
      if (snapshot.state == TransferState.enqueued ||
          snapshot.state == TransferState.running ||
          snapshot.state == TransferState.waitingToRetry)
        snapshot.state,
  ];
  if (alive.any((state) => state != TransferState.running)) {
    return TempSweepScope.none;
  }
  if (staleOnly || alive.isNotEmpty) return TempSweepScope.stale;
  return TempSweepScope.all;
}
