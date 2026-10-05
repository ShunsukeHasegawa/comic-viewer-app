// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keep_screen_on_setting.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(keepScreenOnStore)
final keepScreenOnStoreProvider = KeepScreenOnStoreProvider._();

final class KeepScreenOnStoreProvider
    extends
        $FunctionalProvider<
          KeepScreenOnStore,
          KeepScreenOnStore,
          KeepScreenOnStore
        >
    with $Provider<KeepScreenOnStore> {
  KeepScreenOnStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'keepScreenOnStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$keepScreenOnStoreHash();

  @$internal
  @override
  $ProviderElement<KeepScreenOnStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  KeepScreenOnStore create(Ref ref) {
    return keepScreenOnStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KeepScreenOnStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KeepScreenOnStore>(value),
    );
  }
}

String _$keepScreenOnStoreHash() => r'ba875087dfdefd8cdb8d16a711a518ef160bbbd8';

/// 読書中（ビューア表示中）に画面のスリープを抑止するか（#19）。
///
/// `ReadingScreenMode` がこれを見てスリープ抑止だけを切り替える（全画面表示は
/// 設定に関わらず続ける）。読めなかったときの扱い（ON とみなす）はそちらで決める。
///
/// テーマと同じく自動で再試行しない。端末内の DB が読めないのは一時的なことでは
/// まず無く、再試行の間は切り替えも塞がれる。保存し直せばそれで直る。

@ProviderFor(KeepScreenOnSetting)
final keepScreenOnSettingProvider = KeepScreenOnSettingProvider._();

/// 読書中（ビューア表示中）に画面のスリープを抑止するか（#19）。
///
/// `ReadingScreenMode` がこれを見てスリープ抑止だけを切り替える（全画面表示は
/// 設定に関わらず続ける）。読めなかったときの扱い（ON とみなす）はそちらで決める。
///
/// テーマと同じく自動で再試行しない。端末内の DB が読めないのは一時的なことでは
/// まず無く、再試行の間は切り替えも塞がれる。保存し直せばそれで直る。
final class KeepScreenOnSettingProvider
    extends $AsyncNotifierProvider<KeepScreenOnSetting, bool> {
  /// 読書中（ビューア表示中）に画面のスリープを抑止するか（#19）。
  ///
  /// `ReadingScreenMode` がこれを見てスリープ抑止だけを切り替える（全画面表示は
  /// 設定に関わらず続ける）。読めなかったときの扱い（ON とみなす）はそちらで決める。
  ///
  /// テーマと同じく自動で再試行しない。端末内の DB が読めないのは一時的なことでは
  /// まず無く、再試行の間は切り替えも塞がれる。保存し直せばそれで直る。
  KeepScreenOnSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: noAutoRetry,
        name: r'keepScreenOnSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$keepScreenOnSettingHash();

  @$internal
  @override
  KeepScreenOnSetting create() => KeepScreenOnSetting();
}

String _$keepScreenOnSettingHash() =>
    r'4127daa220a9da6b45e43f235d89ba285dfaa37e';

/// 読書中（ビューア表示中）に画面のスリープを抑止するか（#19）。
///
/// `ReadingScreenMode` がこれを見てスリープ抑止だけを切り替える（全画面表示は
/// 設定に関わらず続ける）。読めなかったときの扱い（ON とみなす）はそちらで決める。
///
/// テーマと同じく自動で再試行しない。端末内の DB が読めないのは一時的なことでは
/// まず無く、再試行の間は切り替えも塞がれる。保存し直せばそれで直る。

abstract class _$KeepScreenOnSetting extends $AsyncNotifier<bool> {
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
