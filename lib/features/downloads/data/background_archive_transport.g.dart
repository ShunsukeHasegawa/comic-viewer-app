// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'background_archive_transport.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 巻の ZIP の転送経路。テストでは `FakeArchiveTransport` に差し替える
/// （本物はプラットフォームチャネルに触るため）。

@ProviderFor(archiveTransport)
final archiveTransportProvider = ArchiveTransportProvider._();

/// 巻の ZIP の転送経路。テストでは `FakeArchiveTransport` に差し替える
/// （本物はプラットフォームチャネルに触るため）。

final class ArchiveTransportProvider
    extends
        $FunctionalProvider<
          ArchiveTransport,
          ArchiveTransport,
          ArchiveTransport
        >
    with $Provider<ArchiveTransport> {
  /// 巻の ZIP の転送経路。テストでは `FakeArchiveTransport` に差し替える
  /// （本物はプラットフォームチャネルに触るため）。
  ArchiveTransportProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'archiveTransportProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$archiveTransportHash();

  @$internal
  @override
  $ProviderElement<ArchiveTransport> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ArchiveTransport create(Ref ref) {
    return archiveTransport(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArchiveTransport value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArchiveTransport>(value),
    );
  }
}

String _$archiveTransportHash() => r'5c76782a108fa089d041e95fc060384065a633b5';
