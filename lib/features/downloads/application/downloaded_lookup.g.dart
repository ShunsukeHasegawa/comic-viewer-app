// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloaded_lookup.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 端末で読める（検証まで通った実体がある）巻 ID。
///
/// 初回の取得中 / 中断中は含めない。オフラインで「開ける巻」を判断する基準なので、
/// 途中のデータを含めると開いてから読めないことに気づく形になってしまう。
/// 一方で「更新あり」の取り直し中は**旧世代の ZIP が残っていて読める**ので、
/// status ではなく [VolumeDownload.hasInstalledArchive] で判断する（#11）。

@ProviderFor(downloadedVolumeIds)
final downloadedVolumeIdsProvider = DownloadedVolumeIdsProvider._();

/// 端末で読める（検証まで通った実体がある）巻 ID。
///
/// 初回の取得中 / 中断中は含めない。オフラインで「開ける巻」を判断する基準なので、
/// 途中のデータを含めると開いてから読めないことに気づく形になってしまう。
/// 一方で「更新あり」の取り直し中は**旧世代の ZIP が残っていて読める**ので、
/// status ではなく [VolumeDownload.hasInstalledArchive] で判断する（#11）。

final class DownloadedVolumeIdsProvider
    extends $FunctionalProvider<Set<int>, Set<int>, Set<int>>
    with $Provider<Set<int>> {
  /// 端末で読める（検証まで通った実体がある）巻 ID。
  ///
  /// 初回の取得中 / 中断中は含めない。オフラインで「開ける巻」を判断する基準なので、
  /// 途中のデータを含めると開いてから読めないことに気づく形になってしまう。
  /// 一方で「更新あり」の取り直し中は**旧世代の ZIP が残っていて読める**ので、
  /// status ではなく [VolumeDownload.hasInstalledArchive] で判断する（#11）。
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
    r'3a1a30acbcc3052a88d3b5a96475584059c292b7';

/// 読める巻を 1 つ以上持つタイトル ID。

@ProviderFor(downloadedBookIds)
final downloadedBookIdsProvider = DownloadedBookIdsProvider._();

/// 読める巻を 1 つ以上持つタイトル ID。

final class DownloadedBookIdsProvider
    extends $FunctionalProvider<Set<int>, Set<int>, Set<int>>
    with $Provider<Set<int>> {
  /// 読める巻を 1 つ以上持つタイトル ID。
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

String _$downloadedBookIdsHash() => r'3d629439689d98ccae089a0fc80e48022f4d2a52';

/// ダウンロード台帳をまだ読み終えていない（= 何が読めるか分からない）。
///
/// 台帳の読み込みは `path_provider` とディレクトリ作成を待つので、圏外の
/// コールドスタートでは一覧（drift の控え）より遅れる。その間の空集合を
/// 「ダウンロード済みが 0 件」と言い切ると、圏外で既定 ON の絞り込みが
/// 「ありません／すべて表示」になってしまう（#11 のレビュー指摘）。
/// 失敗（`AsyncError`）は `false`。読み終える見込みが無いので、待たせるより
/// 逃げ道（すべて表示）を出す。

@ProviderFor(isDownloadLedgerLoading)
final isDownloadLedgerLoadingProvider = IsDownloadLedgerLoadingProvider._();

/// ダウンロード台帳をまだ読み終えていない（= 何が読めるか分からない）。
///
/// 台帳の読み込みは `path_provider` とディレクトリ作成を待つので、圏外の
/// コールドスタートでは一覧（drift の控え）より遅れる。その間の空集合を
/// 「ダウンロード済みが 0 件」と言い切ると、圏外で既定 ON の絞り込みが
/// 「ありません／すべて表示」になってしまう（#11 のレビュー指摘）。
/// 失敗（`AsyncError`）は `false`。読み終える見込みが無いので、待たせるより
/// 逃げ道（すべて表示）を出す。

final class IsDownloadLedgerLoadingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// ダウンロード台帳をまだ読み終えていない（= 何が読めるか分からない）。
  ///
  /// 台帳の読み込みは `path_provider` とディレクトリ作成を待つので、圏外の
  /// コールドスタートでは一覧（drift の控え）より遅れる。その間の空集合を
  /// 「ダウンロード済みが 0 件」と言い切ると、圏外で既定 ON の絞り込みが
  /// 「ありません／すべて表示」になってしまう（#11 のレビュー指摘）。
  /// 失敗（`AsyncError`）は `false`。読み終える見込みが無いので、待たせるより
  /// 逃げ道（すべて表示）を出す。
  IsDownloadLedgerLoadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isDownloadLedgerLoadingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isDownloadLedgerLoadingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isDownloadLedgerLoading(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isDownloadLedgerLoadingHash() =>
    r'998c19d2729655cb797ea1f930958366f5ae1ec4';
