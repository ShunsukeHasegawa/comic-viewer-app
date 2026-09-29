// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'volumes_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(volumesApi)
final volumesApiProvider = VolumesApiProvider._();

final class VolumesApiProvider
    extends $FunctionalProvider<VolumesApi, VolumesApi, VolumesApi>
    with $Provider<VolumesApi> {
  VolumesApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'volumesApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$volumesApiHash();

  @$internal
  @override
  $ProviderElement<VolumesApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VolumesApi create(Ref ref) {
    return volumesApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VolumesApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VolumesApi>(value),
    );
  }
}

String _$volumesApiHash() => r'780f7f30bcbcce3f73bb7bdbd624b1220cd6f05f';
