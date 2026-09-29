// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_recorder.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(progressRecorder)
final progressRecorderProvider = ProgressRecorderProvider._();

final class ProgressRecorderProvider
    extends
        $FunctionalProvider<
          ProgressRecorder,
          ProgressRecorder,
          ProgressRecorder
        >
    with $Provider<ProgressRecorder> {
  ProgressRecorderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'progressRecorderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$progressRecorderHash();

  @$internal
  @override
  $ProviderElement<ProgressRecorder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProgressRecorder create(Ref ref) {
    return progressRecorder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProgressRecorder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProgressRecorder>(value),
    );
  }
}

String _$progressRecorderHash() => r'e39065c524601237aaa6b3daef579849c0a2c01d';
