// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(downloadStore)
final downloadStoreProvider = DownloadStoreProvider._();

final class DownloadStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<DownloadStore>,
          DownloadStore,
          FutureOr<DownloadStore>
        >
    with $FutureModifier<DownloadStore>, $FutureProvider<DownloadStore> {
  DownloadStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadStoreHash();

  @$internal
  @override
  $FutureProviderElement<DownloadStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DownloadStore> create(Ref ref) {
    return downloadStore(ref);
  }
}

String _$downloadStoreHash() => r'a57004e41bae46392dd64172438e2e0840b05080';
