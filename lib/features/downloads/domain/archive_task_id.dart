import 'package:flutter/foundation.dart' show immutable;

/// OS の転送タスクの ID（`v{volumeId}.f{filesVersion}.s{sessionTag}`）。
///
/// タスクはアプリが死んでいる間も OS 側に残り、次の起動で完了やエラーが
/// 届く。そのとき「どの巻の・どの世代の・どのログインセッションの転送か」を
/// ID だけで判別できるようにする。セッションタグはログアウトのたびに
/// 作り直すので、前のユーザーの転送の完了が後から届いても取り込まない（#15）。
@immutable
class ArchiveTaskId {
  const ArchiveTaskId({
    required this.volumeId,
    required this.filesVersion,
    required this.sessionTag,
  });

  final int volumeId;
  final int filesVersion;
  final String sessionTag;

  static final _pattern = RegExp(r'^v(\d+)\.f(\d+)\.s([A-Za-z0-9]+)$');

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
    );
  }

  @override
  String toString() => 'v$volumeId.f$filesVersion.s$sessionTag';

  @override
  bool operator ==(Object other) =>
      other is ArchiveTaskId &&
      other.volumeId == volumeId &&
      other.filesVersion == filesVersion &&
      other.sessionTag == sessionTag;

  @override
  int get hashCode => Object.hash(volumeId, filesVersion, sessionTag);
}
