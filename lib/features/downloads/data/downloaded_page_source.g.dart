// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloaded_page_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(downloadedPageSource)
final downloadedPageSourceProvider = DownloadedPageSourceProvider._();

final class DownloadedPageSourceProvider
    extends
        $FunctionalProvider<
          AsyncValue<DownloadedPageSource>,
          DownloadedPageSource,
          FutureOr<DownloadedPageSource>
        >
    with
        $FutureModifier<DownloadedPageSource>,
        $FutureProvider<DownloadedPageSource> {
  DownloadedPageSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadedPageSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadedPageSourceHash();

  @$internal
  @override
  $FutureProviderElement<DownloadedPageSource> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DownloadedPageSource> create(Ref ref) {
    return downloadedPageSource(ref);
  }
}

String _$downloadedPageSourceHash() =>
    r'ebb809c2d1ce10b2f3141b7b04daa57ff33a8278';
