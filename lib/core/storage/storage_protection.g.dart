// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_protection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(storageProtector)
final storageProtectorProvider = StorageProtectorProvider._();

final class StorageProtectorProvider
    extends
        $FunctionalProvider<
          StorageProtector,
          StorageProtector,
          StorageProtector
        >
    with $Provider<StorageProtector> {
  StorageProtectorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageProtectorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageProtectorHash();

  @$internal
  @override
  $ProviderElement<StorageProtector> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StorageProtector create(Ref ref) {
    return storageProtector(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StorageProtector value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StorageProtector>(value),
    );
  }
}

String _$storageProtectorHash() => r'cab6e855855676edea987406e2d3b3f3198440ff';

/// 起動時に 1 回、保護を掛ける（`ComicLazApp` が購読する）。
///
/// DB と background_downloader の記録は [appDirectoriesProvider] を経由せずに
/// 作られるので、置き場を使う機能の初期化とは別に、起動時に必ず走らせる。
/// 置き場を用意できなければ何もしない（次の起動でやり直す）。

@ProviderFor(storageProtection)
final storageProtectionProvider = StorageProtectionProvider._();

/// 起動時に 1 回、保護を掛ける（`ComicLazApp` が購読する）。
///
/// DB と background_downloader の記録は [appDirectoriesProvider] を経由せずに
/// 作られるので、置き場を使う機能の初期化とは別に、起動時に必ず走らせる。
/// 置き場を用意できなければ何もしない（次の起動でやり直す）。

final class StorageProtectionProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// 起動時に 1 回、保護を掛ける（`ComicLazApp` が購読する）。
  ///
  /// DB と background_downloader の記録は [appDirectoriesProvider] を経由せずに
  /// 作られるので、置き場を使う機能の初期化とは別に、起動時に必ず走らせる。
  /// 置き場を用意できなければ何もしない（次の起動でやり直す）。
  StorageProtectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageProtectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageProtectionHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return storageProtection(ref);
  }
}

String _$storageProtectionHash() => r'69eb89160363f0a4f35a82f43f870a04f9a33362';
