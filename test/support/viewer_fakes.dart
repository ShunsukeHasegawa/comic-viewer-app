import 'package:comic_laz/core/device/screen_wake_lock.dart';
import 'package:comic_laz/features/viewer/data/progress_recorder.dart';

/// 送信内容を記録する [ProgressRecorder]。
class RecordingProgressRecorder implements ProgressRecorder {
  RecordingProgressRecorder({this.succeeds = true});

  /// 送信が成功するか（`false` なら記録済みにしない挙動を確認できる）。
  bool succeeds;

  final records =
      <({int volumeId, int currentPage, int maxPage, DateTime readAt})>[];

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
    return succeeds;
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
