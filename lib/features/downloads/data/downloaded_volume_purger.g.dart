// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloaded_volume_purger.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(downloadedVolumePurger)
final downloadedVolumePurgerProvider = DownloadedVolumePurgerProvider._();

final class DownloadedVolumePurgerProvider
    extends
        $FunctionalProvider<
          SessionDataPurger,
          SessionDataPurger,
          SessionDataPurger
        >
    with $Provider<SessionDataPurger> {
  DownloadedVolumePurgerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadedVolumePurgerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadedVolumePurgerHash();

  @$internal
  @override
  $ProviderElement<SessionDataPurger> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionDataPurger create(Ref ref) {
    return downloadedVolumePurger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionDataPurger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionDataPurger>(value),
    );
  }
}

String _$downloadedVolumePurgerHash() =>
    r'2d75b7abdeed28ba6a12422b59f38057b50e7788';
