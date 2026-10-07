import 'package:comic_laz/core/cache/comic_image_loader.dart';
import 'package:comic_laz/core/cache/image_cache_store.dart';
import 'package:comic_laz/core/config/app_config.dart';
import 'package:comic_laz/core/device/app_resume_monitor.dart';
import 'package:comic_laz/core/device/connectivity_monitor.dart';
import 'package:comic_laz/core/device/device_name_resolver.dart';
import 'package:comic_laz/core/device/device_protection.dart';
import 'package:comic_laz/core/device/in_app_browser.dart';
import 'package:comic_laz/core/device/notification_permission_log.dart';
import 'package:comic_laz/core/session/session_data_purger.dart';
import 'package:comic_laz/core/session/session_purge_journal.dart';
import 'package:comic_laz/core/session/sign_out_hook.dart';
import 'package:comic_laz/core/storage/install_marker.dart';
import 'package:comic_laz/core/storage/storage_protection.dart';
import 'package:comic_laz/core/widgets/thumbnail_image.dart';
import 'package:comic_laz/data/api/books_api.dart';
import 'package:comic_laz/data/api/device_token_api.dart';
import 'package:comic_laz/data/api/taxonomy_api.dart';
import 'package:comic_laz/data/api/user_api.dart';
import 'package:comic_laz/features/auth/application/auth_controller.dart';
import 'package:comic_laz/features/auth/data/auth_api.dart';
import 'package:comic_laz/features/auth/data/auth_store.dart';
import 'package:comic_laz/features/auth/domain/auth_state.dart';
import 'package:comic_laz/features/downloads/application/auto_delete_runner.dart';
import 'package:comic_laz/features/downloads/application/auto_delete_settings.dart';
import 'package:comic_laz/features/downloads/application/download_queue.dart';
import 'package:comic_laz/features/downloads/application/download_settings.dart';
import 'package:comic_laz/features/downloads/data/archive_transport.dart';
import 'package:comic_laz/features/downloads/data/background_archive_transport.dart';
import 'package:comic_laz/features/downloads/data/free_space_probe.dart';
import 'package:comic_laz/features/downloads/data/safe_mode_revalidation_store.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:comic_laz/features/library/data/library_repository.dart';
import 'package:comic_laz/features/offline/application/offline_metadata_gateway.dart';
import 'package:comic_laz/features/progress/data/progress_store.dart';
import 'package:comic_laz/features/push/data/foreground_notifier.dart';
import 'package:comic_laz/features/push/data/push_messaging.dart';
import 'package:comic_laz/features/push/data/push_settings_store.dart';
import 'package:comic_laz/features/settings/application/keep_screen_on_setting.dart';
import 'package:comic_laz/features/settings/application/theme_mode_setting.dart';
import 'package:comic_laz/features/viewer/presentation/widgets/viewer_page_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_fakes.dart';
import 'auth_fakes.dart';
import 'device_fakes.dart';
import 'download_fakes.dart';
import 'progress_fakes.dart';
import 'push_fakes.dart';
import 'settings_fakes.dart';
import 'storage_fakes.dart';

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
  ArchiveTransport? archiveTransport,
  AppResumeMonitor? appResumeMonitor,
  ProgressStore? progressStore,
  ConnectivityMonitor? connectivityMonitor,
  OfflineMetadataGateway? offlineMetadata,
  LibraryCacheStore? libraryCache,
  DeviceStorageProbe? deviceStorageProbe,
  AutoDeleteSettingsController Function()? autoDeleteSettings,
  OpenVolumeCheck? openVolumeCheck,
  SessionPurgeJournal? sessionPurgeJournal,
  SafeModeRevalidationStore? safeModeRevalidationStore,
  DeviceProtection? deviceProtection,
  InstallMarker? installMarker,
  ThemeModeStore? themeModeStore,
  KeepScreenOnStore? keepScreenOnStore,
  PushMessaging? pushMessaging,
  ForegroundNotifier? foregroundNotifier,
  PushSettingsStore? pushSettingsStore,
  DeviceTokenApi? deviceTokenApi,
  NotificationPermissionLog? notificationPermissionLog,
  List<SignOutHook>? signOutHooks,
  InAppBrowser? inAppBrowser,
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
          (context, request, fit, {backdrop = false, onShown}) => StubThumbnail(
            request: request,
            backdrop: backdrop,
            onShown: onShown,
          ),
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
    // OS のバックグラウンド転送はプラットフォームチャネル。本物の
    // `FileDownloader` を作らせない（画面のテストでキューを本物にしても安全に）。
    archiveTransportProvider.overrideWithValue(
      archiveTransport ?? FakeArchiveTransport(),
    ),
    // 前面復帰の検知は WidgetsBinding に依る。テストからは流さない。
    appResumeMonitorProvider.overrideWithValue(
      appResumeMonitor ?? FakeAppResumeMonitor(),
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
    // 端末の空き容量はプラグイン（プラットフォームチャネル）。既定は「分からない」
    // （本番でプラグインが値を返さない端末と同じ）。キューも画面もここから読む。
    deviceStorageProbeProvider.overrideWithValue(
      deviceStorageProbe ?? unknownDeviceStorage,
    ),
    // 自動削除の設定は drift。既定はオフのスタブにして、アプリ全体を出す
    // テストで起動時の自動削除が走っても何も読まないようにする。
    autoDeleteSettingsControllerProvider.overrideWith(
      autoDeleteSettings ?? StubAutoDeleteSettingsController.new,
    ),
    // ビューアで開いている巻の判定（既定は「どれも開いていない」）。
    openVolumeCheckProvider.overrideWithValue(openVolumeCheck ?? (_) => false),
    // 破棄の印（#15）は drift の Settings。既定はメモリ上に持つ。
    sessionPurgeJournalProvider.overrideWithValue(
      sessionPurgeJournal ?? FakeSessionPurgeJournal(),
    ),
    // セーフモードの再検証の予約（#15）も drift。既定は「予約なし」。
    safeModeRevalidationStoreProvider.overrideWithValue(
      safeModeRevalidationStore ?? InMemorySafeModeRevalidationStore(),
    ),
    // バックアップ除外はプラットフォームチャネル（#15）。
    deviceProtectionProvider.overrideWithValue(
      deviceProtection ?? FakeDeviceProtection(),
    ),
    // 起動時の保護は path_provider（チャネル）で置き場を解決するので、既定では
    // 走らせない（StorageProtector 自体は storage_protection_test で確かめる）。
    storageProtectionProvider.overrideWith((ref) async {}),
    // 入れ直し直後の目印（#15）は drift。既定は「入れ直し直後ではない」（テストの
    // 保存済みトークンを起動時に消させない）。
    installMarkerProvider.overrideWithValue(
      installMarker ?? FakeInstallMarker(),
    ),
    // 表示テーマの設定（#17）は drift。既定は「システムに合わせる」をメモリに持つ。
    themeModeStoreProvider.overrideWithValue(
      themeModeStore ?? InMemoryThemeModeStore(),
    ),
    // 「読書中は画面を消さない」（#19）も drift。既定は ON をメモリに持つ。
    keepScreenOnStoreProvider.overrideWithValue(
      keepScreenOnStore ?? InMemoryKeepScreenOnStore(),
    ),
    // プッシュ通知（#14）。Firebase と flutter_local_notifications はチャネル、
    // 設定と控えは drift、登録は通信。既定は「このビルドでは使えない」
    // （設定ファイルの無いビルドと同じ）にして、ログイン / ログアウトのたびに
    // 登録の処理を走らせない。
    pushMessagingProvider.overrideWithValue(
      pushMessaging ?? FakePushMessaging(),
    ),
    foregroundNotificationsProvider.overrideWithValue(
      foregroundNotifier ?? FakeForegroundNotifier(),
    ),
    pushSettingsStoreProvider.overrideWithValue(
      pushSettingsStore ?? InMemoryPushSettingsStore(),
    ),
    deviceTokenApiProvider.overrideWithValue(
      deviceTokenApi ?? FakeDeviceTokenApi(),
    ),
    // 通知の許可を求めたかの記録（ダウンロードと共有。drift）。
    notificationPermissionLogProvider.overrideWithValue(
      notificationPermissionLog ?? InMemoryNotificationPermissionLog(),
    ),
    // 管理画面を開く Custom Tabs（#20）は url_launcher（チャネル）。
    inAppBrowserProvider.overrideWithValue(inAppBrowser ?? FakeInAppBrowser()),
    // ログアウト前のフックは既定で本物（プッシュ通知の解除。上のフェイクで動く）。
    if (signOutHooks != null)
      signOutHooksProvider.overrideWithValue(signOutHooks),
  ];
}

/// テスト用のサムネイル代替ウィジェット。
class StubThumbnail extends StatelessWidget {
  const StubThumbnail({
    required this.request,
    this.backdrop = false,
    this.onShown,
    super.key,
  });

  final ComicImageRequest request;
  final bool backdrop;

  /// 背景用の画像が見えきった合図。テストから呼んで「読み込めた」ことにする。
  final VoidCallback? onShown;

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
  DeviceStorageProbe? deviceStorageProbe,
  AutoDeleteSettingsController Function()? autoDeleteSettings,
  OpenVolumeCheck? openVolumeCheck,
  SessionPurgeJournal? sessionPurgeJournal,
  SafeModeRevalidationStore? safeModeRevalidationStore,
  DeviceProtection? deviceProtection,
  AppResumeMonitor? appResumeMonitor,
  InstallMarker? installMarker,
  ThemeModeStore? themeModeStore,
  KeepScreenOnStore? keepScreenOnStore,
  PushMessaging? pushMessaging,
  ForegroundNotifier? foregroundNotifier,
  PushSettingsStore? pushSettingsStore,
  DeviceTokenApi? deviceTokenApi,
  NotificationPermissionLog? notificationPermissionLog,
  List<SignOutHook>? signOutHooks,
  InAppBrowser? inAppBrowser,
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
        deviceStorageProbe: deviceStorageProbe,
        autoDeleteSettings: autoDeleteSettings,
        openVolumeCheck: openVolumeCheck,
        sessionPurgeJournal: sessionPurgeJournal,
        safeModeRevalidationStore: safeModeRevalidationStore,
        deviceProtection: deviceProtection,
        appResumeMonitor: appResumeMonitor,
        installMarker: installMarker,
        themeModeStore: themeModeStore,
        keepScreenOnStore: keepScreenOnStore,
        pushMessaging: pushMessaging,
        foregroundNotifier: foregroundNotifier,
        pushSettingsStore: pushSettingsStore,
        deviceTokenApi: deviceTokenApi,
        notificationPermissionLog: notificationPermissionLog,
        signOutHooks: signOutHooks,
        inAppBrowser: inAppBrowser,
      ),
      // Riverpod 3 は同じプロバイダの二重 override を拒むので、testOverrides が
      // 既に差し替えているもの（appResumeMonitor など）は上の引数で渡す。
      // ここへ足せるのは testOverrides が触らないプロバイダだけ。
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
