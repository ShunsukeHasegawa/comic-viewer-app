import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show ProviderBase;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/cache/image_cache_store.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/api/books_api.dart';
import '../../../domain/models/read_volume.dart';
import '../../history/application/history_controller.dart';
import '../../library/application/library_controller.dart';
import '../../mypage/application/stats_controller.dart';
import '../../offline/application/offline_metadata_gateway.dart';
import '../../progress/domain/reading_progress.dart';
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

    /// サーバーに確認できず、端末の控えで開いている（#11）。
    ///
    /// この間に次巻へ進めるのは、次巻もダウンロード済みのときだけ。
    @Default(false) bool isStale,
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
    return _open();
  }

  /// 巻を開く（オンラインなら取得、圏外なら端末の控え）。
  Future<ViewerState> _open() async {
    final loaded = await _loadVolume();
    final startPage = await _resolveStartPage(
      loaded.volume,
      isStale: loaded.isStale,
    );

    _evictStaleImageCache(loaded.volume);

    final next = ViewerState(
      volume: loaded.volume,
      currentPage: startPage,
      isStale: loaded.isStale,
    );
    _updatePending(next);
    return next;
  }

  /// 巻情報を手に入れる。
  ///
  /// 通信できたときは端末にも控える（ダウンロード済みの巻だけ。#11）。
  /// 圏外では控えを使い、それも無ければ例外をそのまま投げる
  /// （ダウンロードしていない巻はオフラインで開けない）。
  Future<({ReadVolume volume, bool isStale})> _loadVolume() async {
    final api = ref.read(booksApiProvider);
    final offline = ref.read(offlineMetadataGatewayProvider);

    try {
      final volume = await api.fetchReadVolume(volumeId);
      await _tolerate(() => offline.saveVolume(volume));
      return (volume: volume, isStale: false);
    } on ApiException catch (error) {
      // 404（削除済み）や認証エラーは隠さない。
      if (!error.isTransient) rethrow;
      final stored = await _tolerate(() => offline.readVolume(volumeId));
      if (stored == null) rethrow;
      return (volume: stored, isStale: true);
    }
  }

  /// 端末内の読み書きは best-effort（読書を止めない）。
  Future<T?> _tolerate<T>(Future<T> Function() task) async {
    try {
      return await task();
    } on Object {
      return null;
    }
  }

  /// 開始ページを決める。
  ///
  /// サーバーの `current_page` よりも**未送信のローカル進捗**を優先する（#12）。
  /// オフラインで読み進めた巻を開き直したときに、送れていない進捗が無かった
  /// ことにされて巻き戻るのを防ぐため。
  ///
  /// [isStale] （= 控えた巻情報で開いた）のときは、**送信済み**のローカル進捗も
  /// 見る（#11 のレビュー指摘）。控えの `current_page` は「最後にオンラインで
  /// 開いた時点」の値なので、そのあと読んで送信できたページより古い。古い方から
  /// 再開すると、1 回ページを送っただけで**新しい `read_at`** の未送信行ができ、
  /// 復帰後の一括同期（クライアント申告の `read_at` 同士で比較する）でサーバーの
  /// 進捗が巻き戻ってしまう。どちらが新しいかは分からないので、進んでいる方を採る
  /// （他端末の進捗を取り込んだ控えも巻き戻さない）。
  ///
  /// [_lastRecordedPage] は「送信済みのページ」なので、未送信のローカル進捗から
  /// 再開した場合は `null` のままにしておく（閉じるときに送信を試みさせる）。
  ///
  /// 最後まで読んだ巻は 1 ページ目から始める（Web 版 `pages/book/view/[id].vue`
  /// の `activePage >= files.length` と同じ判定）。最終ページのまま再開すると、
  /// 読み終えた本を開くたびに巻末オーバーレイが出るだけになる。
  Future<int> _resolveStartPage(
    ReadVolume volume, {
    required bool isStale,
  }) async {
    _lastRecordedPage = null;
    if (volume.isEmpty) return 1;

    final local = await _readLocalProgress(volume.id);
    final resumePage = _resumePage(volume, local: local, isStale: isStale);

    if (resumePage >= volume.pageCount) {
      // 「送信済み」を 1 にして、開いただけでは進捗を送らせない。読み終えた巻を
      // 誤って開いて閉じただけで、サーバーの読了が 1 ページ目へ巻き戻るのを防ぐ
      // （未送信のローカル進捗も同じ理由で上書きしない）。ページを送れば
      // そこから記録が再開する。
      _lastRecordedPage = 1;
      return 1;
    }

    // 未送信の進捗から再開したときは「送信済み」を立てない（閉じるときに
    // 送信を試みさせる）。
    if (local != null && local.isPending) return resumePage;
    _lastRecordedPage = resumePage;
    return resumePage;
  }

  /// 続きから読むページ（読了判定を入れる前の値）。
  int _resumePage(
    ReadVolume volume, {
    required ReadingProgress? local,
    required bool isStale,
  }) {
    if (local != null && local.isPending) {
      return volume.clampPage(local.currentPage);
    }
    final serverPage = volume.clampPage(volume.currentPage);
    if (isStale && local != null && local.currentPage > serverPage) {
      return volume.clampPage(local.currentPage);
    }
    return serverPage;
  }

  /// 端末に残っているこの巻の進捗を読む。読めなければ `null`（サーバーの値で開く）。
  ///
  /// ローカル DB が壊れている / マイグレーションに失敗している場合でも、巻が
  /// 取れているなら読書は続けられるようにする。ここで throw すると build() が
  /// 失敗して「読み込みに失敗しました」のままになり、どの巻も開けなくなる。
  /// 一覧側（`LibraryController._localProgress`）と同じ扱い。
  Future<ReadingProgress?> _readLocalProgress(int volumeId) async {
    try {
      return await _recorder?.localProgress(volumeId);
    } on Object {
      return null;
    }
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
  ///
  /// 閉じた後に呼ばれても何もしない（ドラッグ途中でシークバーが外されたときの
  /// 移動は次のフレームに回すので、その間にビューアごと閉じられることがある）。
  void setPage(int page) {
    if (!ref.mounted) return;
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
    final next = await AsyncValue.guard(_open);
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
