import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/comic_image_loader.dart';

/// 一時キャッシュ経由でコミック画像を表示する。
///
/// - **読み込みが終わるまで画像を出さない**（途中まで描かれた JPEG を見せない）
/// - 失敗したら [errorBuilder]（呼び出し側で再読み込みの導線を出す）
/// - [decodeToLayout] なら表示する大きさまで縮めてデコードする
class ComicImage extends ConsumerStatefulWidget {
  const ComicImage({
    required this.request,
    required this.loadingBuilder,
    required this.errorBuilder,
    this.fit = BoxFit.cover,
    this.fadeInDuration,
    this.onShown,
    this.decodeToLayout = false,
    super.key,
  });

  final ComicImageRequest request;

  /// キャッシュの準備中 / ダウンロード中 / デコード中の表示。
  final WidgetBuilder loadingBuilder;

  final Widget Function(BuildContext context, Object error) errorBuilder;

  final BoxFit fit;

  /// 指定すると、読み込めた画像をこの時間で溶かして出す（パッと切り替えない）。
  /// メモリ上のキャッシュから同期で出せたときは溶かさない。
  final Duration? fadeInDuration;

  /// 画像が見えきった（溶かし終えた）ときに呼ぶ。下に敷いたつなぎの層を
  /// 外す合図に使う。再構築のたびに呼ばれうるので、受け手が 1 度に絞る。
  final VoidCallback? onShown;

  /// レイアウトの大きさ × devicePixelRatio まで縮めてデコードする（#28）。
  /// サムネイルと背景用。ビューアのページは拡大に耐える解像度が要るので
  /// 使わない（既定の `false` は原寸）。
  final bool decodeToLayout;

  /// デコードの大きさを刻む幅（物理ピクセル）。少しの大きさの違いで
  /// 別の画像として読み直さない（`ImageCache` のキーが大きさで変わるため）。
  @visibleForTesting
  static const decodeStep = 128;

  /// レイアウトの制約から決めるデコードの枠。大きさが決まらない
  /// （無限 / 0）ときは `null`（原寸）にする。
  @visibleForTesting
  static ({int width, int height})? decodeBoxFor(
    BoxConstraints constraints,
    double devicePixelRatio,
  ) {
    final size = constraints.biggest;
    if (!size.isFinite || size.isEmpty) return null;
    int quantize(double logical) {
      final physical = (logical * devicePixelRatio).ceil();
      return ((physical + decodeStep - 1) ~/ decodeStep) * decodeStep;
    }

    return (width: quantize(size.width), height: quantize(size.height));
  }

  @override
  ConsumerState<ComicImage> createState() => _ComicImageState();
}

class _ComicImageState extends ConsumerState<ComicImage> {
  /// これまでに使ったデコードの枠（同じ画像の間は大きくする方向にしか変えない）。
  ///
  /// 枠が変わると別の画像として読み直し、読み込み中の表示に戻る。縮んだときまで
  /// 読み直すとちらつくだけなので、大きいほうを使い続ける。
  ({int width, int height})? _decodeBox;
  String? _decodeBoxKey;

  ({int width, int height})? _grownDecodeBox(({int width, int height})? next) {
    final key = widget.request.cacheKey;
    final current = _decodeBoxKey == key ? _decodeBox : null;
    final merged = next == null || current == null
        ? next ?? current
        : (
            width: math.max(next.width, current.width),
            height: math.max(next.height, current.height),
          );
    _decodeBox = merged;
    _decodeBoxKey = key;
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final loader = ref.watch(comicImageLoaderProvider);

    // DB / キャッシュディレクトリの用意が終わるまでは取得を始められない。
    return switch ((loader.value, loader.error)) {
      (null, final error?) => widget.errorBuilder(context, error),
      (null, null) => widget.loadingBuilder(context),
      (final loader?, _) when widget.decodeToLayout => LayoutBuilder(
        builder: (context, constraints) => _image(
          loader,
          decodeBox: _grownDecodeBox(
            ComicImage.decodeBoxFor(
              constraints,
              MediaQuery.devicePixelRatioOf(context),
            ),
          ),
        ),
      ),
      (final loader?, _) => _image(loader),
    };
  }

  Widget _image(
    ComicImageLoader loader, {
    ({int width, int height})? decodeBox,
  }) {
    final ComicImage(
      :loadingBuilder,
      :errorBuilder,
      :fadeInDuration,
      :onShown,
    ) = widget;
    return Image(
      image: ComicImageProvider(
        loader: loader,
        request: widget.request,
        decodeBox: decodeBox,
      ),
      fit: widget.fit,
      // 1 フレーム目が来るまでは「読み込み中」。
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          _notifyShownAfterFrame();
          return child;
        }
        final duration = fadeInDuration;
        if (duration == null) {
          if (frame == null) return loadingBuilder(context);
          _notifyShownAfterFrame();
          return child;
        }
        // 子の数と並びを変えない（AnimatedOpacity の状態を引き継いで溶かす）。
        return Stack(
          fit: StackFit.passthrough,
          children: [
            if (frame == null)
              loadingBuilder(context)
            else
              const SizedBox.shrink(),
            AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: duration,
              curve: Curves.easeOut,
              onEnd: frame == null ? null : onShown,
              child: child,
            ),
          ],
        );
      },
      errorBuilder: (context, error, _) => errorBuilder(context, error),
    );
  }

  /// 描画中（frameBuilder の中）に呼び手の状態を変えさせない。
  void _notifyShownAfterFrame() {
    final onShown = widget.onShown;
    if (onShown == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => onShown());
  }
}
