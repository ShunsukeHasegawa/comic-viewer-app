import 'package:comic_laz/core/router/app_router.dart';
import 'package:comic_laz/core/router/app_routes.dart';
import 'package:comic_laz/core/router/not_found_screen.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/domain/models/read_volume.dart';
import 'package:comic_laz/features/library/presentation/widgets/resume_reading_prompt_listener.dart';
import 'package:comic_laz/features/title/presentation/title_detail_screen.dart';
import 'package:comic_laz/features/viewer/application/resume_reading_prompt.dart';
import 'package:comic_laz/features/viewer/data/open_volume_store.dart';
import 'package:comic_laz/features/viewer/presentation/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/api_fakes.dart';
import '../../support/auth_fakes.dart';
import '../../support/test_scope.dart';
import '../../support/viewer_fakes.dart';

const _openVolume = OpenVolume(
  bookId: 12,
  volumeId: 340,
  title: '進撃の巨人',
  volume: 3,
);

final _detail = BookDetail(
  id: 12,
  title: '進撃の巨人',
  volumes: [
    const BookVolume(id: 339, volume: 2, thumbnail: '/books/thumbnail/339?m=1'),
    const BookVolume(id: 340, volume: 3, thumbnail: '/books/thumbnail/340?m=1'),
  ],
);

final _readVolume = ReadVolume(
  id: 340,
  volume: 3,
  files: const [1, 2, 3],
  filesVersion: 1,
  book: const Book(id: 12, title: '進撃の巨人'),
);

Future<GoRouter> _pumpApp(
  WidgetTester tester,
  InMemoryOpenVolumeStore store, {
  String location = AppRoutes.library,
  FakeBooksApi? booksApi,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: buildRoutes(),
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    wrapWithScope(
      MaterialApp.router(routerConfig: router),
      overrides: testOverrides(
        authApi: MockAuthApi(),
        booksApi:
            booksApi ??
            FakeBooksApi(bookDetail: _detail, readVolume: _readVolume),
        openVolumeStore: store,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('前回読んでいた途中ならホームでタイトル・巻数・その巻のサムネイルを添えて尋ねる', (tester) async {
    await _pumpApp(tester, InMemoryOpenVolumeStore(_openVolume));

    final dialog = find.byType(ResumeReadingDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('進撃の巨人')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('3 巻')),
      findsOneWidget,
    );
    // 表紙（最新巻）ではなく、読んでいた巻のサムネイルを出す。
    final thumbnail = tester.widget<StubThumbnail>(
      find.descendant(of: dialog, matching: find.byType(StubThumbnail)),
    );
    expect(
      thumbnail.request.url.toString(),
      contains('/books/thumbnail/340?m=1'),
    );
  });

  testWidgets('ダイアログは中身の高さに収め、ボタンは横に並べる（画面いっぱいに伸ばさない）', (tester) async {
    await _pumpApp(tester, InMemoryOpenVolumeStore(_openVolume));

    final screen = tester.getSize(find.byType(MaterialApp));
    // Dialog 自体は画面全体を占める。見えている板（Material）の大きさを測る。
    final dialog = tester.getSize(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first,
    );
    expect(dialog.height, lessThan(screen.height / 2));
    expect(
      tester.getCenter(find.text('閉じる')).dy,
      tester.getCenter(find.text('続きを読む')).dy,
    );
  });

  testWidgets('控えが無ければ尋ねない（閉じてから終了したときに毎回出さない）', (tester) async {
    await _pumpApp(tester, InMemoryOpenVolumeStore());

    expect(find.byType(ResumeReadingDialog), findsNothing);
  });

  testWidgets('控えを読めなくてもホームはそのまま使える', (tester) async {
    await _pumpApp(
      tester,
      InMemoryOpenVolumeStore(_openVolume)..readError = StateError('db'),
    );

    expect(find.byType(ResumeReadingDialog), findsNothing);
  });

  testWidgets('「続きを読む」でタイトル詳細を挟んで巻を開く（閉じたら詳細へ戻す。#21）', (tester) async {
    final router = await _pumpApp(tester, InMemoryOpenVolumeStore(_openVolume));

    await tester.tap(find.text('続きを読む'));
    await tester.pumpAndSettle();

    expect(find.byType(ViewerScreen), findsOneWidget);
    expect(
      tester.widget<ViewerScreen>(find.byType(ViewerScreen)).volumeId,
      340,
    );

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(TitleDetailScreen), findsOneWidget);
  });

  testWidgets('「閉じる」なら控えを捨て、ホームへ戻っても尋ね直さない', (tester) async {
    final store = InMemoryOpenVolumeStore(_openVolume);
    final router = await _pumpApp(tester, store);

    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    expect(find.byType(ResumeReadingDialog), findsNothing);
    expect(store.stored, isNull, reason: '次の起動でも尋ねない');

    router.go(AppRoutes.history);
    await tester.pumpAndSettle();
    router.go(AppRoutes.library);
    await tester.pumpAndSettle();
    expect(find.byType(ResumeReadingDialog), findsNothing);
  });

  testWidgets('ホーム以外から始まったら割り込まず、ホームを開いたときに尋ねる（通知のタップで詳細を開いたときなど）', (
    tester,
  ) async {
    final router = await _pumpApp(
      tester,
      InMemoryOpenVolumeStore(_openVolume),
      location: AppRoutes.bookDetail(12),
    );
    expect(find.byType(ResumeReadingDialog), findsNothing);

    router.go(AppRoutes.library);
    await tester.pumpAndSettle();
    expect(find.byType(ResumeReadingDialog), findsOneWidget);
  });

  testWidgets('「続きを読む」では詳細を 1 回しか取りに行かない（自宅サーバーを叩きすぎない）', (tester) async {
    final api = FakeBooksApi(bookDetail: _detail, readVolume: _readVolume);
    await _pumpApp(tester, InMemoryOpenVolumeStore(_openVolume), booksApi: api);

    await tester.tap(find.text('続きを読む'));
    await tester.pumpAndSettle();

    expect(find.byType(ViewerScreen), findsOneWidget);
    expect(api.fetchBookDetailCalls, [12]);
  });

  testWidgets('外のタップでは閉じない（誤タップで断ったことにしない）', (tester) async {
    final store = InMemoryOpenVolumeStore(_openVolume);
    await _pumpApp(tester, store);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(ResumeReadingDialog), findsOneWidget);
    expect(store.stored, isNotNull);
  });

  testWidgets('戻るボタンで閉じたら、選んでいないので控えは残す（次の起動でまた尋ねる）', (tester) async {
    final store = InMemoryOpenVolumeStore(_openVolume);
    await _pumpApp(tester, store);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ResumeReadingDialog), findsNothing);
    expect(store.stored, isNotNull);
  });

  testWidgets('起動時に読んだ後で控えが捨てられていたら尋ねない（ログアウト / safe_mode の変更）', (
    tester,
  ) async {
    final store = InMemoryOpenVolumeStore(_openVolume);
    final container = createContainer(
      authApi: MockAuthApi(),
      booksApi: FakeBooksApi(bookDetail: _detail, readVolume: _readVolume),
      openVolumeStore: store,
    );
    addTearDown(container.dispose);
    // ホームを出す前に読み込みを済ませ、その後で破棄が走った状態を作る。
    await container.read(resumeReadingPromptProvider.future);
    await store.clear();

    final router = GoRouter(routes: buildRoutes());
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ResumeReadingDialog), findsNothing);
  });
}
