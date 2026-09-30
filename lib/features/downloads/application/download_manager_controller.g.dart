// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_manager_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ダウンロード管理画面のタイトル名・巻数・サーバー側の `files_version`。
///
/// **開いただけではネットワークに出ない**（自宅サーバーの HDD を起こさない・
/// 圏外でも即座に出す）。端末の控え（`OfflineMetadataGateway`）と一覧の控え
/// だけで組み立て、サーバーへの確認はユーザー操作（[refreshFromServer]）に限る。

@ProviderFor(DownloadManagerTitles)
final downloadManagerTitlesProvider = DownloadManagerTitlesProvider._();

/// ダウンロード管理画面のタイトル名・巻数・サーバー側の `files_version`。
///
/// **開いただけではネットワークに出ない**（自宅サーバーの HDD を起こさない・
/// 圏外でも即座に出す）。端末の控え（`OfflineMetadataGateway`）と一覧の控え
/// だけで組み立て、サーバーへの確認はユーザー操作（[refreshFromServer]）に限る。
final class DownloadManagerTitlesProvider
    extends
        $AsyncNotifierProvider<DownloadManagerTitles, DownloadTitleCatalog> {
  /// ダウンロード管理画面のタイトル名・巻数・サーバー側の `files_version`。
  ///
  /// **開いただけではネットワークに出ない**（自宅サーバーの HDD を起こさない・
  /// 圏外でも即座に出す）。端末の控え（`OfflineMetadataGateway`）と一覧の控え
  /// だけで組み立て、サーバーへの確認はユーザー操作（[refreshFromServer]）に限る。
  DownloadManagerTitlesProvider._()
    : super(
        from: null,
        argument: null,
        retry: noAutoRetry,
        name: r'downloadManagerTitlesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadManagerTitlesHash();

  @$internal
  @override
  DownloadManagerTitles create() => DownloadManagerTitles();
}

String _$downloadManagerTitlesHash() =>
    r'57fcafc1d2b7c7bd3ddc72d60e3cf88b98bb8ab4';

/// ダウンロード管理画面のタイトル名・巻数・サーバー側の `files_version`。
///
/// **開いただけではネットワークに出ない**（自宅サーバーの HDD を起こさない・
/// 圏外でも即座に出す）。端末の控え（`OfflineMetadataGateway`）と一覧の控え
/// だけで組み立て、サーバーへの確認はユーザー操作（[refreshFromServer]）に限る。

abstract class _$DownloadManagerTitles
    extends $AsyncNotifier<DownloadTitleCatalog> {
  FutureOr<DownloadTitleCatalog> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<DownloadTitleCatalog>, DownloadTitleCatalog>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<DownloadTitleCatalog>,
                DownloadTitleCatalog
              >,
              AsyncValue<DownloadTitleCatalog>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
