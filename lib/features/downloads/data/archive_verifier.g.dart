// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archive_verifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(archiveVerifier)
final archiveVerifierProvider = ArchiveVerifierProvider._();

final class ArchiveVerifierProvider
    extends
        $FunctionalProvider<ArchiveVerifier, ArchiveVerifier, ArchiveVerifier>
    with $Provider<ArchiveVerifier> {
  ArchiveVerifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'archiveVerifierProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$archiveVerifierHash();

  @$internal
  @override
  $ProviderElement<ArchiveVerifier> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ArchiveVerifier create(Ref ref) {
    return archiveVerifier(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArchiveVerifier value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArchiveVerifier>(value),
    );
  }
}

String _$archiveVerifierHash() => r'133b96fad31746719c1e68399e8f963e721bb682';
