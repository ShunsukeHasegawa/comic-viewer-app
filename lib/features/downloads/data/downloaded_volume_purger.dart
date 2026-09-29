import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/session_data_purger.dart';
import '../application/download_queue.dart';

part 'downloaded_volume_purger.g.dart';

/// ログアウト / セッション失効でダウンロード済みの巻を捨てる（#15）。
///
/// 一時キャッシュ（#8）と違い、ダウンロードは明示的に落としたものなので普段は
/// 自動で消さない。ただしログアウトは別で、端末に前のユーザーのコミックが
/// 残っていると次のユーザーがオフラインで読めてしまう。
///
/// 走行中のダウンロードも `DownloadQueue` 側で止め、破棄より前に始まった取得が
/// 後から書き戻さないよう世代で弾く。
class DownloadedVolumePurger implements SessionDataPurger {
  const DownloadedVolumePurger(this._purge);

  /// ログアウトまでキュー（DB / ディレクトリ）を作らせないため遅延させる。
  final Future<void> Function() _purge;

  @override
  String get debugLabel => 'downloaded volumes';

  /// 数 GB を落とし直させることになるので、セッションの終わり / ユーザー切り替え
  /// だけで消す（`safe_mode` の変更では消さない。#11 のレビュー指摘）。
  @override
  bool get purgesRefetchableOnly => false;

  @override
  Future<void> purgeSessionData() => _purge();
}

@Riverpod(keepAlive: true)
SessionDataPurger downloadedVolumePurger(Ref ref) => DownloadedVolumePurger(
  () => ref.read(downloadQueueProvider.notifier).purgeAll(),
);
