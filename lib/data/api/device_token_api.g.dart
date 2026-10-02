// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_token_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deviceTokenApi)
final deviceTokenApiProvider = DeviceTokenApiProvider._();

final class DeviceTokenApiProvider
    extends $FunctionalProvider<DeviceTokenApi, DeviceTokenApi, DeviceTokenApi>
    with $Provider<DeviceTokenApi> {
  DeviceTokenApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceTokenApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceTokenApiHash();

  @$internal
  @override
  $ProviderElement<DeviceTokenApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeviceTokenApi create(Ref ref) {
    return deviceTokenApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceTokenApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceTokenApi>(value),
    );
  }
}

String _$deviceTokenApiHash() => r'6c08b62de98daa0d8c6487e0c922930f737ea5cc';
