import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

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
