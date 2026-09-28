// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'taxonomy_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(taxonomyApi)
final taxonomyApiProvider = TaxonomyApiProvider._();

final class TaxonomyApiProvider
    extends $FunctionalProvider<TaxonomyApi, TaxonomyApi, TaxonomyApi>
    with $Provider<TaxonomyApi> {
  TaxonomyApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taxonomyApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taxonomyApiHash();

  @$internal
  @override
  $ProviderElement<TaxonomyApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaxonomyApi create(Ref ref) {
    return taxonomyApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaxonomyApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaxonomyApi>(value),
    );
  }
}

String _$taxonomyApiHash() => r'87de0b6a0da4e67bbd4dee3ba7d58df56ba9fbe2';
