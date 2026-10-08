import 'package:comic_laz/core/device/screen_wake_lock.dart';
import 'package:comic_laz/features/progress/domain/reading_progress.dart';
import 'package:comic_laz/features/viewer/data/open_volume_store.dart';
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

  /// 送信済みのローカル進捗（巻 ID → ページ）。
  ///
  /// 控えた巻情報（#11）より新しい「送信済み」の行から再開できることを試すために使う。
  final syncedPages = <int, int>{};

  /// ローカル保存（送信しない）だけを受けたページ。
  final saved = <({int volumeId, int currentPage, int maxPage})>[];

  /// `localProgress` で投げる例外（ローカル DB が読めない状況の再現）。
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
      syncedPages[volumeId] = currentPage;
    } else {
      // 送れなかった進捗は端末に残る（次に開いたときの再開位置になる）。
      unsyncedPages[volumeId] = currentPage;
    }
    return succeeds;
  }

  @override
  Future<ReadingProgress?> localProgress(int volumeId) async {
    if (unsyncedPageError case final error?) throw error;
    if (unsyncedPages[volumeId] case final page?) {
      return _row(volumeId, page, synced: false);
    }
    if (syncedPages[volumeId] case final page?) {
      return _row(volumeId, page, synced: true);
    }
    return null;
  }

  ReadingProgress _row(int volumeId, int page, {required bool synced}) =>
      ReadingProgress(
        volumeId: volumeId,
        currentPage: page,
        maxPage: page,
        readAt: DateTime.utc(2026, 9, 25, 10),
        synced: synced,
      );
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

/// メモリ上に持つ [OpenVolumeStore]（drift を触らない）。
class InMemoryOpenVolumeStore implements OpenVolumeStore {
  InMemoryOpenVolumeStore([this.stored]);

  OpenVolume? stored;

  /// 読み込みを失敗させる（尋ねずに起動を続けることの確認用）。
  Object? readError;

  int clearCount = 0;

  @override
  Future<OpenVolume?> read() async {
    if (readError case final error?) throw error;
    return stored;
  }

  @override
  Future<void> save(OpenVolume volume) async => stored = volume;

  @override
  Future<void> clearIfVolume(int volumeId) async {
    if (stored?.volumeId != volumeId) return;
    await clear();
  }

  @override
  Future<void> clear() async {
    clearCount++;
    stored = null;
  }
}
