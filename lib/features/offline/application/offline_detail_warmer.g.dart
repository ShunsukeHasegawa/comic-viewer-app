// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_detail_warmer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(offlineDetailWarmer)
final offlineDetailWarmerProvider = OfflineDetailWarmerProvider._();

final class OfflineDetailWarmerProvider
    extends
        $FunctionalProvider<
          OfflineDetailWarmer,
          OfflineDetailWarmer,
          OfflineDetailWarmer
        >
    with $Provider<OfflineDetailWarmer> {
  OfflineDetailWarmerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineDetailWarmerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineDetailWarmerHash();

  @$internal
  @override
  $ProviderElement<OfflineDetailWarmer> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OfflineDetailWarmer create(Ref ref) {
    return offlineDetailWarmer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfflineDetailWarmer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfflineDetailWarmer>(value),
    );
  }
}

String _$offlineDetailWarmerHash() =>
    r'402ba5a4c8e446ddbf743dca46ba5a6fe8e66cf7';
