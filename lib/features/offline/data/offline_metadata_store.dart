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

/// 保存しておいたメタ情報 1 件の、payload を除いた部分。
class OfflineMetadataHeader {
  const OfflineMetadataHeader({required this.fetchedAt, this.etag});

  final DateTime fetchedAt;

  final String? etag;
}

/// 保存しておいたメタ情報 1 件（payload は JSON 文字列のまま）。
///
/// 一覧のように数 MB になる payload は、呼び出し側で別の isolate に渡して
/// decode するため（#26）。
class OfflineMetadataRaw extends OfflineMetadataHeader {
  const OfflineMetadataRaw({
    required this.payload,
    required super.fetchedAt,
    super.etag,
  });

  final String payload;
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

  /// payload を decode せずに読む（行が無ければ `null`）。
  ///
  /// 中身の検証は呼び出し側の責任（壊れていたら [delete] する）。
  Future<OfflineMetadataRaw?> readRaw(String key) async {
    final row = await (database.select(
      database.offlineMetadataEntries,
    )..where((table) => table.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    return OfflineMetadataRaw(
      payload: row.payload,
      fetchedAt: row.fetchedAt,
      etag: row.etag,
    );
  }

  /// ETag と取得時刻だけを読む（payload は DB から取り出しもしない）。
  ///
  /// 一覧の `If-None-Match` を組むためだけに数 MB の payload を UI isolate へ
  /// 運ばないため（#26）。
  Future<OfflineMetadataHeader?> readHeader(String key) async {
    final table = database.offlineMetadataEntries;
    final row =
        await (database.selectOnly(table)
              ..addColumns([table.etag, table.fetchedAt])
              ..where(table.key.equals(key)))
            .getSingleOrNull();
    if (row == null) return null;
    final fetchedAt = row.read(table.fetchedAt);
    if (fetchedAt == null) return null;
    return OfflineMetadataHeader(
      fetchedAt: fetchedAt,
      etag: row.read(table.etag),
    );
  }

  Future<void> write(
    String key, {
    required Map<String, dynamic> payload,
    String? etag,
    DateTime? fetchedAt,
  }) => writeRaw(
    key,
    payload: jsonEncode(payload),
    etag: etag,
    fetchedAt: fetchedAt,
  );

  /// encode 済みの JSON をそのまま書く（encode を別の isolate で済ませた場合）。
  Future<void> writeRaw(
    String key, {
    required String payload,
    String? etag,
    DateTime? fetchedAt,
  }) async {
    await database
        .into(database.offlineMetadataEntries)
        .insertOnConflictUpdate(
          OfflineMetadataRow(
            key: key,
            payload: payload,
            etag: etag,
            fetchedAt: fetchedAt ?? now(),
          ),
        );
  }

  /// ETag だけを書き換える（行が無ければ何もしない）。
  ///
  /// 304 で ETag だけが変わったときに payload を書き直さないため（#26）。
  Future<void> updateEtag(String key, String? etag) async {
    await (database.update(database.offlineMetadataEntries)
          ..where((table) => table.key.equals(key)))
        .write(OfflineMetadataEntriesCompanion(etag: Value(etag)));
  }

  /// [source] の行を [entries] に移す（1 つのトランザクションで）。
  ///
  /// - [source] がもう無ければ何もしない（`false`）。移し替えの準備中に
  ///   ログアウトの破棄が走ったとき、前のユーザーの控えを書き戻さないため。
  /// - [entries] のうち既に行があるキーは上書きしない（そちらが新しい）。
  /// - 書き終えてから [source] を消す。途中で落ちても全部が巻き戻るので、
  ///   新しい行の片方だけ書かれて旧形式が消える、ということが起きない。
  Future<bool> moveEntry(
    String source,
    Map<String, OfflineMetadataRaw> entries,
  ) => database.transaction(() async {
    final table = database.offlineMetadataEntries;
    final keys = [source, ...entries.keys];
    final existing = {
      for (final row
          in await (database.selectOnly(table)
                ..addColumns([table.key])
                ..where(table.key.isIn(keys)))
              .get())
        ?row.read(table.key),
    };
    if (!existing.contains(source)) return false;
    for (final MapEntry(:key, :value) in entries.entries) {
      if (existing.contains(key)) continue;
      await writeRaw(
        key,
        payload: value.payload,
        etag: value.etag,
        fetchedAt: value.fetchedAt,
      );
    }
    await delete([source]);
    return true;
  });

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
