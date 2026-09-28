// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// キャッシュの設定と使用量。
///
/// 自動再試行はしない（ローカル DB 相手なので、失敗したらユーザー操作でやり直す）。

@ProviderFor(StorageSettingsController)
final storageSettingsControllerProvider = StorageSettingsControllerProvider._();

/// キャッシュの設定と使用量。
///
/// 自動再試行はしない（ローカル DB 相手なので、失敗したらユーザー操作でやり直す）。
final class StorageSettingsControllerProvider
    extends
        $AsyncNotifierProvider<
          StorageSettingsController,
          StorageSettingsState
        > {
  /// キャッシュの設定と使用量。
  ///
  /// 自動再試行はしない（ローカル DB 相手なので、失敗したらユーザー操作でやり直す）。
  StorageSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noAutoRetry,
        name: r'storageSettingsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageSettingsControllerHash();

  @$internal
  @override
  StorageSettingsController create() => StorageSettingsController();
}

String _$storageSettingsControllerHash() =>
    r'6340b825537774b4a7b6b3e123302f19f1e99ced';

/// キャッシュの設定と使用量。
///
/// 自動再試行はしない（ローカル DB 相手なので、失敗したらユーザー操作でやり直す）。

abstract class _$StorageSettingsController
    extends $AsyncNotifier<StorageSettingsState> {
  FutureOr<StorageSettingsState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<StorageSettingsState>, StorageSettingsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<StorageSettingsState>,
                StorageSettingsState
              >,
              AsyncValue<StorageSettingsState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
