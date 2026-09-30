// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auto_delete_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(autoDeleteSettingsStore)
final autoDeleteSettingsStoreProvider = AutoDeleteSettingsStoreProvider._();

final class AutoDeleteSettingsStoreProvider
    extends
        $FunctionalProvider<
          AutoDeleteSettingsStore,
          AutoDeleteSettingsStore,
          AutoDeleteSettingsStore
        >
    with $Provider<AutoDeleteSettingsStore> {
  AutoDeleteSettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoDeleteSettingsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoDeleteSettingsStoreHash();

  @$internal
  @override
  $ProviderElement<AutoDeleteSettingsStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AutoDeleteSettingsStore create(Ref ref) {
    return autoDeleteSettingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AutoDeleteSettingsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AutoDeleteSettingsStore>(value),
    );
  }
}

String _$autoDeleteSettingsStoreHash() =>
    r'd313cd06f8c17d5c0d728e36f7512d216eb83fb9';

/// 自動削除の設定。

@ProviderFor(AutoDeleteSettingsController)
final autoDeleteSettingsControllerProvider =
    AutoDeleteSettingsControllerProvider._();

/// 自動削除の設定。
final class AutoDeleteSettingsControllerProvider
    extends
        $AsyncNotifierProvider<
          AutoDeleteSettingsController,
          AutoDeleteSettings
        > {
  /// 自動削除の設定。
  AutoDeleteSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoDeleteSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoDeleteSettingsControllerHash();

  @$internal
  @override
  AutoDeleteSettingsController create() => AutoDeleteSettingsController();
}

String _$autoDeleteSettingsControllerHash() =>
    r'e3d0cbf1a6bf79a9df0efd64a6293e1b504c1aec';

/// 自動削除の設定。

abstract class _$AutoDeleteSettingsController
    extends $AsyncNotifier<AutoDeleteSettings> {
  FutureOr<AutoDeleteSettings> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AutoDeleteSettings>, AutoDeleteSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AutoDeleteSettings>, AutoDeleteSettings>,
              AsyncValue<AutoDeleteSettings>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
