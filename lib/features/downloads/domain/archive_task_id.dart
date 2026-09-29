import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

/// OS の転送タスクの ID（`v{volumeId}.f{filesVersion}.s{sessionTag}.n{nonce}`）。
///
/// タスクはアプリが死んでいる間も OS 側に残り、次の起動で完了やエラーが
/// 届く。そのとき「どの巻の・どの世代の・どのログインセッションの転送か」を
/// ID だけで判別できるようにする。セッションタグはログアウトのたびに
/// 作り直すので、前のユーザーの転送の完了が後から届いても取り込まない（#15）。
///
/// ノンスは**投入のたびに**作り直す（再開では同じ ID を使う。再開データは
/// ID で引くため）。Android のパッケージは一時停止の印（`pausedTaskIds`）を
/// ID ごとにプロセスが生きている間ずっと覚え、取り消しでも投入でも消さない。
/// 待機中に印を付けたまま削除した巻 / 止める直前に書き終えた巻を同じ ID で
/// 積み直すと、新しい転送が最初の受信で止まり、誰も再開しないまま動かなくなる。
@immutable
class ArchiveTaskId {
  const ArchiveTaskId({
    required this.volumeId,
    required this.filesVersion,
    required this.sessionTag,
    required this.nonce,
  });

  final int volumeId;
  final int filesVersion;
  final String sessionTag;

  /// 投入ごとに変わる値（英数字）。
  final String nonce;

  static final _pattern = RegExp(
    r'^v(\d+)\.f(\d+)\.s([A-Za-z0-9]+)\.n([A-Za-z0-9]+)$',
  );

  static final _random = math.Random.secure();

  /// 新しい投入のためのノンス。
  ///
  /// 連番にしないのは、Dart 側（Flutter エンジン）だけが作り直されても
  /// ネイティブのプロセスと印は生き残るため（連番は 0 からやり直して重なる）。
  static String newNonce() =>
      [for (var i = 0; i < 10; i++) _random.nextInt(36).toRadixString(36)]
          .join();

  /// 他の用途の ID・壊れた ID は `null`。
  static ArchiveTaskId? tryParse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) return null;
    final volumeId = int.tryParse(match.group(1)!);
    final filesVersion = int.tryParse(match.group(2)!);
    if (volumeId == null || filesVersion == null) return null;
    return ArchiveTaskId(
      volumeId: volumeId,
      filesVersion: filesVersion,
      sessionTag: match.group(3)!,
      nonce: match.group(4)!,
    );
  }

  @override
  String toString() => 'v$volumeId.f$filesVersion.s$sessionTag.n$nonce';

  @override
  bool operator ==(Object other) =>
      other is ArchiveTaskId &&
      other.volumeId == volumeId &&
      other.filesVersion == filesVersion &&
      other.sessionTag == sessionTag &&
      other.nonce == nonce;

  @override
  int get hashCode => Object.hash(volumeId, filesVersion, sessionTag, nonce);
}
