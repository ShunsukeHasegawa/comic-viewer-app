// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_monitor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(connectivityMonitor)
final connectivityMonitorProvider = ConnectivityMonitorProvider._();

final class ConnectivityMonitorProvider
    extends
        $FunctionalProvider<
          ConnectivityMonitor,
          ConnectivityMonitor,
          ConnectivityMonitor
        >
    with $Provider<ConnectivityMonitor> {
  ConnectivityMonitorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityMonitorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityMonitorHash();

  @$internal
  @override
  $ProviderElement<ConnectivityMonitor> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConnectivityMonitor create(Ref ref) {
    return connectivityMonitor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectivityMonitor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectivityMonitor>(value),
    );
  }
}

String _$connectivityMonitorHash() =>
    r'00a287585b130d630311a1a557f08d15d8cee5c1';
