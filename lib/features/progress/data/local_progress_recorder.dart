import '../../viewer/data/progress_recorder.dart';
import '../application/progress_syncer.dart';
import '../data/progress_store.dart';

/// ページ送りをまずローカルへ書き、そのうえで送信を試みる [ProgressRecorder]（#12）。
///
/// 圏外でも記録は失われない。送信できたかどうかは行の `synced` で判断するので、
/// ビューアは「送れなかった進捗」を次の機会に送り直せる。
class LocalProgressRecorder implements ProgressRecorder {
  const LocalProgressRecorder({required this.store, required this.syncer});

  final ProgressStore store;
  final ProgressSyncer syncer;

  @override
  Future<void> savePage({
    required int volumeId,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  }) async {
    // 0 ページ（ZIP が無い）巻は読めないので記録しない。
    if (maxPage < 1) return;
    await store.save(
      volumeId: volumeId,
      // `min(page, files.length)`。巻末オーバーレイの番号を保存しない。
      currentPage: currentPage.clamp(1, maxPage),
      maxPage: maxPage,
      readAt: readAt,
    );
  }

  @override
  Future<bool> record({
    required int volumeId,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  }) async {
    if (maxPage < 1) return false;

    await savePage(
      volumeId: volumeId,
      currentPage: currentPage,
      maxPage: maxPage,
      readAt: readAt,
    );

    // オンラインならその場で送る。圏外なら未送信のまま残る。
    await syncer.sync();
    final saved = await store.find(volumeId);
    // 行が消えている（巻が消えた）場合も「これ以上送らない」= 記録済み扱い。
    return saved == null || saved.synced;
  }

  @override
  Future<int?> unsyncedPage(int volumeId) async {
    final saved = await store.find(volumeId);
    return saved != null && saved.isPending ? saved.currentPage : null;
  }
}
