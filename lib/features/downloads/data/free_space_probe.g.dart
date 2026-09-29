// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'free_space_probe.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(freeSpaceProbe)
final freeSpaceProbeProvider = FreeSpaceProbeProvider._();

final class FreeSpaceProbeProvider
    extends $FunctionalProvider<FreeSpaceProbe, FreeSpaceProbe, FreeSpaceProbe>
    with $Provider<FreeSpaceProbe> {
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

String _$freeSpaceProbeHash() => r'335ed8610f246403d7bf469e5ae0a3f9e44ae9b1';
