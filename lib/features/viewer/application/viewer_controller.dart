import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show ProviderBase;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/cache/image_cache_store.dart';
import '../../../data/api/books_api.dart';
import '../../../domain/models/read_volume.dart';
import '../../history/application/history_controller.dart';
import '../../library/application/library_controller.dart';
import '../../mypage/application/stats_controller.dart';
import '../../title/application/book_detail_controller.dart';
import '../data/progress_recorder.dart';

part 'viewer_controller.freezed.dart';
part 'viewer_controller.g.dart';

/// ビューアの状態。
@freezed
abstract class ViewerState with _$ViewerState {
  const factory ViewerState({
    required ReadVolume volume,

    /// 表示中のページ（1 始まり）。`volume.files.length + 1` は巻末オーバーレイ。
    required int currentPage,

    /// ヘッダ / シークバーを表示しているか。
    @Default(false) bool isMenuVisible,
  }) = _ViewerState;

  const ViewerState._();

  /// 実ページ数（巻末オーバーレイを含まない）。
  ///
  /// ZIP が無い（`files_version` が無い）巻は読めないので 0 として扱う。
  /// そうしないと画像 URL を組み立てられず、ローディング表示のまま止まる。
  int get pageCount => volume.isEmpty ? 0 : volume.files.length;

  /// 巻末オーバーレイを表示中か。
  bool get isAtVolumeEnd => currentPage > pageCount;

  /// スワイプできる総数（実ページ + 巻末オーバーレイ）。
  int get slideCount => pageCount == 0 ? 0 : pageCount + 1;

  /// 次の巻があるか。
  bool get hasNextVolume => volume.nextVolumeId != null;
}

/// 送信待ちの進捗。
typedef PendingProgress = ({int volumeId, int page, int maxPage});

/// ビューアの読み込みとページ送り・進捗記録。
@Riverpod(retry: noAutoRetry)
class ViewerController extends _$ViewerController {
  /// dispose 後でも進捗を送れるよう、`ref` ではなく実体を持つ。
  ProgressRecorder? _recorder;

  /// 現在の進捗（`state` を読まずに送れるようにしておく）。
  PendingProgress? _pending;

  /// 最後に送信できたページ（同じ値を送り直さない）。
  int? _lastRecordedPage;

  /// 進行中の送信。
  Future<void>? _recording;

  @override
  Future<ViewerState> build(int volumeId) async {
    _recorder = ref.read(progressRecorderProvider);
    // 画面を離れるときに取りこぼさない（dispose 後は state を読めないので
    // `_pending` に持たせた値で送る）。
    ref.onDispose(flushProgress);

    final volume = await ref.read(booksApiProvider).fetchReadVolume(volumeId);
    final startPage = await _resolveStartPage(volume);

    _evictStaleImageCache(volume);

    final next = ViewerState(volume: volume, currentPage: startPage);
    _updatePending(next);
    return next;
  }

  /// 開始ページを決める。
  ///
  /// サーバーの `current_page` よりも**未送信のローカル進捗**を優先する（#12）。
  /// オフラインで読み進めた巻を開き直したときに、送れていない進捗が無かった
  /// ことにされて巻き戻るのを防ぐため。
  ///
  /// [_lastRecordedPage] は「送信済みのページ」なので、ローカル進捗から再開した
  /// 場合は `null` のままにしておく（閉じるときに送信を試みさせる）。
  Future<int> _resolveStartPage(ReadVolume volume) async {
    _lastRecordedPage = null;
    if (volume.isEmpty) return 1;

    final unsyncedPage = await _recorder?.unsyncedPage(volume.id);
    if (unsyncedPage != null) return volume.clampPage(unsyncedPage);

    final startPage = volume.clampPage(volume.currentPage);
    _lastRecordedPage = startPage;
    return startPage;
  }

  /// ZIP が差し替わっていたら、この巻の古い世代の画像キャッシュを捨てる（#8）。
  ///
  /// キーに `files_version` を含めているので古い画像を表示することは無いが、
  /// 消さないと二度と使われないファイルが容量を食い続ける。
  void _evictStaleImageCache(ReadVolume volume) {
    final filesVersion = volume.filesVersion;
    if (filesVersion == null) return;
    final evict = ref.read(staleCacheEvictorProvider);
    // 表示を待たせない。失敗しても読書は止めない（次に開いたときに再試行される）。
    unawaited(
      evict(
        volumeId: volume.id,
        keepFilesVersion: filesVersion,
      ).catchError((Object _) {}),
    );
  }

  /// ページ / 巻末オーバーレイへ移動する。
  void setPage(int page) {
    final current = state.value;
    if (current == null || current.slideCount == 0) return;

    final clamped = page.clamp(1, current.slideCount);
    if (clamped == current.currentPage) return;

    final next = current.copyWith(currentPage: clamped);
    _updatePending(next);
    // ページ送りごとに端末へ書く（送信は巻移動 / 閉じる / バックグラウンドで
    // まとめる）。表示を待たせないので待たない。
    _saveProgressLocally();
    state = AsyncValue.data(next);
  }

  /// 現在のページをローカルに保存する（#12）。
  ///
  /// 送信はしないので失敗しても何も起きない（次のページ送りで書き直される）。
  void _saveProgressLocally() {
    final pending = _pending;
    final recorder = _recorder;
    if (pending == null || recorder == null) return;
    unawaited(
      recorder
          .savePage(
            volumeId: pending.volumeId,
            currentPage: pending.page,
            maxPage: pending.maxPage,
            readAt: DateTime.now(),
          )
          .catchError((Object _) {}),
    );
  }

  /// 次のページへ（RTL では画面左側のタップ）。
  void goToNextPage() => setPage((state.value?.currentPage ?? 1) + 1);

  /// 前のページへ（RTL では画面右側のタップ）。
  void goToPreviousPage() => setPage((state.value?.currentPage ?? 1) - 1);

  void toggleMenu() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(isMenuVisible: !current.isMenuVisible),
    );
  }

  void hideMenu() {
    final current = state.value;
    if (current == null || !current.isMenuVisible) return;
    state = AsyncValue.data(current.copyWith(isMenuVisible: false));
  }

  /// 読み込みの再試行。
  Future<void> reload() async {
    final api = ref.read(booksApiProvider);
    final next = await AsyncValue.guard(() async {
      final volume = await api.fetchReadVolume(volumeId);
      final startPage = await _resolveStartPage(volume);
      final state = ViewerState(volume: volume, currentPage: startPage);
      _updatePending(state);
      _evictStaleImageCache(volume);
      return state;
    });
    if (!ref.mounted) return;
    state = next;
  }

  /// 進捗をサーバーへ送る。
  ///
  /// ページ送りのたびには送らず、巻の移動 / 画面を閉じる / バックグラウンド遷移で
  /// まとめて送る（Web 版と同じ方針。HDD サーバーへの書き込みを抑える）。
  Future<void> flushProgress() {
    final pending = _pending;
    final recorder = _recorder;
    // ZIP が無い（ページ 0 枚）巻は保存も送信もしない。
    if (pending == null || recorder == null) return Future.value();
    if (pending.page == _lastRecordedPage) return Future.value();

    // 同時に複数走らせない（連続したページ送り + 閉じる操作）。
    late final Future<void> guarded;
    final task = _record(pending, recorder, _recording);
    guarded = task.whenComplete(() {
      // 実際に保持しているのは whenComplete 後の future なので、それと比べる。
      if (identical(_recording, guarded)) _recording = null;
    });
    _recording = guarded;
    return task;
  }

  Future<void> _record(
    PendingProgress pending,
    ProgressRecorder recorder,
    Future<void>? previous,
  ) async {
    if (previous != null) {
      try {
        await previous;
      } on Object {
        // 前回の失敗は引きずらない（今回の送信を止めない）。
      }
    }
    final sent = await recorder.record(
      volumeId: pending.volumeId,
      currentPage: pending.page,
      maxPage: pending.maxPage,
      readAt: DateTime.now(),
    );
    if (!sent) return;
    // 送れなかった場合は記録済みにしない（次の機会に送り直す）。
    _lastRecordedPage = pending.page;
    _invalidateProgressViews(pending.volumeId);
  }

  /// 進捗を表示している画面に反映させる。
  ///
  /// ビューアは `push` で開くため、詳細 / 一覧 / 履歴 / 統計は生きたまま
  /// 古い進捗を表示し続ける。生きている画面だけ作り直す。
  void _invalidateProgressViews(int volumeId) {
    if (!ref.mounted) return;
    final bookId = state.value?.volume.book.id;

    final providers = <ProviderBase<Object?>>[
      if (bookId != null) bookDetailControllerProvider(bookId),
      libraryControllerProvider,
      historyControllerProvider,
      statsControllerProvider,
    ];
    for (final provider in providers) {
      // 表示していない画面を作り直すと無駄な取得が走るので、生きているものだけ。
      if (ref.exists(provider)) ref.invalidate(provider);
    }
  }

  /// 次の巻へ移動する。移動先の巻 ID を返す（無ければ `null`）。
  ///
  /// 連打で二重に遷移しないよう、呼び出し側は戻り値が `null` でないことを
  /// 確認してから遷移する。
  Future<int?> moveToNextVolume() async {
    final nextVolumeId = state.value?.volume.nextVolumeId;
    if (nextVolumeId == null) return null;

    // 今の巻の進捗を確定させてから移動する。
    await flushProgress();
    return nextVolumeId;
  }

  /// 巻末オーバーレイの番号（`files.length + 1`）は保存しない。
  void _updatePending(ViewerState next) {
    if (next.pageCount == 0) {
      _pending = null;
      return;
    }
    _pending = (
      volumeId: next.volume.id,
      page: next.volume.clampPage(next.currentPage),
      maxPage: next.pageCount,
    );
  }
}
