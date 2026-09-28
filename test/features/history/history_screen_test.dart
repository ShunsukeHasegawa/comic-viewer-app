import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/widgets/error_view.dart';
import 'package:comic_laz/data/api/paginated.dart';
import 'package:comic_laz/domain/models/reading_book.dart';
import 'package:comic_laz/features/history/application/history_controller.dart';
import 'package:comic_laz/features/history/presentation/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';
import '../../support/test_scope.dart';

HistoryEntry entry(int id, {bool isFinished = false}) => HistoryEntry(
  id: id,
  bookId: 12,
  title: '進撃の巨人',
  volume: id - 339,
  currentPage: isFinished ? 190 : 12,
  maxPage: 190,
  isFinished: isFinished,
  updatedAt: DateTime.utc(2026, 9, 25, 1, 0),
);

/// ページ送りできる履歴 API。
class PagedUserApi extends FakeUserApi {
  PagedUserApi(this.pages);

  final List<List<HistoryEntry>> pages;
  final requestedPages = <int>[];
  ApiException? error;

  @override
  Future<Paginated<HistoryEntry>> fetchHistory({int page = 1}) async {
    requestedPages.add(page);
    if (error case final error?) throw error;
    return Paginated(
      items: pages[page - 1],
      currentPage: page,
      lastPage: pages.length,
      total: pages.expand((p) => p).length,
    );
  }
}

Future<ProviderContainer> pumpHistory(
  WidgetTester tester, {
  FakeUserApi? userApi,
}) async {
  final container = createContainer(userApi: userApi ?? FakeUserApi());
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HistoryScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('履歴を表示する', (tester) async {
    await pumpHistory(
      tester,
      userApi: FakeUserApi(history: [entry(340), entry(341, isFinished: true)]),
    );

    expect(find.textContaining('1 巻'), findsOneWidget);
    expect(find.textContaining('読了'), findsOneWidget);
    expect(find.textContaining('12 / 190 ページ'), findsOneWidget);
  });

  testWidgets('履歴が無ければ空表示', (tester) async {
    await pumpHistory(tester);

    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.text('まだ読書履歴がありません。'), findsOneWidget);
  });

  testWidgets('末尾までスクロールすると次のページを読み込む', (tester) async {
    final api = PagedUserApi([
      [for (var i = 0; i < 10; i++) entry(340 + i)],
      [for (var i = 10; i < 15; i++) entry(340 + i)],
    ]);
    final container = await pumpHistory(tester, userApi: api);

    expect(api.requestedPages, [1]);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(api.requestedPages, [1, 2]);
    final state = container.read(historyControllerProvider).value!;
    expect(state.entries, hasLength(15));
    expect(state.hasMore, isFalse);
  });

  testWidgets('画面に収まる件数でもボタンで次のページを読める', (tester) async {
    // スクロールが発生しないので、ボタンが無いと 2 ページ目に到達できない
    final api = PagedUserApi([
      [entry(340)],
      [entry(341)],
    ]);
    final container = await pumpHistory(tester, userApi: api);

    await tester.tap(find.text('もっと読み込む'));
    await tester.pumpAndSettle();

    expect(api.requestedPages, [1, 2]);
    expect(
      container.read(historyControllerProvider).value!.entries,
      hasLength(2),
    );
  });

  testWidgets('最後のページまで読んだら追加読み込みしない', (tester) async {
    final api = PagedUserApi([
      [entry(340)],
    ]);
    final container = await pumpHistory(tester, userApi: api);

    await container.read(historyControllerProvider.notifier).loadMore();
    await tester.pumpAndSettle();

    expect(api.requestedPages, [1]);
  });

  testWidgets('追加読み込みが失敗しても表示中の履歴は残す', (tester) async {
    final api = PagedUserApi([
      [for (var i = 0; i < 10; i++) entry(340 + i)],
      [entry(350)],
    ]);
    final container = await pumpHistory(tester, userApi: api);

    api.error = const NetworkException();
    await container.read(historyControllerProvider.notifier).loadMore();
    await tester.pumpAndSettle();

    final state = container.read(historyControllerProvider).value!;
    expect(state.entries, hasLength(10));
    expect(state.isLoadingMore, isFalse);
    expect(state.loadMoreError, isA<NetworkException>());

    // 末尾に理由と再試行が出る
    await tester.scrollUntilVisible(find.text('再試行'), 200);
    expect(find.text('ネットワークに接続できませんでした。'), findsOneWidget);

    api.error = null;
    await tester.tap(find.text('再試行'));
    await tester.pumpAndSettle();
    expect(
      container.read(historyControllerProvider).value!.entries,
      hasLength(11),
    );
  });

  testWidgets('追加読み込みの失敗後はスクロールで自動再試行しない', (tester) async {
    final api = PagedUserApi([
      [for (var i = 0; i < 10; i++) entry(340 + i)],
      [entry(350)],
    ]);
    final container = await pumpHistory(tester, userApi: api);

    api.error = const NetworkException();
    await container.read(historyControllerProvider.notifier).loadMore();
    await tester.pumpAndSettle();
    expect(api.requestedPages, [1, 2]);

    // 末尾で何度こすっても叩き直さない（自宅サーバーへの連打を避ける）
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(api.requestedPages, [1, 2]);
  });

  testWidgets('初回の失敗はエラー表示 + 再試行', (tester) async {
    final api = PagedUserApi([
      [entry(340)],
    ])..error = const NetworkException();
    final container = await pumpHistory(tester, userApi: api);

    expect(find.byType(ErrorView), findsOneWidget);

    api.error = null;
    await container.read(historyControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsNothing);
    expect(find.textContaining('1 巻'), findsOneWidget);
  });
}
