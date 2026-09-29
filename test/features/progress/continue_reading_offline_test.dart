import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/domain/models/reading_book.dart';
import 'package:comic_laz/features/library/application/library_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';
import '../../support/progress_fakes.dart';
import '../../support/test_scope.dart';

void main() {
  test('「続きを読む」はオフラインでもローカル進捗のページを指す', () async {
    // サーバーの一覧は圏外へ出る前の値（3 ページ）のまま。
    final container = createContainer(
      userApi: FakeUserApi(
        reading: const [
          ReadingBook(
            bookId: 12,
            title: '進撃の巨人',
            volumeId: 340,
            volumeNumber: 3,
            currentPage: 3,
            maxPage: 30,
            progressPercent: 10,
          ),
        ],
      ),
      progressStore: InMemoryProgressStore([
        testProgress(volumeId: 340, currentPage: 24, maxPage: 30),
      ]),
    );
    addTearDown(container.dispose);

    final data = await container.read(libraryControllerProvider.future);

    expect(data.reading.single.currentPage, 24);
    expect(data.reading.single.progressPercent, 80);
  });

  test('一覧が取れなくてもローカル進捗の反映で落ちない', () async {
    // 圏外（`fetchReading` が失敗）では前回の一覧が無いので空になる。
    // 一覧そのものの永続キャッシュは #11。
    final container = createContainer(
      userApi: FakeUserApi()..readingError = const NetworkException(),
      progressStore: InMemoryProgressStore([
        testProgress(volumeId: 340, currentPage: 24),
      ]),
    );
    addTearDown(container.dispose);

    final data = await container.read(libraryControllerProvider.future);

    expect(data.reading, isEmpty);
  });
}
