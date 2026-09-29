import 'package:comic_laz/domain/models/reading_book.dart';
import 'package:comic_laz/features/progress/domain/reading_progress.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/progress_fakes.dart';

void main() {
  const reading = [
    ReadingBook(
      bookId: 12,
      title: '進撃の巨人',
      volumeId: 340,
      volumeNumber: 3,
      currentPage: 3,
      maxPage: 30,
      progressPercent: 10,
    ),
    ReadingBook(
      bookId: 13,
      title: 'ベルセルク',
      volumeId: 500,
      volumeNumber: 1,
      currentPage: 5,
      maxPage: 20,
      progressPercent: 25,
    ),
  ];

  test('未送信のローカル進捗が「続きを読む」に反映される', () async {
    // オフラインで読み進めた巻をタップしたときに前のページへ戻らないため。
    final merged = applyLocalProgress(reading, {
      340: testProgress(volumeId: 340, currentPage: 24, maxPage: 30),
    });

    expect(merged.first.currentPage, 24);
    expect(merged.first.progressPercent, 80, reason: 'サーバーと同じ切り捨て');
    expect(merged.last.currentPage, 5, reason: '進捗が無い巻はそのまま');
  });

  test('送信済みのローカル進捗では上書きしない', () async {
    // 送信済みならサーバーの値が正（他端末の進捗が入っていることもある）。
    final merged = applyLocalProgress(reading, {
      340: testProgress(volumeId: 340, currentPage: 24, synced: true),
    });

    expect(merged.first.currentPage, 3);
  });

  test('進捗率は 0 ページの巻でも落ちない', () async {
    expect(testProgress(volumeId: 340, maxPage: 0).progressPercent, 0);
  });
}
