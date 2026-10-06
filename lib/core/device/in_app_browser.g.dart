// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'in_app_browser.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(inAppBrowser)
final inAppBrowserProvider = InAppBrowserProvider._();

final class InAppBrowserProvider
    extends $FunctionalProvider<InAppBrowser, InAppBrowser, InAppBrowser>
    with $Provider<InAppBrowser> {
  InAppBrowserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inAppBrowserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inAppBrowserHash();

  @$internal
  @override
  $ProviderElement<InAppBrowser> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InAppBrowser create(Ref ref) {
    return inAppBrowser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InAppBrowser value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InAppBrowser>(value),
    );
  }
}

String _$inAppBrowserHash() => r'db1c0fa62ccaa84d712ebf7ec80390f8085437d0';
