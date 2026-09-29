import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/api/books_api.dart';
import '../../../domain/models/book_detail.dart';
import '../../downloads/application/downloaded_lookup.dart';
import '../../library/application/library_controller.dart';
import '../../offline/application/offline_metadata_gateway.dart';

part 'book_detail_controller.freezed.dart';
part 'book_detail_controller.g.dart';

/// タイトル詳細画面の表示データ。
@freezed
abstract class BookDetailData with _$BookDetailData {
  const factory BookDetailData({
    required BookDetail detail,

    /// サーバーに確認できず、端末に控えてある内容を表示している（#11）。
    ///
    /// この間は未ダウンロードの巻を開けないので、画面側は無効表示にする。
    @Default(false) bool isStale,
  }) = _BookDetailData;
}

/// タイトル詳細の読み込みとお気に入り操作。
@Riverpod(retry: noAutoRetry)
class BookDetailController extends _$BookDetailController {
  @override
  Future<BookDetailData> build(int bookId) {
    // ダウンロードが完了した時点の詳細を控える（#11）。
    // 「詳細を開く → ダウンロード」の順で操作されるので、取得時点ではまだ
    // ダウンロード済みではない。完了を待って控えないと、圏外で詳細が開けない。
    ref.listen(downloadedBookIdsProvider, (previous, next) {
      if (!next.contains(bookId)) return;
      if (previous != null && previous.contains(bookId)) return;
      _saveForOffline();
    });
    return _load();
  }

  /// 再読み込み（プルリフレッシュ / 再試行）。
  Future<void> refresh() async {
    final next = await AsyncValue.guard(_load);
    if (!ref.mounted) return;
    state = next;
  }

  /// 取得する。圏外では端末に控えた詳細を `isStale` つきで返す。
  ///
  /// 控えも無ければ例外をそのまま投げる（「オフラインでは開けない」ことを
  /// エラー表示で伝える。黙って空の詳細を見せない）。
  Future<BookDetailData> _load() async {
    final api = ref.read(booksApiProvider);
    final offline = ref.read(offlineMetadataGatewayProvider);

    try {
      final detail = await api.fetchBookDetail(bookId);
      await _tolerate(() => offline.saveBookDetail(detail));
      return BookDetailData(detail: detail);
    } on ApiException catch (error) {
      if (!error.isTransient) rethrow;
      final stored = await _tolerate(() => offline.readBookDetail(bookId));
      if (stored == null) rethrow;
      return BookDetailData(detail: stored, isStale: true);
    }
  }

  /// いま表示している詳細を控える（ダウンロード完了時）。
  void _saveForOffline() {
    final current = state.value;
    // 圏外で復元した内容を書き戻しても実害は無いが、意味も無いので触らない。
    if (current == null || current.isStale) return;
    unawaited(
      _tolerate(
        () => ref
            .read(offlineMetadataGatewayProvider)
            .saveBookDetail(current.detail),
      ),
    );
  }

  /// お気に入りを切り替える。
  ///
  /// 見た目を先に反映し、失敗したら元に戻す（タップの反応を待たせない）。
  /// 成功したらライブラリ側の一覧にも反映する（再取得はしない）。
  Future<void> toggleFavorite() async {
    final current = state.value;
    if (current == null) return;

    final next = !current.detail.isFavorite;
    final api = ref.read(booksApiProvider);

    state = AsyncValue.data(
      current.copyWith(detail: current.detail.copyWith(isFavorite: next)),
    );
    try {
      if (next) {
        await api.addFavorite(bookId);
      } else {
        await api.removeFavorite(bookId);
      }
    } on Object {
      if (!ref.mounted) return;
      // 失敗したら元の状態へ戻し、呼び出し側でメッセージを出す。
      state = AsyncValue.data(current);
      rethrow;
    }

    if (!ref.mounted) return;
    _syncLibrary(isFavorite: next);
  }

  /// 一覧が表示中ならその場で反映する。
  ///
  /// 表示していない場合は何もしない（次に開いたときに取得し直される）。
  /// ここで一覧を新規に構築すると、詳細を開くだけで一覧の再取得が走ってしまう。
  void _syncLibrary({required bool isFavorite}) {
    if (!ref.exists(libraryControllerProvider)) return;
    ref
        .read(libraryControllerProvider.notifier)
        .setFavorite(bookId: bookId, isFavorite: isFavorite);
  }

  /// 端末内の読み書きは best-effort（詳細の表示を止めない）。
  Future<T?> _tolerate<T>(Future<T> Function() task) async {
    try {
      return await task();
    } on Object {
      return null;
    }
  }
}

/// 続きから読む対象の巻。読みかけが無ければ最初の未読巻、それも無ければ 1 巻目。
BookVolume? resumeTargetOf(BookDetail detail) {
  if (detail.volumes.isEmpty) return null;

  final currentVolumeNumber = detail.readingProgress?.currentVolume;
  if (currentVolumeNumber != null) {
    for (final volume in detail.volumes) {
      // 読了済みの巻を「続きから」にしない（サーバーが読了後も
      // current_volume を返す場合に備える）。
      if (volume.volume == currentVolumeNumber && !volume.isFinished) {
        return volume;
      }
    }
  }

  for (final volume in detail.volumes) {
    if (!volume.isFinished) return volume;
  }
  return detail.volumes.first;
}
