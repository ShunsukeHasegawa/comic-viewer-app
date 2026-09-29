// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_syncer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(progressSyncer)
final progressSyncerProvider = ProgressSyncerProvider._();

final class ProgressSyncerProvider
    extends $FunctionalProvider<ProgressSyncer, ProgressSyncer, ProgressSyncer>
    with $Provider<ProgressSyncer> {
  ProgressSyncerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'progressSyncerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$progressSyncerHash();

  @$internal
  @override
  $ProviderElement<ProgressSyncer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProgressSyncer create(Ref ref) {
    return progressSyncer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProgressSyncer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProgressSyncer>(value),
    );
  }
}

String _$progressSyncerHash() => r'b0068d62383d9a96ab02f29c76dd299296600151';
