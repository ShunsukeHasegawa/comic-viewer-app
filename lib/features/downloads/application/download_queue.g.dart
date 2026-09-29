// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_queue.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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
/// ZIP の転送は OS のバックグラウンド転送（[ArchiveTransport]）に任せ、
/// アプリを閉じても続くようにする（#10）。Dart 側に残すのは次のものだけ:
/// - 積む順番（`creationTime` を狭義単調増加にして、1 巻から順に落とす）
/// - 転送が終わった後の検証（サイズ / ZIP として開けるか / ページ数）と、
///   `.zip.download` から本番のファイル名への rename、台帳の確定
/// - 失敗の解釈と再試行（ネイティブの 401 / Wi-Fi 切れ / 5xx を分ける）
/// - 起動時の照合（アプリが死んでいる間に終わった / 消えた転送の拾い上げ）
///
/// 同時実行数（1。自宅サーバーの HDD を複数本で読ませない）と Wi-Fi 限定は
/// OS 側（holding queue / requireWiFi）が守る。アプリが閉じていても効かせる
/// ため、Dart では止めない。

@ProviderFor(DownloadQueue)
final downloadQueueProvider = DownloadQueueProvider._();

/// 巻単位のダウンロードキュー。
///
/// ZIP の転送は OS のバックグラウンド転送（[ArchiveTransport]）に任せ、
/// アプリを閉じても続くようにする（#10）。Dart 側に残すのは次のものだけ:
/// - 積む順番（`creationTime` を狭義単調増加にして、1 巻から順に落とす）
/// - 転送が終わった後の検証（サイズ / ZIP として開けるか / ページ数）と、
///   `.zip.download` から本番のファイル名への rename、台帳の確定
/// - 失敗の解釈と再試行（ネイティブの 401 / Wi-Fi 切れ / 5xx を分ける）
/// - 起動時の照合（アプリが死んでいる間に終わった / 消えた転送の拾い上げ）
///
/// 同時実行数（1。自宅サーバーの HDD を複数本で読ませない）と Wi-Fi 限定は
/// OS 側（holding queue / requireWiFi）が守る。アプリが閉じていても効かせる
/// ため、Dart では止めない。
final class DownloadQueueProvider
    extends $AsyncNotifierProvider<DownloadQueue, Map<int, VolumeDownload>> {
  /// 巻単位のダウンロードキュー。
  ///
  /// ZIP の転送は OS のバックグラウンド転送（[ArchiveTransport]）に任せ、
  /// アプリを閉じても続くようにする（#10）。Dart 側に残すのは次のものだけ:
  /// - 積む順番（`creationTime` を狭義単調増加にして、1 巻から順に落とす）
  /// - 転送が終わった後の検証（サイズ / ZIP として開けるか / ページ数）と、
  ///   `.zip.download` から本番のファイル名への rename、台帳の確定
  /// - 失敗の解釈と再試行（ネイティブの 401 / Wi-Fi 切れ / 5xx を分ける）
  /// - 起動時の照合（アプリが死んでいる間に終わった / 消えた転送の拾い上げ）
  ///
  /// 同時実行数（1。自宅サーバーの HDD を複数本で読ませない）と Wi-Fi 限定は
  /// OS 側（holding queue / requireWiFi）が守る。アプリが閉じていても効かせる
  /// ため、Dart では止めない。
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

String _$downloadQueueHash() => r'2414962d92ebee447f16b7909b45e72804471f0e';

/// 巻単位のダウンロードキュー。
///
/// ZIP の転送は OS のバックグラウンド転送（[ArchiveTransport]）に任せ、
/// アプリを閉じても続くようにする（#10）。Dart 側に残すのは次のものだけ:
/// - 積む順番（`creationTime` を狭義単調増加にして、1 巻から順に落とす）
/// - 転送が終わった後の検証（サイズ / ZIP として開けるか / ページ数）と、
///   `.zip.download` から本番のファイル名への rename、台帳の確定
/// - 失敗の解釈と再試行（ネイティブの 401 / Wi-Fi 切れ / 5xx を分ける）
/// - 起動時の照合（アプリが死んでいる間に終わった / 消えた転送の拾い上げ）
///
/// 同時実行数（1。自宅サーバーの HDD を複数本で読ませない）と Wi-Fi 限定は
/// OS 側（holding queue / requireWiFi）が守る。アプリが閉じていても効かせる
/// ため、Dart では止めない。

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
