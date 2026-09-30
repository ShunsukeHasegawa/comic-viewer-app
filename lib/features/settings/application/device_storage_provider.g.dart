// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_storage_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 端末の空き容量と全体の容量（設定画面の表示用）。`null` は「不明」。
///
/// ダウンロードを消したら取り直す（台帳から出す使用量と空き容量の表示を
/// 食い違わせない）。キャッシュ削除・全データ削除・再計算の後は画面が
/// invalidate する。プローブは投げないので、エラーにはならない。

@ProviderFor(deviceStorage)
final deviceStorageProvider = DeviceStorageProvider._();

/// 端末の空き容量と全体の容量（設定画面の表示用）。`null` は「不明」。
///
/// ダウンロードを消したら取り直す（台帳から出す使用量と空き容量の表示を
/// 食い違わせない）。キャッシュ削除・全データ削除・再計算の後は画面が
/// invalidate する。プローブは投げないので、エラーにはならない。

final class DeviceStorageProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeviceStorage?>,
          DeviceStorage?,
          FutureOr<DeviceStorage?>
        >
    with $FutureModifier<DeviceStorage?>, $FutureProvider<DeviceStorage?> {
  /// 端末の空き容量と全体の容量（設定画面の表示用）。`null` は「不明」。
  ///
  /// ダウンロードを消したら取り直す（台帳から出す使用量と空き容量の表示を
  /// 食い違わせない）。キャッシュ削除・全データ削除・再計算の後は画面が
  /// invalidate する。プローブは投げないので、エラーにはならない。
  DeviceStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceStorageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceStorageHash();

  @$internal
  @override
  $FutureProviderElement<DeviceStorage?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DeviceStorage?> create(Ref ref) {
    return deviceStorage(ref);
  }
}

String _$deviceStorageHash() => r'3d91a0ba9b03730a2ffc114048c288a9e2094bdd';
