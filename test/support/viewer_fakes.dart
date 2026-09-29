import 'package:comic_laz/core/device/screen_wake_lock.dart';
import 'package:comic_laz/features/viewer/data/progress_recorder.dart';

/// 送信内容を記録する [ProgressRecorder]。
class RecordingProgressRecorder implements ProgressRecorder {
  RecordingProgressRecorder({this.succeeds = true});

  /// 送信が成功するか（`false` なら記録済みにしない挙動を確認できる）。
  bool succeeds;

  final records =
      <({int volumeId, int currentPage, int maxPage, DateTime readAt})>[];

  /// 未送信として残っているローカル進捗（巻 ID → ページ）。
  ///
  /// ビューアが「サーバーの値より手元の未送信進捗を優先する」ことを試すために使う。
  final unsyncedPages = <int, int>{};

  /// ローカル保存（送信しない）だけを受けたページ。
  final saved = <({int volumeId, int currentPage, int maxPage})>[];

  /// `unsyncedPage` で投げる例外（ローカル DB が読めない状況の再現）。
  Object? unsyncedPageError;

  @override
  Future<void> savePage({
    required int volumeId,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  }) async {
    saved.add((volumeId: volumeId, currentPage: currentPage, maxPage: maxPage));
    unsyncedPages[volumeId] = currentPage;
  }

  @override
  Future<bool> record({
    required int volumeId,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  }) async {
    records.add((
      volumeId: volumeId,
      currentPage: currentPage,
      maxPage: maxPage,
      readAt: readAt,
    ));
    if (succeeds) {
      unsyncedPages.remove(volumeId);
    } else {
      // 送れなかった進捗は端末に残る（次に開いたときの再開位置になる）。
      unsyncedPages[volumeId] = currentPage;
    }
    return succeeds;
  }

  @override
  Future<int?> unsyncedPage(int volumeId) async {
    if (unsyncedPageError case final error?) throw error;
    return unsyncedPages[volumeId];
  }
}

/// 呼び出しだけ記録する [ScreenWakeLock]。
class FakeScreenWakeLock implements ScreenWakeLock {
  bool enabled = false;
  int enableCount = 0;
  int disableCount = 0;

  @override
  Future<void> enable() async {
    enabled = true;
    enableCount++;
  }

  @override
  Future<void> disable() async {
    enabled = false;
    disableCount++;
  }
}
