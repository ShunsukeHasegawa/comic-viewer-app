import 'package:comic_laz/core/cache/comic_image_loader.dart';
import 'package:comic_laz/core/cache/image_cache_store.dart';
import 'package:comic_laz/core/config/app_config.dart';
import 'package:comic_laz/core/device/connectivity_monitor.dart';
import 'package:comic_laz/core/device/device_name_resolver.dart';
import 'package:comic_laz/core/session/session_data_purger.dart';
import 'package:comic_laz/core/widgets/thumbnail_image.dart';
import 'package:comic_laz/data/api/books_api.dart';
import 'package:comic_laz/data/api/taxonomy_api.dart';
import 'package:comic_laz/data/api/user_api.dart';
import 'package:comic_laz/features/auth/application/auth_controller.dart';
import 'package:comic_laz/features/auth/data/auth_api.dart';
import 'package:comic_laz/features/auth/data/auth_store.dart';
import 'package:comic_laz/features/auth/domain/auth_state.dart';
import 'package:comic_laz/features/downloads/application/download_queue.dart';
import 'package:comic_laz/features/downloads/application/download_settings.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/library/data/library_repository.dart';
import 'package:comic_laz/features/offline/application/offline_metadata_gateway.dart';
import 'package:comic_laz/features/progress/data/progress_store.dart';
import 'package:comic_laz/features/viewer/presentation/widgets/viewer_page_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_fakes.dart';
import 'auth_fakes.dart';
import 'download_fakes.dart';
import 'progress_fakes.dart';

/// プラットフォームチャネルとネットワークを触らないようにした標準の override 群。
List<Override> testOverrides({
  AuthStore? authStore,
  AuthApi? authApi,
  DeviceNameResolver? deviceNameResolver,
  List<SessionDataPurger>? purgers,
  BooksApi? booksApi,
  UserApi? userApi,
  TaxonomyApi? taxonomyApi,
  ThumbnailBuilder? thumbnailBuilder,
  ViewerImageBuilder? viewerImageBuilder,
  PagePrecacher? pagePrecacher,
  StaleCacheEvictor? staleCacheEvictor,
  Map<int, VolumeDownload>? downloads,
  DownloadQueue Function()? downloadQueue,
  DownloadGate downloadGate = DownloadGate.open,
  DownloadWifiOnly Function()? downloadWifiOnly,
  ProgressStore? progressStore,
  ConnectivityMonitor? connectivityMonitor,
  OfflineMetadataGateway? offlineMetadata,
  LibraryCacheStore? libraryCache,
  String apiBaseUrl = 'http://localhost:8000',
}) {
  return [
    appConfigProvider.overrideWithValue(
      AppConfig.from(apiBaseUrl: apiBaseUrl, flavor: 'development'),
    ),
    authStoreProvider.overrideWithValue(authStore ?? FakeAuthStore()),
    deviceNameResolverProvider.overrideWithValue(
      deviceNameResolver ?? FakeDeviceNameResolver(),
    ),
    sessionDataPurgersProvider.overrideWithValue(purgers ?? const []),
    if (authApi != null) authApiProvider.overrideWithValue(authApi),
    booksApiProvider.overrideWithValue(booksApi ?? FakeBooksApi()),
    userApiProvider.overrideWithValue(userApi ?? FakeUserApi()),
    taxonomyApiProvider.overrideWithValue(taxonomyApi ?? FakeTaxonomyApi()),
    // 画像はネットワークを触らせない（URL とキャッシュキーだけ検証できるようにする）。
    viewerImageBuilderProvider.overrideWithValue(
      viewerImageBuilder ??
          (context, request, onRetry) =>
              const ColoredBox(color: Color(0xFF444444)),
    ),
    pagePrecacherProvider.overrideWithValue(
      pagePrecacher ?? (context, request) async {},
    ),
    thumbnailBuilderProvider.overrideWithValue(
      thumbnailBuilder ??
          (context, request, fit) => StubThumbnail(request: request),
    ),
    // 古い世代のキャッシュ掃除は、キャッシュ本体を作らずに済むよう既定で無効。
    staleCacheEvictorProvider.overrideWithValue(
      staleCacheEvictor ??
          ({required int volumeId, required int keepFilesVersion}) async {},
    ),
    // ダウンロードは DB とファイルを作るので、画面のテストでは記録だけの
    // スタブに差し替える（キューそのものの検証は download_queue_test）。
    downloadQueueProvider.overrideWith(
      downloadQueue ?? () => StubDownloadQueue(initial: {...?downloads}),
    ),
    // 回線の種類はプラグイン、設定は drift。画面のテストでは結果だけ差し込む。
    downloadGateProvider.overrideWithValue(downloadGate),
    downloadWifiOnlyProvider.overrideWith(
      downloadWifiOnly ?? StubDownloadWifiOnly.new,
    ),
    // 読書進捗は drift（プラットフォームチャネル）を使うので、既定はメモリ実装。
    progressStoreProvider.overrideWithValue(
      progressStore ?? InMemoryProgressStore(),
    ),
    // ネットワーク復帰の検知はプラグイン。テストからは流さない。
    connectivityMonitorProvider.overrideWithValue(
      connectivityMonitor ?? FakeConnectivityMonitor(),
    ),
    // オフライン用のメタ情報は drift + ダウンロード領域を触るので、既定は
    // 「何も控えていない」実装（#11 の分岐を試すテストだけ差し替える）。
    offlineMetadataGatewayProvider.overrideWithValue(
      offlineMetadata ?? const NoOfflineMetadataGateway(),
    ),
    // 一覧キャッシュの永続化も drift を触る。既定はプロセス内だけに持つ。
    libraryCacheStoreProvider.overrideWithValue(
      libraryCache ?? InMemoryLibraryCacheStore(),
    ),
  ];
}

/// テスト用のサムネイル代替ウィジェット。
class StubThumbnail extends StatelessWidget {
  const StubThumbnail({required this.request, super.key});

  final ComicImageRequest request;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// テスト用の [ProviderContainer]。
ProviderContainer createContainer({
  AuthStore? authStore,
  AuthApi? authApi,
  DeviceNameResolver? deviceNameResolver,
  List<SessionDataPurger>? purgers,
  BooksApi? booksApi,
  UserApi? userApi,
  TaxonomyApi? taxonomyApi,
  Map<int, VolumeDownload>? downloads,
  DownloadQueue Function()? downloadQueue,
  DownloadGate downloadGate = DownloadGate.open,
  ProgressStore? progressStore,
  ConnectivityMonitor? connectivityMonitor,
  OfflineMetadataGateway? offlineMetadata,
  LibraryCacheStore? libraryCache,
  List<Override> overrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      ...testOverrides(
        authStore: authStore,
        authApi: authApi,
        deviceNameResolver: deviceNameResolver,
        purgers: purgers,
        booksApi: booksApi,
        userApi: userApi,
        taxonomyApi: taxonomyApi,
        downloads: downloads,
        downloadQueue: downloadQueue,
        downloadGate: downloadGate,
        progressStore: progressStore,
        connectivityMonitor: connectivityMonitor,
        offlineMetadata: offlineMetadata,
        libraryCache: libraryCache,
      ),
      // 後に並べた方が勝つので、個別の差し替えはここへ足す。
      ...overrides,
    ],
  );
}

/// ウィジェットを override 込みの [ProviderScope] で包む。
Widget wrapWithScope(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(overrides: overrides, child: child);

/// `authControllerProvider` を構築し、起動時のトークン検証が終わるまで待つ。
Future<AuthState> settleAuth(ProviderContainer container) async {
  // read しないと build されない = 復元処理が始まらない。
  container.read(authControllerProvider);
  await pumpEventQueue();
  return container.read(authControllerProvider);
}
