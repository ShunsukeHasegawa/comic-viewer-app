import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/app_database.dart';

part 'cache_settings.freezed.dart';
part 'cache_settings.g.dart';

/// 一時キャッシュの上限。
enum CacheLimit {
  mb256(256 * 1024 * 1024, '256 MB'),
  mb512(512 * 1024 * 1024, '512 MB'),
  gb1(1024 * 1024 * 1024, '1 GB'),
  gb2(2 * 1024 * 1024 * 1024, '2 GB'),

  /// 上限なし（ダウンロード済みデータと合わせて端末の空き容量で律速）。
  unlimited(null, '無制限');

  const CacheLimit(this.bytes, this.label);

  /// 上限のバイト数。`null` は無制限。
  final int? bytes;

  final String label;
}

/// 一時キャッシュの保持期間。
enum CacheRetention {
  days7(Duration(days: 7), '7 日'),
  days30(Duration(days: 30), '30 日'),
  forever(null, '無期限');

  const CacheRetention(this.duration, this.label);

  /// `null` は無期限。
  final Duration? duration;

  final String label;
}

/// キャッシュ設定。
///
/// 既定値は Web 版（Workbox）の方針に寄せる:
/// ページ画像は 1 枚 1MB 超になるので控えめ、サムネイルは小さいので長めに持つ。
@freezed
abstract class CacheSettings with _$CacheSettings {
  const factory CacheSettings({
    @Default(CacheLimit.gb1) CacheLimit pageLimit,
    @Default(CacheLimit.mb256) CacheLimit thumbnailLimit,
    @Default(CacheRetention.days30) CacheRetention retention,
  }) = _CacheSettings;
}

/// 設定の読み書き（drift の key-value テーブル）。
class CacheSettingsStore {
  CacheSettingsStore(this._database);

  static const pageLimitKey = 'cache.page_limit';
  static const thumbnailLimitKey = 'cache.thumbnail_limit';
  static const retentionKey = 'cache.retention';

  final AppDatabase _database;

  Future<CacheSettings> read() async {
    final rows = await _database.select(_database.settings).get();
    final values = {for (final row in rows) row.key: row.value};

    return CacheSettings(
      pageLimit: _parse(
        values[pageLimitKey],
        CacheLimit.values,
        CacheLimit.gb1,
      ),
      thumbnailLimit: _parse(
        values[thumbnailLimitKey],
        CacheLimit.values,
        CacheLimit.mb256,
      ),
      retention: _parse(
        values[retentionKey],
        CacheRetention.values,
        CacheRetention.days30,
      ),
    );
  }

  Future<void> write(CacheSettings settings) async {
    await _database.batch((batch) {
      batch.insertAllOnConflictUpdate(_database.settings, [
        SettingRow(key: pageLimitKey, value: settings.pageLimit.name),
        SettingRow(key: thumbnailLimitKey, value: settings.thumbnailLimit.name),
        SettingRow(key: retentionKey, value: settings.retention.name),
      ]);
    });
  }

  /// 未知の値（バージョン間で enum が変わった場合）は既定値に倒す。
  static T _parse<T extends Enum>(String? raw, List<T> values, T fallback) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }
}

@Riverpod(keepAlive: true)
CacheSettingsStore cacheSettingsStore(Ref ref) =>
    CacheSettingsStore(ref.watch(appDatabaseProvider));
