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
    r'a9543b3d95a6c92ffdaa7f20d17d43663b90fbec';

/// ダウンロード完了で詳細の控えを書いた回数（読み直しの合図）。

@ProviderFor(OfflineDetailRevision)
final offlineDetailRevisionProvider = OfflineDetailRevisionProvider._();

/// ダウンロード完了で詳細の控えを書いた回数（読み直しの合図）。
final class OfflineDetailRevisionProvider
    extends $NotifierProvider<OfflineDetailRevision, int> {
  /// ダウンロード完了で詳細の控えを書いた回数（読み直しの合図）。
  OfflineDetailRevisionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineDetailRevisionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineDetailRevisionHash();

  @$internal
  @override
  OfflineDetailRevision create() => OfflineDetailRevision();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$offlineDetailRevisionHash() =>
    r'38b44bc3a7ca9ea06853c17e7e01d39a339139e5';

/// ダウンロード完了で詳細の控えを書いた回数（読み直しの合図）。

abstract class _$OfflineDetailRevision extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
