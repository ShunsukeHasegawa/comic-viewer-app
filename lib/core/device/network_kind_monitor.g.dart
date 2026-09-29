// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_kind_monitor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(networkKindMonitor)
final networkKindMonitorProvider = NetworkKindMonitorProvider._();

final class NetworkKindMonitorProvider
    extends
        $FunctionalProvider<
          NetworkKindMonitor,
          NetworkKindMonitor,
          NetworkKindMonitor
        >
    with $Provider<NetworkKindMonitor> {
  NetworkKindMonitorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkKindMonitorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkKindMonitorHash();

  @$internal
  @override
  $ProviderElement<NetworkKindMonitor> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NetworkKindMonitor create(Ref ref) {
    return networkKindMonitor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkKindMonitor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkKindMonitor>(value),
    );
  }
}

String _$networkKindMonitorHash() =>
    r'5a57f311b3a91658ee21c15b21a0471ca1c3e899';

/// 今の回線の種類。最初の問い合わせが終わるまでは読み込み中。

@ProviderFor(networkKind)
final networkKindProvider = NetworkKindProvider._();

/// 今の回線の種類。最初の問い合わせが終わるまでは読み込み中。

final class NetworkKindProvider
    extends
        $FunctionalProvider<
          AsyncValue<NetworkKind>,
          NetworkKind,
          Stream<NetworkKind>
        >
    with $FutureModifier<NetworkKind>, $StreamProvider<NetworkKind> {
  /// 今の回線の種類。最初の問い合わせが終わるまでは読み込み中。
  NetworkKindProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkKindProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkKindHash();

  @$internal
  @override
  $StreamProviderElement<NetworkKind> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<NetworkKind> create(Ref ref) {
    return networkKind(ref);
  }
}

String _$networkKindHash() => r'88bb8e39d66969ebcf5c81d04e3e9160c863ed25';
