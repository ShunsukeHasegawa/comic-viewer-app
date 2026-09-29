// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(downloadSettingsStore)
final downloadSettingsStoreProvider = DownloadSettingsStoreProvider._();

final class DownloadSettingsStoreProvider
    extends
        $FunctionalProvider<
          DownloadSettingsStore,
          DownloadSettingsStore,
          DownloadSettingsStore
        >
    with $Provider<DownloadSettingsStore> {
  DownloadSettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadSettingsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadSettingsStoreHash();

  @$internal
  @override
  $ProviderElement<DownloadSettingsStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadSettingsStore create(Ref ref) {
    return downloadSettingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadSettingsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadSettingsStore>(value),
    );
  }
}

String _$downloadSettingsStoreHash() =>
    r'85b9390723ce9a4d76ad41f0124e4a4377c7bb9b';

/// 「Wi-Fi のときだけダウンロードする」設定。

@ProviderFor(DownloadWifiOnly)
final downloadWifiOnlyProvider = DownloadWifiOnlyProvider._();

/// 「Wi-Fi のときだけダウンロードする」設定。
final class DownloadWifiOnlyProvider
    extends $AsyncNotifierProvider<DownloadWifiOnly, bool> {
  /// 「Wi-Fi のときだけダウンロードする」設定。
  DownloadWifiOnlyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadWifiOnlyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadWifiOnlyHash();

  @$internal
  @override
  DownloadWifiOnly create() => DownloadWifiOnly();
}

String _$downloadWifiOnlyHash() => r'2858ec592d0b2b96d9e3a4c3895f5d9d76c2d19c';

/// 「Wi-Fi のときだけダウンロードする」設定。

abstract class _$DownloadWifiOnly extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// [DownloadWifiOnly] と回線の種類から、キューを流してよいかを決める。
///
/// 設定や回線がまだ分からない間は閉じておく。起動直後に一瞬モバイル回線で
/// 走り出してしまうより、数百ミリ秒待たせる方がよい。

@ProviderFor(downloadGate)
final downloadGateProvider = DownloadGateProvider._();

/// [DownloadWifiOnly] と回線の種類から、キューを流してよいかを決める。
///
/// 設定や回線がまだ分からない間は閉じておく。起動直後に一瞬モバイル回線で
/// 走り出してしまうより、数百ミリ秒待たせる方がよい。

final class DownloadGateProvider
    extends $FunctionalProvider<DownloadGate, DownloadGate, DownloadGate>
    with $Provider<DownloadGate> {
  /// [DownloadWifiOnly] と回線の種類から、キューを流してよいかを決める。
  ///
  /// 設定や回線がまだ分からない間は閉じておく。起動直後に一瞬モバイル回線で
  /// 走り出してしまうより、数百ミリ秒待たせる方がよい。
  DownloadGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadGateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadGateHash();

  @$internal
  @override
  $ProviderElement<DownloadGate> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DownloadGate create(Ref ref) {
    return downloadGate(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadGate value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadGate>(value),
    );
  }
}

String _$downloadGateHash() => r'1cb929d211da89b13658e300ced60dfd7030b693';
