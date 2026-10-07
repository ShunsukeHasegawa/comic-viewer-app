import 'dart:math' as math;

import '../domain/volume_download.dart';

// 転送の進捗の帳簿（DB へ書く間引きと、空き容量の予約）。
//
// DownloadQueue から切り出した（#29）。どちらも巻ごとの数字を覚えるだけで、
// 台帳や転送には触らない。

/// 進捗を DB へ書く間隔（バイト）。
///
/// 毎回書くと 1 巻で数千回の UPDATE になる。再開位置は OS の転送が持って
/// いるので、DB の値は表示の復元用で多少古くてよい。
const progressPersistIntervalBytes = 4 * 1024 * 1024;

/// 届いた進捗を台帳の行に反映する（`total` が分からなければ今の値のまま）。
VolumeDownload applyProgress(VolumeDownload current, int received, int? total) {
  final totalBytes = total != null && total > 0 ? total : current.totalBytes;
  return current.copyWith(
    status: VolumeDownloadStatus.downloading,
    receivedBytes: received,
    totalBytes: totalBytes,
  );
}

/// 進捗を DB へ書くかどうかを、最後に書いた受信バイト数から決める。
class ProgressPersistThrottle {
  final _persisted = <int, int>{};

  /// [received] を書くべきなら覚えて `true`。
  ///
  /// 前に書いた値から [progressPersistIntervalBytes] 以上動いたときだけ書く
  /// （巻き戻り = 先頭からの取り直しも同じ幅で拾う）。
  bool shouldPersist(int volumeId, int received) {
    final persisted = _persisted[volumeId] ?? 0;
    if ((received - persisted).abs() < progressPersistIntervalBytes) {
      return false;
    }
    _persisted[volumeId] = received;
    return true;
  }

  /// 先頭から取り直す（DB には 0 を書いた）。
  void restart(int volumeId) => _persisted[volumeId] = 0;

  void forget(int volumeId) => _persisted.remove(volumeId);

  void clear() => _persisted.clear();
}

/// OS に渡して未確定の巻の残りバイト数（空き容量の判定に含める。F7）。
///
/// 空き容量を 1 巻ずつ見ると、まとめて積んだ 30 巻がどれも「入る」と
/// 判定され、後半が転送の途中で容量不足になる。
class SpaceReservations {
  final _reserved = <int, int>{};

  /// 先頭から取る巻の全体を押さえる。
  void reserve(int volumeId, int bytes) => _reserved[volumeId] = bytes;

  /// 進んだ分を外し、残りだけを押さえる。
  void reserveRemaining(
    int volumeId, {
    required int total,
    required int received,
  }) {
    _reserved[volumeId] = math.max(0, total - received);
  }

  /// [volumeId] 以外で押さえている合計。
  ///
  /// 中断中（[isActive] が `false`）の巻は、再開されるか分からないので数えない。
  /// 数えると、止めた巻の残りのせいで入るはずの巻が「空き容量が足りません」に
  /// なる。9 分の時間切れなどの一時的な停止は台帳が待機中 / 取得中のままなので
  /// 引き続き数える。
  int reservedByOthers(int volumeId, {required bool Function(int) isActive}) =>
      _reserved.entries
          .where((entry) => entry.key != volumeId)
          .where((entry) => isActive(entry.key))
          .fold<int>(0, (sum, entry) => sum + entry.value);

  void release(int volumeId) => _reserved.remove(volumeId);

  void clear() => _reserved.clear();
}
