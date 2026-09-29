// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_metadata_gateway.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(offlineMetadataGateway)
final offlineMetadataGatewayProvider = OfflineMetadataGatewayProvider._();

final class OfflineMetadataGatewayProvider
    extends
        $FunctionalProvider<
          OfflineMetadataGateway,
          OfflineMetadataGateway,
          OfflineMetadataGateway
        >
    with $Provider<OfflineMetadataGateway> {
  OfflineMetadataGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineMetadataGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineMetadataGatewayHash();

  @$internal
  @override
  $ProviderElement<OfflineMetadataGateway> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OfflineMetadataGateway create(Ref ref) {
    return offlineMetadataGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfflineMetadataGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfflineMetadataGateway>(value),
    );
  }
}

String _$offlineMetadataGatewayHash() =>
    r'51759ba7d57599b9f8308458e9bbd4debb324574';
