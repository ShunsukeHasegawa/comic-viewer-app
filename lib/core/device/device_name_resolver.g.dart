// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_name_resolver.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deviceNameResolver)
final deviceNameResolverProvider = DeviceNameResolverProvider._();

final class DeviceNameResolverProvider
    extends
        $FunctionalProvider<
          DeviceNameResolver,
          DeviceNameResolver,
          DeviceNameResolver
        >
    with $Provider<DeviceNameResolver> {
  DeviceNameResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceNameResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceNameResolverHash();

  @$internal
  @override
  $ProviderElement<DeviceNameResolver> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeviceNameResolver create(Ref ref) {
    return deviceNameResolver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceNameResolver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceNameResolver>(value),
    );
  }
}

String _$deviceNameResolverHash() =>
    r'b7bd2fee4fb6c1ddd69b309ade9a2255207f8634';
