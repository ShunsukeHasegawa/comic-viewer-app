// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'free_space_probe.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 端末のストレージの測り方。
///
/// 測る場所はダウンロードの置き場（application support）。キャッシュ領域と
/// 別のボリュームになる端末でも、判定したいのは ZIP を書く側の空きだから。
/// ディレクトリが解決できないときも「分からない」にする（決して投げない）。

@ProviderFor(deviceStorageProbe)
final deviceStorageProbeProvider = DeviceStorageProbeProvider._();

/// 端末のストレージの測り方。
///
/// 測る場所はダウンロードの置き場（application support）。キャッシュ領域と
/// 別のボリュームになる端末でも、判定したいのは ZIP を書く側の空きだから。
/// ディレクトリが解決できないときも「分からない」にする（決して投げない）。

final class DeviceStorageProbeProvider
    extends
        $FunctionalProvider<
          DeviceStorageProbe,
          DeviceStorageProbe,
          DeviceStorageProbe
        >
    with $Provider<DeviceStorageProbe> {
  /// 端末のストレージの測り方。
  ///
  /// 測る場所はダウンロードの置き場（application support）。キャッシュ領域と
  /// 別のボリュームになる端末でも、判定したいのは ZIP を書く側の空きだから。
  /// ディレクトリが解決できないときも「分からない」にする（決して投げない）。
  DeviceStorageProbeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceStorageProbeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceStorageProbeHash();

  @$internal
  @override
  $ProviderElement<DeviceStorageProbe> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeviceStorageProbe create(Ref ref) {
    return deviceStorageProbe(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceStorageProbe value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceStorageProbe>(value),
    );
  }
}

String _$deviceStorageProbeHash() =>
    r'26a37804415622bcdbfc13d1df676afa58b38451';

/// ダウンロード前の空き容量チェックに使う値。
///
/// 設定画面の表示と同じ [deviceStorageProbeProvider] から取る（キューと画面で
/// 違う値を見せない）。テストはこの provider ごと差し替え、プラグインには
/// 触らない。

@ProviderFor(freeSpaceProbe)
final freeSpaceProbeProvider = FreeSpaceProbeProvider._();

/// ダウンロード前の空き容量チェックに使う値。
///
/// 設定画面の表示と同じ [deviceStorageProbeProvider] から取る（キューと画面で
/// 違う値を見せない）。テストはこの provider ごと差し替え、プラグインには
/// 触らない。

final class FreeSpaceProbeProvider
    extends $FunctionalProvider<FreeSpaceProbe, FreeSpaceProbe, FreeSpaceProbe>
    with $Provider<FreeSpaceProbe> {
  /// ダウンロード前の空き容量チェックに使う値。
  ///
  /// 設定画面の表示と同じ [deviceStorageProbeProvider] から取る（キューと画面で
  /// 違う値を見せない）。テストはこの provider ごと差し替え、プラグインには
  /// 触らない。
  FreeSpaceProbeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'freeSpaceProbeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$freeSpaceProbeHash();

  @$internal
  @override
  $ProviderElement<FreeSpaceProbe> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FreeSpaceProbe create(Ref ref) {
    return freeSpaceProbe(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FreeSpaceProbe value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FreeSpaceProbe>(value),
    );
  }
}

String _$freeSpaceProbeHash() => r'292ff0b9f54fd822ad9951fc8f1f74da60c909b2';
