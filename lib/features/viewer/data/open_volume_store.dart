import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/session_data_purger.dart';
import '../../../core/storage/app_database.dart';

part 'open_volume_store.g.dart';

/// ビューアで開いている巻の控え。
///
/// 閉じれば消すので、起動時に残っていれば「読んでいる途中で OS にアプリごと
/// 終了させられた」ことになる。ホームで続きを読むか尋ねるのに使う。
/// ダイアログをすぐ出せるよう、タイトルと巻数も一緒に持つ（通信を待たない）。
class OpenVolume {
  const OpenVolume({
    required this.bookId,
    required this.volumeId,
    required this.title,
    required this.volume,
  });

  final int bookId;
  final int volumeId;
  final String title;

  /// 巻数。
  final int volume;

  Map<String, Object> toJson() => {
    'book_id': bookId,
    'volume_id': volumeId,
    'title': title,
    'volume': volume,
  };

  /// 読み解けなければ `null`（尋ねないだけで、読書には影響しない）。
  static OpenVolume? tryParse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return null;
      final bookId = json['book_id'];
      final volumeId = json['volume_id'];
      if (bookId is! int || volumeId is! int) return null;
      final title = json['title'];
      final volume = json['volume'];
      return OpenVolume(
        bookId: bookId,
        volumeId: volumeId,
        title: title is String ? title : '',
        volume: volume is int ? volume : 0,
      );
    } on FormatException {
      return null;
    }
  }
}

/// [OpenVolume] の置き場。
abstract interface class OpenVolumeStore {
  Future<OpenVolume?> read();

  Future<void> save(OpenVolume volume);

  /// 控えが [volumeId] のときだけ消す。
  ///
  /// 次の巻へ進むと、新しい巻の書き込みが古い巻の後始末より先に届きうる。
  /// 無条件に消すと、読んでいる最中の巻の控えまで消えてしまう。
  Future<void> clearIfVolume(int volumeId);

  Future<void> clear();
}

/// drift の Settings テーブルに置く実装。
class DriftOpenVolumeStore implements OpenVolumeStore {
  DriftOpenVolumeStore(this._database);

  static const key = 'viewer.open_volume';

  final AppDatabase _database;

  @override
  Future<OpenVolume?> read() async {
    final row = await (_database.select(
      _database.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row == null ? null : OpenVolume.tryParse(row.value);
  }

  @override
  Future<void> save(OpenVolume volume) => _database
      .into(_database.settings)
      .insertOnConflictUpdate(
        SettingRow(key: key, value: jsonEncode(volume.toJson())),
      );

  @override
  Future<void> clearIfVolume(int volumeId) => _database.transaction(() async {
    // 読んでから消すまでの間に別の巻が書き込まないよう、まとめて行う。
    final current = await read();
    if (current != null && current.volumeId != volumeId) return;
    await clear();
  });

  @override
  Future<void> clear() => (_database.delete(
    _database.settings,
  )..where((t) => t.key.equals(key))).go();
}

@Riverpod(keepAlive: true)
OpenVolumeStore openVolumeStore(Ref ref) =>
    DriftOpenVolumeStore(ref.watch(appDatabaseProvider));

/// ログアウトで控えを捨てる（次のユーザーに前のユーザーの本を尋ねない）。
///
/// 消えても「続きを読むか尋ねない」だけなので、`safe_mode` の変更でも捨てる
/// （見せてはいけなくなったタイトルを尋ねない）。
class OpenVolumePurger implements SessionDataPurger {
  const OpenVolumePurger(this._store);

  final OpenVolumeStore Function() _store;

  @override
  String get debugLabel => 'open volume';

  @override
  bool get purgesRefetchableOnly => true;

  @override
  Future<void> purgeSessionData() => _store().clear();
}

@Riverpod(keepAlive: true)
SessionDataPurger openVolumePurger(Ref ref) =>
    OpenVolumePurger(() => ref.read(openVolumeStoreProvider));
