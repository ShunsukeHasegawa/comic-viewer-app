// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_resume_monitor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appResumeMonitor)
final appResumeMonitorProvider = AppResumeMonitorProvider._();

final class AppResumeMonitorProvider
    extends
        $FunctionalProvider<
          AppResumeMonitor,
          AppResumeMonitor,
          AppResumeMonitor
        >
    with $Provider<AppResumeMonitor> {
  AppResumeMonitorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appResumeMonitorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appResumeMonitorHash();

  @$internal
  @override
  $ProviderElement<AppResumeMonitor> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppResumeMonitor create(Ref ref) {
    return appResumeMonitor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppResumeMonitor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppResumeMonitor>(value),
    );
  }
}

String _$appResumeMonitorHash() => r'9cee016594037918899531a4094a1d4830923ff5';
