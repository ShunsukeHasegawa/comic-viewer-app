import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/api/books_api.dart';
import '../../../domain/models/book_detail.dart';
import '../../library/application/library_controller.dart';

part 'book_detail_controller.g.dart';

/// タイトル詳細の読み込みとお気に入り操作。
@Riverpod(retry: noAutoRetry)
class BookDetailController extends _$BookDetailController {
  @override
  Future<BookDetail> build(int bookId) {
    return ref.read(booksApiProvider).fetchBookDetail(bookId);
  }

  /// 再読み込み（プルリフレッシュ / 再試行）。
  Future<void> refresh() async {
    final api = ref.read(booksApiProvider);
    final next = await AsyncValue.guard(() => api.fetchBookDetail(bookId));
    if (!ref.mounted) return;
    state = next;
  }

  /// お気に入りを切り替える。
  ///
  /// 見た目を先に反映し、失敗したら元に戻す（タップの反応を待たせない）。
  /// 成功したらライブラリ側の一覧にも反映する（再取得はしない）。
  Future<void> toggleFavorite() async {
    final current = state.value;
    if (current == null) return;

    final next = !current.isFavorite;
    final api = ref.read(booksApiProvider);

    state = AsyncValue.data(current.copyWith(isFavorite: next));
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
