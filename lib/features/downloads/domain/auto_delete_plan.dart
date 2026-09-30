import 'package:flutter/foundation.dart' show immutable;

import '../../progress/domain/reading_progress.dart';
import 'volume_download.dart';

/// 読了した巻を自動で削除するまでの期間。
enum FinishedRetention {
  off(null, 'オフ'),
  days7(Duration(days: 7), '7 日後'),
  days14(Duration(days: 14), '14 日後'),
  days30(Duration(days: 30), '30 日後'),
  days90(Duration(days: 90), '90 日後');

  const FinishedRetention(this.duration, this.label);

  /// `null` はオフ。
  final Duration? duration;
  final String label;
}

/// 空き容量がこれを下回ったら古い巻から削除する。
enum LowSpaceThreshold {
  off(null, 'オフ'),
  gb1(1 << 30, '1 GB 未満'),
  gb2(2 << 30, '2 GB 未満'),
  gb5(5 << 30, '5 GB 未満');

  const LowSpaceThreshold(this.bytes, this.label);

  /// `null` はオフ。
  final int? bytes;
  final String label;
}

/// ダウンロード済みの巻の自動削除の設定（#13）。**既定はすべてオフ**。
///
/// 明示的に落とした数百 MB の巻を、ユーザーが選ばないうちに消さない。
@immutable
class AutoDeleteSettings {
  const AutoDeleteSettings({
    this.finished = FinishedRetention.off,
    this.lowSpace = LowSpaceThreshold.off,
  });

  final FinishedRetention finished;
  final LowSpaceThreshold lowSpace;

  /// どれか 1 つでも有効か（すべてオフなら台帳も控えも読まない）。
  bool get isEnabled =>
      finished != FinishedRetention.off || lowSpace != LowSpaceThreshold.off;

  AutoDeleteSettings copyWith({
    FinishedRetention? finished,
    LowSpaceThreshold? lowSpace,
  }) => AutoDeleteSettings(
    finished: finished ?? this.finished,
    lowSpace: lowSpace ?? this.lowSpace,
  );

  @override
  bool operator ==(Object other) =>
      other is AutoDeleteSettings &&
      other.finished == finished &&
      other.lowSpace == lowSpace;

  @override
  int get hashCode => Object.hash(finished, lowSpace);

  @override
  String toString() => 'AutoDeleteSettings(${finished.name}, ${lowSpace.name})';
}

/// 自動削除 1 回分の結果（設定画面の「前回の自動削除」）。
@immutable
class AutoDeleteResult {
  const AutoDeleteResult({
    required this.at,
    required this.volumes,
    required this.bytes,
  });

  final DateTime at;
  final int volumes;
  final int bytes;

  @override
  bool operator ==(Object other) =>
      other is AutoDeleteResult &&
      other.at == at &&
      other.volumes == volumes &&
      other.bytes == bytes;

  @override
  int get hashCode => Object.hash(at, volumes, bytes);

  @override
  String toString() => 'AutoDeleteResult($at, $volumes vols, $bytes B)';
}

/// 自動削除の判断材料（すべて呼び出し側が集めて渡す。ここは I/O をしない）。
@immutable
class AutoDeleteInputs {
  const AutoDeleteInputs({
    required this.ledger,
    required this.now,
    this.progress = const {},
    this.finishedOnServer = const {},
    this.finishedSeen = const {},
    this.openVolumeIds = const {},
    this.freeBytes,
  });

  /// ダウンロードの台帳。
  final Map<int, VolumeDownload> ledger;

  /// この端末の読書進捗（#12。ページ送りのたびに書かれ、送信後も残る）。
  final Map<int, ReadingProgress> progress;

  /// 控え（`BookDetail.volumes[].userStatus`）で読了になっている巻。
  /// 他端末で読み終えた巻もここで分かる。
  final Set<int> finishedOnServer;

  /// 他端末で読了した巻に、この端末が初めて気づいた時刻。
  final Map<int, DateTime> finishedSeen;

  /// ビューアで開いている巻。
  final Set<int> openVolumeIds;

  final DateTime now;

  /// 端末の空き容量（`null` = 分からない）。
  final int? freeBytes;
}

/// 自動削除の計画。
@immutable
class AutoDeletePlan {
  const AutoDeletePlan({
    this.finished = const [],
    this.lowSpace = const [],
    this.finishedSeen = const {},
  });

  /// 読了ポリシーで消す巻（基準時刻の古い順）。
  final List<int> finished;

  /// 空き容量ポリシーで消す巻（消す順番どおり）。[finished] とは重ならない。
  final List<int> lowSpace;

  /// 保存し直す「初めて気づいた時刻」（新規は `now`。台帳に無い巻と、今の
  /// 世代を確定する前の記録は削る）。
  final Map<int, DateTime> finishedSeen;

  /// 消す巻すべて（[finished] → [lowSpace] の順）。
  List<int> get all => [...finished, ...lowSpace];

  /// 消す巻の容量の合計（台帳の `totalBytes` で見積もる）。
  int bytesOf(Map<int, VolumeDownload> ledger) =>
      all.fold(0, (sum, volumeId) => sum + (ledger[volumeId]?.totalBytes ?? 0));
}

/// 巻 1 つ分の読書の様子。
///
/// [openedHere] は「今の世代を落としてから、この端末で開いたか」。
typedef _Reading = ({
  int volumeId,
  bool finished,
  bool openedHere,
  DateTime? touchedAt,
});

/// 自動削除する巻を決める（純粋関数）。
///
/// 削除候補にしない巻（両ポリシー共通）:
/// - completed 以外（取得中・待機・中断・失敗）。「更新あり」の取り直し中の
///   旧世代も含む。台帳の確定と競うと、読める ZIP と台帳が食い違う。
/// - ビューアで開いている巻。読んでいる最中に消さない。
///
/// 読了したかは、この端末の進捗（最後のページまで進んだ）か、控えの読了フラグ
/// （他端末で読了。サーバーの `is_finished` は一度立つと戻らない）で判断する。
/// 「最後に触った時刻」はこの端末の進捗の `readAt`。無ければ（他端末で読了し、
/// この端末では開いていない）初めて気づいた時刻を使い、**気づいた回は消さない**。
///
/// どちらの時刻も、台帳の `completedAt`（今の世代を確定した時刻）より前には
/// しない。進捗の行は送信後も残り（#12）、気づいた時刻もログアウトや削除を
/// 跨いで残りうるので、そのまま使うと**前回のダウンロード**の記録で、読み返す
/// ために落とし直した巻を開く前に消してしまう。
AutoDeletePlan planAutoDelete(
  AutoDeleteSettings settings,
  AutoDeleteInputs inputs,
) {
  final now = inputs.now;
  final ledger = inputs.ledger;

  // 台帳に無い巻の記録は捨てる（ログアウト後に前のユーザーの記録を持ち越さない）。
  final seen = <int, DateTime>{
    for (final MapEntry(:key, :value) in inputs.finishedSeen.entries)
      if (ledger.containsKey(key)) key: value,
  };

  final readings = <_Reading>[];
  for (final download in ledger.values) {
    final volumeId = download.volumeId;
    final completedAt = download.completedAt;
    final completed = download.status == VolumeDownloadStatus.completed;

    // 今の世代を確定する前に気づいた記録は、前回のダウンロード（消して
    // 落とし直した / 前のセッション）のもの。今の巻については気づき直す。
    if (seen[volumeId] case final stamped?
        when completedAt != null && stamped.isBefore(completedAt)) {
      seen.remove(volumeId);
    }

    final local = inputs.progress[volumeId];
    final finishedHere =
        local != null &&
        local.maxPage > 0 &&
        local.currentPage >= local.maxPage;
    final finished = finishedHere || inputs.finishedOnServer.contains(volumeId);

    DateTime? touchedAt;
    if (local != null) {
      // 読み返し中（手元は途中・サーバーは読了）も最後に開いた時刻から数える。
      touchedAt = local.readAt;
    } else if (finished) {
      touchedAt = seen[volumeId];
      // 初めて気づいた回は時刻を残すだけにする。ダウンロードした直後に
      // 「他端末で読了済み」を理由に消すと、読み返すために落とした巻が消える。
      // 落とし終わる前（待機中・中断中）には付けない。長く待たされた巻が、
      // 完了した瞬間に期限切れになる。
      if (touchedAt == null && completed) seen[volumeId] = now;
    }
    // 開いたのが今の世代を落とす前なら、落とした時刻から数える。
    final openedHere =
        local != null &&
        (completedAt == null || !local.readAt.isBefore(completedAt));
    if (touchedAt != null &&
        completedAt != null &&
        touchedAt.isBefore(completedAt)) {
      touchedAt = completedAt;
    }

    if (!completed) continue;
    if (inputs.openVolumeIds.contains(volumeId)) continue;
    readings.add((
      volumeId: volumeId,
      finished: finished,
      openedHere: openedHere,
      touchedAt: touchedAt,
    ));
  }

  int byTouched(_Reading a, _Reading b) {
    final at = a.touchedAt ?? now;
    final bt = b.touchedAt ?? now;
    final order = at.compareTo(bt);
    return order != 0 ? order : a.volumeId.compareTo(b.volumeId);
  }

  final finished = <int>[];
  if (settings.finished.duration case final retention?) {
    final expired =
        readings
            .where(
              (r) =>
                  r.finished &&
                  r.touchedAt != null &&
                  !r.touchedAt!.add(retention).isAfter(now),
            )
            .toList()
          ..sort(byTouched);
    finished.addAll(expired.map((r) => r.volumeId));
  }

  final lowSpace = <int>[];
  final threshold = settings.lowSpace.bytes;
  final free = inputs.freeBytes;
  // 空き容量が分からないときは動かさない（誤った値で消し始めない）。
  if (threshold != null && free != null) {
    // 読了ポリシーで消える分は先に空くものとして数える（二重に消さない）。
    var expected = free;
    for (final volumeId in finished) {
      expected += ledger[volumeId]?.totalBytes ?? 0;
    }
    if (expected < threshold) {
      final taken = finished.toSet();
      // 読了 → 読みかけの順に、最後に触ったのが古いものから。
      // 落としてからこの端末で一度も開いていない巻は対象にしない。他端末で
      // 読み終えた巻も含む（読み返すために落とした「これから読む巻」を、
      // その落とした分で空きが減ったことを理由に黙って消さない）。
      final order = [
        ...readings.where((r) => r.finished && r.openedHere).toList()
          ..sort(byTouched),
        ...readings.where((r) => !r.finished && r.openedHere).toList()
          ..sort(byTouched),
      ];
      for (final reading in order) {
        if (expected >= threshold) break;
        if (taken.contains(reading.volumeId)) continue;
        lowSpace.add(reading.volumeId);
        expected += ledger[reading.volumeId]?.totalBytes ?? 0;
      }
    }
  }

  return AutoDeletePlan(
    finished: List.unmodifiable(finished),
    lowSpace: List.unmodifiable(lowSpace),
    finishedSeen: Map.unmodifiable(seen),
  );
}
