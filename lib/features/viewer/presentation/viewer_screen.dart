import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cache/comic_image_loader.dart';
import '../../../core/device/reading_screen_mode.dart';
import '../../../core/media/media_urls.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../downloads/application/downloaded_lookup.dart';
import '../application/page_prefetcher.dart';
import '../application/viewer_controller.dart';
import 'widgets/viewer_chrome.dart';
import 'widgets/viewer_page_image.dart';
import 'widgets/volume_end_overlay.dart';

/// コミックビューア画面（右 → 左の RTL 固定）。
class ViewerScreen extends ConsumerStatefulWidget {
  const ViewerScreen({required this.volumeId, super.key});

  final int volumeId;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  late final PageController _pageController;
  late final AppLifecycleListener _lifecycleListener;

  /// dispose では ref を使えないため、初期化時に取っておく。
  late final ReadingScreenMode _screenMode;

  PagePrefetcher? _prefetcher;

  /// 先読みの前提条件（ZIP の世代）。変わったら作り直す
  /// （古い世代の URL を温め続けないため）。
  int? _prefetchFilesVersion;

  /// 次巻への遷移中（連打での二重遷移を防ぐ）。
  bool _movingToNextVolume = false;

  ViewerController get _controller =>
      ref.read(viewerControllerProvider(widget.volumeId).notifier);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // バックグラウンドへ移るときに進捗を送る（OS に殺されても残るように）。
    _lifecycleListener = AppLifecycleListener(
      onInactive: _flushProgressQuietly,
      onHide: _flushProgressQuietly,
    );

    // 全画面 + スリープ抑止。巻をまたぐ遷移では参照カウントで維持される。
    _screenMode = ref.read(readingScreenModeProvider);
    _screenMode.acquire();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _pageController.dispose();
    // 進捗の送信は provider 側の onDispose が行う（ここでは ref を使えない）。
    _screenMode.release();
    super.dispose();
  }

  /// 進捗の送信は best-effort。失敗しても操作を止めない。
  void _flushProgressQuietly() {
    _controller.flushProgress().catchError((Object _) {});
  }

  /// 状態のページ番号に表示を合わせる（シークバー / タップ操作の反映）。
  void _syncPageController(int page) {
    if (!_pageController.hasClients) return;
    final target = page - 1;
    final current =
        _pageController.page?.round() ?? _pageController.initialPage;
    if (current == target) return;
    // 連続したページ送りでアニメーションが渋滞しないよう、離れている場合は飛ばす。
    // アニメーションで送ると通り過ぎるページを全部組み立てて画像を要求する
    // （シークバーで遠くへ飛んだときに途中のページを読まない。#18）。
    if ((current - target).abs() > 1) {
      _pageController.jumpToPage(target);
    } else {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _prefetch(ViewerState state) {
    final filesVersion = state.volume.filesVersion;
    if (filesVersion == null || state.pageCount == 0) return;

    // ZIP 差し替えの後は URL / キャッシュキーを作り直す。
    if (_prefetchFilesVersion != filesVersion) {
      _prefetchFilesVersion = filesVersion;
      final urls = ref.read(mediaUrlsProvider);
      final precache = ref.read(pagePrecacherProvider);
      final files = state.volume.files;
      _prefetcher = PagePrefetcher(
        // 位置（1 始まり）を API のページ識別子に変換する
        // （表示側と同じキャッシュキーを温める）。
        precache: (position) => precache(
          context,
          ComicImageRequest.page(
            urls,
            volumeId: state.volume.id,
            page: files[position - 1],
            filesVersion: filesVersion,
          ),
        ),
      );
    }

    _prefetcher?.update(
      currentPage: state.currentPage,
      pageCount: state.pageCount,
    );
  }

  Future<void> _close() async {
    // 進捗を確定させてから閉じる（送信の失敗で閉じられなくなっては困る）。
    try {
      await _controller.flushProgress();
    } on Object {
      // 送れなかった進捗は次の機会に送る。
    }
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
      return;
    }
    router?.go(AppRoutes.library);
  }

  /// 次の巻へ進めるか。
  ///
  /// 圏外（端末の控えで開いている）ときは、次巻もダウンロード済みでなければ
  /// 開いても真っ白になる。遷移してからエラー画面を見せるより、巻末の時点で
  /// 「読めない」と分かる方がよい（#11）。
  bool _canOpenNextVolume(ViewerState state) {
    final nextVolumeId = state.volume.nextVolumeId;
    if (nextVolumeId == null) return false;
    if (!state.isStale) return true;
    return ref.watch(downloadedVolumeIdsProvider).contains(nextVolumeId);
  }

  Future<void> _moveToNextVolume() async {
    if (_movingToNextVolume) return;
    setState(() => _movingToNextVolume = true);
    try {
      int? nextVolumeId;
      try {
        nextVolumeId = await _controller.moveToNextVolume();
      } on Object {
        // 進捗を送れなくても次の巻へは進める。
        nextVolumeId = ref
            .read(viewerControllerProvider(widget.volumeId))
            .value
            ?.volume
            .nextVolumeId;
      }
      if (!mounted || nextVolumeId == null) return;
      // 巻を積み上げない（戻ると詳細 / 一覧に帰る）。
      context.pushReplacement(AppRoutes.viewer(nextVolumeId));
    } finally {
      if (mounted) setState(() => _movingToNextVolume = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = viewerControllerProvider(widget.volumeId);
    final async = ref.watch(provider);
    final state = async.value;

    if (state != null) {
      // ビルド中に PageView を触らない。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncPageController(state.currentPage);
        // キャッシュの準備待ちは `pagePrecacher` の内側で行う。
        _prefetch(state);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.viewerBackground,
      body: switch ((state, async.error)) {
        (null, final error?) => _ViewerMessage(
          icon: Icons.error_outline,
          message: apiErrorMessage(error),
          onRetry: _controller.reload,
          onClose: _close,
        ),
        (null, null) => const ViewerPageLoading(),
        (final state?, _) => _ViewerBody(
          state: state,
          pageController: _pageController,
          onClose: _close,
          isMovingToNextVolume: _movingToNextVolume,
          onNextVolume: _moveToNextVolume,
          canOpenNextVolume: _canOpenNextVolume(state),
          controller: _controller,
        ),
      },
    );
  }
}

class _ViewerBody extends StatelessWidget {
  const _ViewerBody({
    required this.state,
    required this.pageController,
    required this.onClose,
    required this.isMovingToNextVolume,
    required this.onNextVolume,
    required this.canOpenNextVolume,
    required this.controller,
  });

  final ViewerState state;
  final PageController pageController;
  final Future<void> Function() onClose;

  /// 次巻への遷移中（ボタンだけ無効にし、表示内容は変えない）。
  final bool isMovingToNextVolume;
  final Future<void> Function() onNextVolume;

  /// 次巻を開けるか（圏外で未ダウンロードなら開けない）。
  final bool canOpenNextVolume;

  final ViewerController controller;

  @override
  Widget build(BuildContext context) {
    // ZIP が無い巻（ページ 0 枚 / files_version 無し）は読めない。
    if (state.pageCount == 0) {
      return _ViewerMessage(
        icon: Icons.image_not_supported_outlined,
        message: 'この巻のページが見つかりませんでした',
        onClose: onClose,
      );
    }

    final filesVersion = state.volume.filesVersion!;

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: pageController,
          // 右 → 左（RTL 固定）。綴じ方向の設定は廃止済み。
          reverse: true,
          itemCount: state.slideCount,
          onPageChanged: (index) => controller.setPage(index + 1),
          itemBuilder: (context, index) {
            final page = index + 1;
            if (page > state.pageCount) {
              return VolumeEndOverlay(
                volume: state.volume,
                hasNextVolume: state.hasNextVolume,
                canOpenNextVolume: canOpenNextVolume,
                onNextVolume: canOpenNextVolume && !isMovingToNextVolume
                    ? () => onNextVolume()
                    : null,
                onClose: () => onClose(),
              );
            }
            return ViewerPageImage(
              volumeId: state.volume.id,
              page: state.volume.files[index],
              filesVersion: filesVersion,
              isCurrent: page == state.currentPage,
              onNext: controller.goToNextPage,
              onPrevious: controller.goToPreviousPage,
              onToggleMenu: controller.toggleMenu,
            );
          },
        ),
        if (state.isMenuVisible) ...[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ViewerHeader(state: state, onClose: () => onClose()),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            // ドラッグ中は番号だけ動き、離したときに 1 回だけ呼ばれる（#18）。
            child: ViewerFooter(state: state, onSeek: controller.setPage),
          ),
        ],
      ],
    );
  }
}

/// ビューア上の案内表示（読めない巻 / 取得失敗）。
///
/// 背景は常に黒なので、テーマ（ライト / ダーク）に依らず白系の文字で描く。
class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({
    required this.icon,
    required this.message,
    required this.onClose,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final Future<void> Function() onClose;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: () => onClose(),
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: '閉じる',
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white54, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  if (onRetry case final onRetry?)
                    OutlinedButton.icon(
                      onPressed: () => onRetry(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('再試行'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
