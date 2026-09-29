// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_queue.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 同時に走らせるダウンロードの数。
///
/// 自宅サーバーは HDD なので、並列に ZIP を読ませるとシークだらけになって
/// 全体が遅くなる（1 巻 = 1 ファイルのシーケンシャル read が一番速い）。
/// 既定は 1。テストや将来の設定から変えられるよう provider にしておく。

@ProviderFor(downloadConcurrency)
final downloadConcurrencyProvider = DownloadConcurrencyProvider._();

/// 同時に走らせるダウンロードの数。
///
/// 自宅サーバーは HDD なので、並列に ZIP を読ませるとシークだらけになって
/// 全体が遅くなる（1 巻 = 1 ファイルのシーケンシャル read が一番速い）。
/// 既定は 1。テストや将来の設定から変えられるよう provider にしておく。

final class DownloadConcurrencyProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// 同時に走らせるダウンロードの数。
  ///
  /// 自宅サーバーは HDD なので、並列に ZIP を読ませるとシークだらけになって
  /// 全体が遅くなる（1 巻 = 1 ファイルのシーケンシャル read が一番速い）。
  /// 既定は 1。テストや将来の設定から変えられるよう provider にしておく。
  DownloadConcurrencyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadConcurrencyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadConcurrencyHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return downloadConcurrency(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$downloadConcurrencyHash() =>
    r'1901fc6894407f6201d218882ddb9f4de13fcaf6';

@ProviderFor(downloadRetryDelay)
final downloadRetryDelayProvider = DownloadRetryDelayProvider._();

final class DownloadRetryDelayProvider
    extends $FunctionalProvider<RetryDelay, RetryDelay, RetryDelay>
    with $Provider<RetryDelay> {
  DownloadRetryDelayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadRetryDelayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadRetryDelayHash();

  @$internal
  @override
  $ProviderElement<RetryDelay> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RetryDelay create(Ref ref) {
    return downloadRetryDelay(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RetryDelay value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RetryDelay>(value),
    );
  }
}

String _$downloadRetryDelayHash() =>
    r'64fa7224546cdbb73807407804a26983cd910838';

/// 巻単位のダウンロードキュー。
///
/// - 同時実行数を [downloadConcurrency] に制限する
/// - 中断・再開は `Range`（一時ファイルの実サイズを起点にする）
/// - 失敗は指数バックオフで再試行。429 は `Retry-After` に従う
/// - [downloadGateProvider] が閉じている間（Wi-Fi 限定で Wi-Fi に繋がって
///   いない）は新しく始めず、走行中のものは待機に戻す（#10）
/// - 完了前に検証（サイズ / ZIP として開けるか / ページ数）し、
///   通ったものだけ `.part` から本番のファイル名へ rename する

@ProviderFor(DownloadQueue)
final downloadQueueProvider = DownloadQueueProvider._();

/// 巻単位のダウンロードキュー。
///
/// - 同時実行数を [downloadConcurrency] に制限する
/// - 中断・再開は `Range`（一時ファイルの実サイズを起点にする）
/// - 失敗は指数バックオフで再試行。429 は `Retry-After` に従う
/// - [downloadGateProvider] が閉じている間（Wi-Fi 限定で Wi-Fi に繋がって
///   いない）は新しく始めず、走行中のものは待機に戻す（#10）
/// - 完了前に検証（サイズ / ZIP として開けるか / ページ数）し、
///   通ったものだけ `.part` から本番のファイル名へ rename する
final class DownloadQueueProvider
    extends $AsyncNotifierProvider<DownloadQueue, Map<int, VolumeDownload>> {
  /// 巻単位のダウンロードキュー。
  ///
  /// - 同時実行数を [downloadConcurrency] に制限する
  /// - 中断・再開は `Range`（一時ファイルの実サイズを起点にする）
  /// - 失敗は指数バックオフで再試行。429 は `Retry-After` に従う
  /// - [downloadGateProvider] が閉じている間（Wi-Fi 限定で Wi-Fi に繋がって
  ///   いない）は新しく始めず、走行中のものは待機に戻す（#10）
  /// - 完了前に検証（サイズ / ZIP として開けるか / ページ数）し、
  ///   通ったものだけ `.part` から本番のファイル名へ rename する
  DownloadQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadQueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadQueueHash();

  @$internal
  @override
  DownloadQueue create() => DownloadQueue();
}

String _$downloadQueueHash() => r'5f0e7ec5eb5034bd8ea5c8118f7517a2ce82deee';

/// 巻単位のダウンロードキュー。
///
/// - 同時実行数を [downloadConcurrency] に制限する
/// - 中断・再開は `Range`（一時ファイルの実サイズを起点にする）
/// - 失敗は指数バックオフで再試行。429 は `Retry-After` に従う
/// - [downloadGateProvider] が閉じている間（Wi-Fi 限定で Wi-Fi に繋がって
///   いない）は新しく始めず、走行中のものは待機に戻す（#10）
/// - 完了前に検証（サイズ / ZIP として開けるか / ページ数）し、
///   通ったものだけ `.part` から本番のファイル名へ rename する

abstract class _$DownloadQueue
    extends $AsyncNotifier<Map<int, VolumeDownload>> {
  FutureOr<Map<int, VolumeDownload>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<Map<int, VolumeDownload>>,
              Map<int, VolumeDownload>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Map<int, VolumeDownload>>,
                Map<int, VolumeDownload>
              >,
              AsyncValue<Map<int, VolumeDownload>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
