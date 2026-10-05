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

  /// スライドで追いつける距離（ページ数）。これより離れていれば飛ばす。
  static const _maxSlideDistance = 3;

  /// ページ位置を「ちょうどそのページ」とみなす誤差。
  static const _pageEpsilon = 0.001;

  /// タップで送っているスライドの行き先（0 始まり）。スライド中でなければ null。
  int? _slideTarget;

  /// 古いスライドの完了で [_slideTarget] を消さないための通し番号。
  int _slideToken = 0;

  /// 指を置いた時点でスライド中だったか（[_onPointerDown]）。
  bool _tapStartedMidSlide = false;

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
  ///
  /// [resume] はスライド中のタップで止められたスライドを再開するとき。
  /// 止まった位置の四捨五入が行き先と同じでも、行き先まで送り切る。
  void _syncPageController(int page, {bool resume = false}) {
    if (!_pageController.hasClients) return;
    final target = page - 1;
    final current =
        _pageController.page ?? _pageController.initialPage.toDouble();
    if (resume) {
      if ((current - target).abs() < _pageEpsilon) return;
    } else {
      // 指でのスワイプ中は四捨五入で状態が先に進むので、表示に手を出さない。
      if (_slideTarget == target || current.round() == target) return;
    }
    // アニメーションで送ると通り過ぎるページを全部組み立てて画像を要求する
    // （シークバーで遠くへ飛んだときに途中のページを読まない。#18）。
    // 素早い連続タップで数ページ先行した分はスライドで追いつく。
    if ((current - target).abs() > _maxSlideDistance) {
      _slideToken++;
      _setSlideTarget(null);
      _pageController.jumpToPage(target);
      return;
    }
    final token = ++_slideToken;
    _setSlideTarget(target);
    _pageController
        .animateToPage(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        )
        // 指で止められた / 次のスライドに置き換えられたときも完了する。
        .whenComplete(() {
          if (token == _slideToken) _setSlideTarget(null);
        });
  }

  /// スライドの行き先を更新する。
  ///
  /// スライド中は PageView の指での操作を切る（[_ViewerBody.isTapSliding]）
  /// ので、切り替わるときは作り直す。
  void _setSlideTarget(int? target) {
    final wasSliding = _slideTarget != null;
    _slideTarget = target;
    if (mounted && wasSliding != (target != null)) setState(() {});
  }

  /// スワイプ / スライドで表示ページが変わった。
  ///
  /// タップで送っているスライドの途中のページは状態に書き戻さない。
  /// 書き戻すと、先行している状態が途中のページへ巻き戻り、その間の
  /// タップが 1 回分失われる。
  void _onPageChanged(int index) {
    if (_slideTarget != null) return;
    _controller.setPage(index + 1);
  }

  /// スクロールが止まったら、止まった位置を状態に合わせる。
  ///
  /// スライドを指で止めてそのまま戻すと、四捨五入のページが変わらず
  /// `onPageChanged` が来ないまま状態だけ先へ進んで残るため。
  void _onScrollEnd() {
    if (_slideTarget != null || !_pageController.hasClients) return;
    final page = _pageController.page;
    if (page == null) return;
    _controller.setPage(page.round() + 1);
  }

  /// 指を置いた時点でスライド中だったかを記録する。
  ///
  /// スライド中は `Scrollable` が子へのポインタを無視するため、各ページの
  /// タップ領域（`ViewerTapZones`）にタップが届かず、スライドが止まるだけになる。
  ///
  /// タップのスライドは動き出した最初のフレームではまだページの途中にいない
  /// ので、行き先が残っているか（止められても完了の通知は後で届く）も見る。
  /// スワイプ後の慣性で動いている間も子には届かないので、位置の端数も見る。
  void _onPointerDown(PointerDownEvent event) {
    final page = _pageController.hasClients ? _pageController.page : null;
    _tapStartedMidSlide =
        _slideTarget != null ||
        (page != null && (page - page.roundToDouble()).abs() > _pageEpsilon);
  }

  /// スライド中に始まったタップをページ送りとして扱う。
  ///
  /// 止まっているときのタップは各ページのタップ領域が先に受ける（より深い）。
  /// ここに来るのは誰も受けなかったタップ（巻末オーバーレイの余白など）なので
  /// 何もしない。
  void _onTapDuringSlide(double dx, double width) {
    if (!_tapStartedMidSlide) return;
    _tapStartedMidSlide = false;
    ViewerTapZones.dispatch(
      dx: dx,
      width: width,
      onNext: _controller.goToNextPage,
      onPrevious: _controller.goToPreviousPage,
      onToggleMenu: _controller.toggleMenu,
    );
    // 端のページで送れなかった / メニューの開閉だけのときも、止められた
    // スライドを行き先まで送り切る（途中で止まったままにしない）。
    final state = ref.read(viewerControllerProvider(widget.volumeId)).value;
    if (state != null) _syncPageController(state.currentPage, resume: true);
  }

  /// シークバーでのページ移動。
  ///
  /// ドラッグの途中でシークバーが外されると、移動は次のフレームに回る
  /// （`ViewerFooter`）。それがビューアごと閉じた（戻る）ためなら移動しない。
  /// 確定していない数十ページ先の位置を進捗として保存・送信してしまうため。
  void _seek(int page) {
    // 閉じる遷移はドラッグを打ち切り、Slider は離したときと同じ onChangeEnd を
    // 呼ぶ。そのときにも移動しない（閉じ始めた時点で今の画面ではなくなる）。
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _controller.setPage(page);
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
          onSeek: _seek,
          onPageChanged: _onPageChanged,
          onScrollEnd: _onScrollEnd,
          onPointerDown: _onPointerDown,
          onTapDuringSlide: _onTapDuringSlide,
          isTapSliding: _slideTarget != null,
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
    required this.onSeek,
    required this.onPageChanged,
    required this.onScrollEnd,
    required this.onPointerDown,
    required this.onTapDuringSlide,
    required this.isTapSliding,
  });

  /// タップで送るスライドの最中か。
  ///
  /// その間は PageView の指での操作を切る。切らないと、次のタップで指を
  /// 置いた瞬間に PageView がスライドを掴み、離すまで止めてしまう
  /// （回数分は送れても、タップのたびに一瞬止まって見える）。
  final bool isTapSliding;

  /// シークバーでのページ移動（[_ViewerScreenState._seek]）。
  final ValueChanged<int> onSeek;

  /// 表示ページの変化（0 始まり。[_ViewerScreenState._onPageChanged]）。
  final ValueChanged<int> onPageChanged;
  final VoidCallback onScrollEnd;

  /// スライド中のタップの受け口（[_ViewerScreenState._onTapDuringSlide]）。
  final ValueChanged<PointerDownEvent> onPointerDown;
  final void Function(double dx, double width) onTapDuringSlide;

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
        // スライド中は PageView の子にタップが届かないので、外側で受ける
        // （届かないとスライドが止まるだけで、素早い連続タップが失われる）。
        LayoutBuilder(
          builder: (context, constraints) => Listener(
            onPointerDown: onPointerDown,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) => onTapDuringSlide(
                details.localPosition.dx,
                constraints.maxWidth,
              ),
              child: NotificationListener<ScrollEndNotification>(
                onNotification: (notification) {
                  if (notification.depth == 0) onScrollEnd();
                  return false;
                },
                child: PageView.builder(
                  controller: pageController,
                  // 右 → 左（RTL 固定）。綴じ方向の設定は廃止済み。
                  reverse: true,
                  physics: isTapSliding
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  itemCount: state.slideCount,
                  onPageChanged: onPageChanged,
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
              ),
            ),
          ),
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
            child: ViewerFooter(state: state, onSeek: onSeek),
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
