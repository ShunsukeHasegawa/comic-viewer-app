// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_urls.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mediaUrls)
final mediaUrlsProvider = MediaUrlsProvider._();

final class MediaUrlsProvider
    extends $FunctionalProvider<MediaUrls, MediaUrls, MediaUrls>
    with $Provider<MediaUrls> {
  MediaUrlsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaUrlsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaUrlsHash();

  @$internal
  @override
  $ProviderElement<MediaUrls> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MediaUrls create(Ref ref) {
    return mediaUrls(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaUrls value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaUrls>(value),
    );
  }
}

String _$mediaUrlsHash() => r'b958cdddb39c83c277eb8cd52c346dcfa7cdff41';
