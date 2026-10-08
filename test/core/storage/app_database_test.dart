import 'dart:io';

import 'package:comic_laz/core/cache/image_cache_store.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _cacheIndexName = 'cached_images_kind_last_used_at_key';

void main() {
  group('一時キャッシュの索引', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() => database.close());

    // 索引の宣言だけでは、WHERE と ORDER BY の形が変わったときに一時ソートへ
    // 戻っても気づけない。実際の SQLite の計画で LRU 走査を固定する。
    test('種別ごとのLRU走査で複合索引を使う', () async {
      final query = ImageCacheStore.evictionCandidatesQuery(
        database,
        kind: CachedImageKind.page,
      );
      final plan = await _queryPlan(database, query.constructQuery());

      expect(plan, contains('USING INDEX $_cacheIndexName'));
      expect(plan, isNot(contains('USE TEMP B-TREE FOR ORDER BY')));
    });

    // 期限だけで全種別を走査すると複合索引の先頭列を使えないため、実装と同じく
    // 種別を指定した計画が索引の範囲走査になることを確かめる。
    test('種別ごとの期限切れ走査で複合索引を使う', () async {
      final query = ImageCacheStore.evictionCandidatesQuery(
        database,
        kind: CachedImageKind.thumbnail,
        olderThan: DateTime.utc(2026, 10, 8),
      );
      final plan = await _queryPlan(database, query.constructQuery());

      expect(plan, contains('USING INDEX $_cacheIndexName'));
      expect(plan, isNot(contains('USE TEMP B-TREE FOR ORDER BY')));
    });
  });

  // 索引追加のために表を作り直すと、端末にしかないダウンロード台帳や未送信の
  // 進捗まで失いうる。v4 相当のDBを開き直し、行を保ったまま移行する。
  test('v4からの移行は既存データを残してキャッシュ索引だけを追加する', () async {
    final root = Directory.systemTemp.createTempSync('comic_laz_migration');
    final file = File(p.join(root.path, 'comic_laz.sqlite'));
    final now = DateTime.utc(2026, 10, 8, 12);

    var database = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await database.close();
      try {
        if (root.existsSync()) root.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows が SQLite のハンドルを解放するまで遅れる場合は OS の掃除に任せる。
      }
    });

    await database.batch((batch) {
      batch.insert(
        database.cachedImages,
        CachedImageRow(
          key: 'v1/100/1',
          kind: CachedImageKind.page,
          fileName: 'cache-file',
          bytes: 123,
          createdAt: now,
          lastUsedAt: now,
        ),
      );
      batch.insert(
        database.downloadedVolumes,
        DownloadedVolumeRow(
          volumeId: 1,
          bookId: 2,
          filesVersion: 100,
          status: VolumeDownloadStatus.completed,
          receivedBytes: 456,
          totalBytes: 456,
          pageCount: 10,
          updatedAt: now,
          completedAt: now,
        ),
      );
      batch.insert(
        database.readingProgresses,
        ReadingProgressRow(
          volumeId: 1,
          currentPage: 3,
          maxPage: 10,
          readAt: now,
          synced: false,
        ),
      );
      batch.insert(
        database.offlineMetadataEntries,
        OfflineMetadataRow(key: 'books', payload: '[]', fetchedAt: now),
      );
      batch.insert(
        database.pinnedImages,
        const PinnedImageRow(key: 'v1/100/1', bookId: 2),
      );
      batch.insert(
        database.settings,
        const SettingRow(key: 'cache.custom', value: 'keep'),
      );
    });
    await database.customStatement('DROP INDEX $_cacheIndexName');
    await (database.delete(
      database.settings,
    )..where((table) => table.key.equals(AppDatabase.freshInstallKey))).go();
    await database.customStatement('PRAGMA user_version = 4');
    await database.close();

    database = AppDatabase(NativeDatabase(file));

    expect(
      (await database.select(database.cachedImages).getSingle()).bytes,
      123,
    );
    expect(
      (await database.select(database.downloadedVolumes).getSingle())
          .totalBytes,
      456,
    );
    expect(
      (await database.select(database.readingProgresses).getSingle())
          .currentPage,
      3,
    );
    expect(
      (await database.select(database.offlineMetadataEntries).getSingle())
          .payload,
      '[]',
    );
    expect(
      (await database.select(database.pinnedImages).getSingle()).bookId,
      2,
    );
    expect(
      await (database.select(
        database.settings,
      )..where((table) => table.key.equals('cache.custom'))).getSingle(),
      const SettingRow(key: 'cache.custom', value: 'keep'),
    );
    expect(
      await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
            variables: [Variable.withString(_cacheIndexName)],
          )
          .map((row) => row.read<String>('name'))
          .getSingle(),
      _cacheIndexName,
    );
    expect(
      await (database.select(database.settings)
            ..where((table) => table.key.equals(AppDatabase.freshInstallKey)))
          .getSingleOrNull(),
      isNull,
    );
  });

  test('作成済み索引が残るv4も再移行でき既存データを保つ', () async {
    final root = Directory.systemTemp.createTempSync('comic_laz_migration');
    final file = File(p.join(root.path, 'comic_laz.sqlite'));
    final now = DateTime.utc(2026, 10, 8, 12);

    var database = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await database.close();
      try {
        if (root.existsSync()) root.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows が SQLite のハンドルを解放するまで遅れる場合は OS の掃除に任せる。
      }
    });

    await database
        .into(database.downloadedVolumes)
        .insert(
          DownloadedVolumeRow(
            volumeId: 9,
            bookId: 10,
            filesVersion: 100,
            status: VolumeDownloadStatus.completed,
            receivedBytes: 789,
            totalBytes: 789,
            pageCount: 12,
            updatedAt: now,
            completedAt: now,
          ),
        );
    // onCreate を通らない既存 v4 と、索引作成直後に終了した状態を再現する。
    await (database.delete(
      database.settings,
    )..where((table) => table.key.equals(AppDatabase.freshInstallKey))).go();
    await database.customStatement('PRAGMA user_version = 4');
    await database.close();

    database = AppDatabase(NativeDatabase(file));

    expect(
      (await database.select(database.downloadedVolumes).getSingle())
          .receivedBytes,
      789,
    );
    expect(
      await (database.select(database.settings)
            ..where((table) => table.key.equals(AppDatabase.freshInstallKey)))
          .getSingleOrNull(),
      isNull,
    );
  });
}

Future<String> _queryPlan(AppDatabase database, GenerationContext query) async {
  final rows = await database
      .customSelect(
        'EXPLAIN QUERY PLAN ${query.sql}',
        variables: [for (final value in query.boundVariables) Variable(value)],
      )
      .get();
  return rows.map((row) => row.read<String>('detail')).join('\n');
}
