// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_storage_summary_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ダウンロードの容量の内訳（設定画面用）。
///
/// 台帳（[downloadQueueProvider]）から毎回集計する。DB を別に集計しないので、
/// 巻を削除すればその場で表示が減る（「削除後に容量表示が正しく更新される」）。
///
/// 台帳の読み込み中 / 失敗はそのまま返す。0 B と見せると「ダウンロードが無い」
/// と読めてしまうため、画面はそれぞれを別に表示する。

@ProviderFor(downloadStorageSummary)
final downloadStorageSummaryProvider = DownloadStorageSummaryProvider._();

/// ダウンロードの容量の内訳（設定画面用）。
///
/// 台帳（[downloadQueueProvider]）から毎回集計する。DB を別に集計しないので、
/// 巻を削除すればその場で表示が減る（「削除後に容量表示が正しく更新される」）。
///
/// 台帳の読み込み中 / 失敗はそのまま返す。0 B と見せると「ダウンロードが無い」
/// と読めてしまうため、画面はそれぞれを別に表示する。

final class DownloadStorageSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<DownloadStorageSummary>,
          AsyncValue<DownloadStorageSummary>,
          AsyncValue<DownloadStorageSummary>
        >
    with $Provider<AsyncValue<DownloadStorageSummary>> {
  /// ダウンロードの容量の内訳（設定画面用）。
  ///
  /// 台帳（[downloadQueueProvider]）から毎回集計する。DB を別に集計しないので、
  /// 巻を削除すればその場で表示が減る（「削除後に容量表示が正しく更新される」）。
  ///
  /// 台帳の読み込み中 / 失敗はそのまま返す。0 B と見せると「ダウンロードが無い」
  /// と読めてしまうため、画面はそれぞれを別に表示する。
  DownloadStorageSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadStorageSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadStorageSummaryHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<DownloadStorageSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<DownloadStorageSummary> create(Ref ref) {
    return downloadStorageSummary(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<DownloadStorageSummary> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<DownloadStorageSummary>>(
        value,
      ),
    );
  }
}

String _$downloadStorageSummaryHash() =>
    r'f3901a304f14448f09c0d6c33d5200db8282f38a';
