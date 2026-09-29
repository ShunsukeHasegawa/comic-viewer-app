import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/app_database.dart';

part 'offline_metadata_store.g.dart';

/// 保存しておいたメタ情報 1 件。
class OfflineMetadata {
  const OfflineMetadata({
    required this.payload,
    required this.fetchedAt,
    this.etag,
  });

  /// モデルの `fromJson` に渡せる形。
  final Map<String, dynamic> payload;

  /// サーバーから取得した時刻（「いつの内容か」の表示に使う）。
  final DateTime fetchedAt;

  final String? etag;
}

/// オフライン再生のためのメタ情報置き場（#11）。
///
/// キーで JSON を出し入れするだけの薄い層にしてある。ここに型を持ち込まないのは、
/// 「読めない payload は無かったことにする」判断を [OfflineCatalog] 側に
/// 1 箇所でまとめたいため（API の形が変わっても起動を妨げない）。
class OfflineMetadataStore {
  OfflineMetadataStore({required this.database, this.now = DateTime.now});

  final AppDatabase database;

  /// 現在時刻（テストから決められるようにする）。
  final DateTime Function() now;

  /// 読む。行が無い / JSON が壊れているときは `null`。
  Future<OfflineMetadata?> read(String key) async {
    final row = await (database.select(
      database.offlineMetadataEntries,
    )..where((table) => table.key.equals(key))).getSingleOrNull();
    if (row == null) return null;

    final Object? decoded;
    try {
      decoded = jsonDecode(row.payload);
    } on FormatException {
      // 壊れた行は捨てる（次にオンラインになったときに書き直される）。
      await delete([key]);
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      await delete([key]);
      return null;
    }
    return OfflineMetadata(
      payload: decoded,
      fetchedAt: row.fetchedAt,
      etag: row.etag,
    );
  }

  Future<void> write(
    String key, {
    required Map<String, dynamic> payload,
    String? etag,
    DateTime? fetchedAt,
  }) async {
    await database
        .into(database.offlineMetadataEntries)
        .insertOnConflictUpdate(
          OfflineMetadataRow(
            key: key,
            payload: jsonEncode(payload),
            etag: etag,
            fetchedAt: fetchedAt ?? now(),
          ),
        );
  }

  Future<void> delete(Iterable<String> keys) async {
    final list = keys.toList();
    if (list.isEmpty) return;
    await (database.delete(
      database.offlineMetadataEntries,
    )..where((table) => table.key.isIn(list))).go();
  }

  /// [prefix] で始まるキーの一覧（掃除の対象を選ぶのに使う）。
  Future<List<String>> keysWithPrefix(String prefix) async {
    final key = database.offlineMetadataEntries.key;
    final rows =
        await (database.selectOnly(database.offlineMetadataEntries)
              ..addColumns([key])
              ..where(key.like('$prefix%')))
            .get();
    return [for (final row in rows) ?row.read(key)];
  }

  Future<void> deleteAll() async {
    await database.delete(database.offlineMetadataEntries).go();
  }
}

@Riverpod(keepAlive: true)
OfflineMetadataStore offlineMetadataStore(Ref ref) =>
    OfflineMetadataStore(database: ref.watch(appDatabaseProvider));
