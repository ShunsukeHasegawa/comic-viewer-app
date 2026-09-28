import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/cache/cache_settings.dart';
import '../../../core/cache/image_cache_store.dart';
import '../../../core/storage/app_database.dart';
import '../../library/application/library_controller.dart' show noAutoRetry;

part 'storage_settings_controller.freezed.dart';
part 'storage_settings_controller.g.dart';

/// ストレージ設定画面の状態。
@freezed
abstract class StorageSettingsState with _$StorageSettingsState {
  const factory StorageSettingsState({
    required CacheSettings settings,
    required CacheUsage usage,
  }) = _StorageSettingsState;
}

/// キャッシュの設定と使用量。
///
/// 自動再試行はしない（ローカル DB 相手なので、失敗したらユーザー操作でやり直す）。
@Riverpod(retry: noAutoRetry)
class StorageSettingsController extends _$StorageSettingsController {
  @override
  Future<StorageSettingsState> build() => _read();

  Future<StorageSettingsState> _read() async {
    final store = await ref.read(imageCacheStoreProvider.future);
    final settings = await ref.read(cacheSettingsStoreProvider).read();
    return StorageSettingsState(settings: settings, usage: await store.usage());
  }

  /// 使用量と設定を取り直す。
  Future<Object?> refresh() => _apply(_read);

  /// 上限 / 保持期間を保存し、超過分をその場で削除する。
  ///
  /// 削除を次の書き込みまで遅らせると「上限を下げたのに使用量が減らない」ように
  /// 見えるため、掃除を待ってから使用量を出し直す。
  Future<Object?> updateSettings(CacheSettings settings) {
    return _apply(() async {
      final store = await ref.read(imageCacheStoreProvider.future);
      await ref.read(cacheSettingsStoreProvider).write(settings);
      await store.evictIfNeeded();
      return StorageSettingsState(
        settings: settings,
        usage: await store.usage(),
      );
    });
  }

  /// 一時キャッシュを削除する（[kind] を省略するとページ + サムネイル）。
  ///
  /// **明示的にダウンロードしたデータ（#9）は消さない**（別領域・別テーブル）。
  Future<Object?> clearCache({CachedImageKind? kind}) {
    return _apply(() async {
      final store = await ref.read(imageCacheStoreProvider.future);
      await store.clear(kind: kind);
      final settings =
          state.value?.settings ??
          await ref.read(cacheSettingsStoreProvider).read();
      return StorageSettingsState(
        settings: settings,
        usage: await store.usage(),
      );
    });
  }

  /// 成功したら状態を差し替え、失敗したらエラーを返す。
  ///
  /// 失敗時に `state` をエラーにすると表示中の使用量まで消えてしまうので、
  /// 「何が失敗したか」は呼び出し側が SnackBar で知らせる。
  Future<Object?> _apply(Future<StorageSettingsState> Function() task) async {
    try {
      final next = await task();
      if (!ref.mounted) return null;
      state = AsyncValue.data(next);
      return null;
    } on Object catch (error) {
      return error;
    }
  }
}
