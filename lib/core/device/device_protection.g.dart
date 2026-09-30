// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_protection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deviceProtection)
final deviceProtectionProvider = DeviceProtectionProvider._();

final class DeviceProtectionProvider
    extends
        $FunctionalProvider<
          DeviceProtection,
          DeviceProtection,
          DeviceProtection
        >
    with $Provider<DeviceProtection> {
  DeviceProtectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceProtectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceProtectionHash();

  @$internal
  @override
  $ProviderElement<DeviceProtection> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeviceProtection create(Ref ref) {
    return deviceProtection(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceProtection value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceProtection>(value),
    );
  }
}

String _$deviceProtectionHash() => r'7aea42bb5d8404af20f8e3603a7b126ab4c9f169';
