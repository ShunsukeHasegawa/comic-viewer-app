// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloaded_lookup.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 端末で読める（検証まで通った）巻 ID。
///
/// 取得中 / 中断中は含めない。オフラインで「開ける巻」を判断する基準なので、
/// 途中のデータを含めると開いてから読めないことに気づく形になってしまう。

@ProviderFor(downloadedVolumeIds)
final downloadedVolumeIdsProvider = DownloadedVolumeIdsProvider._();

/// 端末で読める（検証まで通った）巻 ID。
///
/// 取得中 / 中断中は含めない。オフラインで「開ける巻」を判断する基準なので、
/// 途中のデータを含めると開いてから読めないことに気づく形になってしまう。

final class DownloadedVolumeIdsProvider
    extends $FunctionalProvider<Set<int>, Set<int>, Set<int>>
    with $Provider<Set<int>> {
  /// 端末で読める（検証まで通った）巻 ID。
  ///
  /// 取得中 / 中断中は含めない。オフラインで「開ける巻」を判断する基準なので、
  /// 途中のデータを含めると開いてから読めないことに気づく形になってしまう。
  DownloadedVolumeIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadedVolumeIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadedVolumeIdsHash();

  @$internal
  @override
  $ProviderElement<Set<int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<int> create(Ref ref) {
    return downloadedVolumeIds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<int>>(value),
    );
  }
}

String _$downloadedVolumeIdsHash() =>
    r'348b50697a695c4c74ebfaa31a793349ae9889cc';

/// ダウンロード済みの巻を 1 つ以上持つタイトル ID。

@ProviderFor(downloadedBookIds)
final downloadedBookIdsProvider = DownloadedBookIdsProvider._();

/// ダウンロード済みの巻を 1 つ以上持つタイトル ID。

final class DownloadedBookIdsProvider
    extends $FunctionalProvider<Set<int>, Set<int>, Set<int>>
    with $Provider<Set<int>> {
  /// ダウンロード済みの巻を 1 つ以上持つタイトル ID。
  DownloadedBookIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadedBookIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadedBookIdsHash();

  @$internal
  @override
  $ProviderElement<Set<int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<int> create(Ref ref) {
    return downloadedBookIds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<int>>(value),
    );
  }
}

String _$downloadedBookIdsHash() => r'c67b30ffa9c7c224c4897d23d26c77dbe299e62c';
