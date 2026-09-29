import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../progress/application/progress_syncer.dart';
import '../../progress/data/local_progress_recorder.dart';
import '../../progress/data/progress_store.dart';
import '../../progress/domain/reading_progress.dart';

part 'progress_recorder.g.dart';

/// 読書進捗の記録先。
///
/// 実装（#12）は「まず端末に書き、送れたら `synced` を立てる」ローカルキュー。
/// ビューアは送れたかどうかだけ見て、送れなかった進捗を次の機会に送り直す。
abstract interface class ProgressRecorder {
  /// ページ送りごとの保存。**端末に書くだけで送信はしない**。
  ///
  /// 送信は巻の移動 / 画面を閉じる / バックグラウンド遷移にまとめる（HDD の
  /// 自宅サーバーへの書き込みを抑える）が、保存はページ送りごとに行う。
  /// アプリが OS に落とされても読んだところが残るようにするため。
  Future<void> savePage({
    required int volumeId,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  });

  /// 進捗を記録する。**サーバーへ送れたか**を返す（ローカル保存は常に行う）。
  Future<bool> record({
    required int volumeId,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  });

  /// 端末に残っているこの巻の進捗（無ければ `null`）。
  ///
  /// オフラインで読み進めた巻を開き直したときに、サーバー由来の古いページから
  /// 再開して**手元の進捗を巻き戻さない**ために使う。
  ///
  /// 送信済み（`synced`）の行も返す。控えてある `ReadVolume`（#11）は「最後に
  /// オンラインで開いた時点」の `current_page` なので、そのあと読んで送信できた
  /// ページは入っていない。圏外で開き直したときに古いページから再開すると、
  /// そこからのページ送りが**新しい `read_at`** で保存され、復帰後の一括同期が
  /// サーバーの正しい進捗を巻き戻してしまう。
  Future<ReadingProgress?> localProgress(int volumeId);
}

@Riverpod(keepAlive: true)
ProgressRecorder progressRecorder(Ref ref) {
  final recorder = LocalProgressRecorder(
    store: ref.watch(progressStoreProvider),
    syncer: ref.watch(progressSyncerProvider),
    isSignedIn: ref.read(authControllerProvider) is AuthAuthenticated,
  );
  // ログアウト後に走るビューアの dispose で行を作り直さないよう、認証状態を
  // 先に流し込んでおく（記録時に `ref` を読むと、その時点で container が
  // 片付いていることがある）。
  ref.listen(authControllerProvider, (previous, next) {
    recorder.isSignedIn = next is AuthAuthenticated;
  });
  return recorder;
}
