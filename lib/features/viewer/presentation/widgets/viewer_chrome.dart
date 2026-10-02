import 'package:flutter/material.dart';

import '../../application/viewer_controller.dart';

/// ビューアのヘッダ（閉じる / タイトル・巻数）。
class ViewerHeader extends StatelessWidget {
  const ViewerHeader({required this.state, required this.onClose, super.key});

  final ViewerState state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: '閉じる',
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.volume.book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  Text(
                    '${state.volume.volume} 巻',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// ページ位置の表示とシークバー（RTL: 右が 1 ページ目）。
///
/// **ドラッグ中は表示（ページ番号）だけを動かし、離したときに 1 回だけ移動する**
/// （#18。Web 版の `@input` / `@change` と同じ分担）。ドラッグの刻みごとに
/// 移動すると、通り過ぎた途中のページを全部（先読みの窓ごと）自宅サーバーへ
/// 要求し、飛び先のページがその後ろに並んで表示が遅れる。進捗の端末保存も
/// 刻みごとに走る。
class ViewerFooter extends StatefulWidget {
  const ViewerFooter({required this.state, required this.onSeek, super.key});

  final ViewerState state;

  /// スライダーを離したときのページ移動（ドラッグの途中では呼ばない）。
  final ValueChanged<int> onSeek;

  @override
  State<ViewerFooter> createState() => _ViewerFooterState();
}

class _ViewerFooterState extends State<ViewerFooter> {
  /// ドラッグ中の位置。`null` ならドラッグしていない（状態のページを出す）。
  int? _dragPage;

  @override
  void dispose() {
    // メニューが閉じられる（ドラッグ中に別の指で中央をタップ）などで、ドラッグの
    // 途中に外されると Slider は onChangeEnd を呼ばない（指を離した時点で
    // 既に unmount 済みのため）。見せていた番号を黙って捨てないよう、外されたときに
    // 最後の位置へ移動する。dispose の最中に provider を変えると、それを見ている
    // ウィジェットの再構築がツリーの確定中に走ってしまうので次のフレームへ回す。
    final pending = _dragPage;
    if (pending != null) {
      final onSeek = widget.onSeek;
      WidgetsBinding.instance.addPostFrameCallback((_) => onSeek(pending));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slideCount = widget.state.slideCount;
    final page = _dragPage ?? widget.state.currentPage;

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              // 「現在 / 全ページ + 1」（巻末オーバーレイを含む Web 版の表記）。
              Text(
                '$page / $slideCount',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: Directionality(
                  // 右から左へ読むので、シークバーも右端が 1 ページ目。
                  textDirection: TextDirection.rtl,
                  child: Slider(
                    value: page.clamp(1, slideCount).toDouble(),
                    min: 1,
                    max: slideCount.toDouble(),
                    divisions: slideCount > 1 ? slideCount - 1 : null,
                    label: '$page',
                    // タップ / 支援技術の操作でも start → changed → end の順で
                    // 呼ばれるので、移動は end に寄せてよい。
                    onChangeStart: (value) =>
                        setState(() => _dragPage = value.round()),
                    onChanged: (value) {
                      final next = value.round();
                      if (next != _dragPage) setState(() => _dragPage = next);
                    },
                    onChangeEnd: (value) {
                      widget.onSeek(value.round());
                      if (mounted) setState(() => _dragPage = null);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// タップ操作の 3 分割（左 = 次ページ / 右 = 前ページ / 中央 = メニュー）。
///
/// RTL 固定なので「次」は画面左側。綴じ方向の設定は廃止済み。
///
/// **ページ画像を包む形で使う**（`InteractiveViewer` の内側）。上に重ねると
/// ページ読み込み失敗時の「再読み込み」や巻末オーバーレイのボタンが押せず、
/// `InteractiveViewer` より外側だとタップがピンチ操作の認識器に食われる。
class ViewerTapZones extends StatelessWidget {
  const ViewerTapZones({
    required this.child,
    required this.onNext,
    required this.onPrevious,
    required this.onToggleMenu,
    super.key,
  });

  final Widget child;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onToggleMenu;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 画像自体はタップを扱わないので、ここで確実に受ける。
      // 内側のボタン（再読み込みなど）はより深い位置にあるので優先される。
      behavior: HitTestBehavior.opaque,
      // ダブルタップ判定を入れると単純なタップが 300ms 遅れるため入れない
      // （InteractiveViewer にダブルタップ拡大は無いので抑止も不要）。
      onTapUp: (details) => _handleTap(context, details),
      // 画面全体でタップを受ける（画像の実サイズに縮まないようにする）。
      child: SizedBox.expand(child: child),
    );
  }

  void _handleTap(BuildContext context, TapUpDetails details) {
    final width = context.size?.width ?? 0;
    if (width <= 0) return;

    final ratio = details.localPosition.dx / width;
    if (ratio < 1 / 3) {
      onNext();
    } else if (ratio > 2 / 3) {
      onPrevious();
    } else {
      onToggleMenu();
    }
  }
}
