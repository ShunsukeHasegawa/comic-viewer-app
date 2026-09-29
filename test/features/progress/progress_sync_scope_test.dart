import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/features/progress/presentation/progress_sync_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';
import '../../support/auth_fakes.dart';
import '../../support/progress_fakes.dart';
import '../../support/test_scope.dart';

void main() {
  late InMemoryProgressStore store;
  late FakeUserApi api;
  late FakeStatusServer server;
  late FakeConnectivityMonitor connectivity;

  final readAt = DateTime.utc(2026, 9, 25, 10);

  setUp(() {
    // 圏外で 10 ページまで読んだ未送信の進捗が 1 件ある状態。
    store = InMemoryProgressStore([
      testProgress(volumeId: 340, currentPage: 10, maxPage: 30, readAt: readAt),
    ]);
    server = FakeStatusServer();
    api = FakeUserApi()..onSync = server.sync;
    connectivity = FakeConnectivityMonitor();
  });

  /// 同期の面倒を見る widget を、ログイン状態を選んで立てる。
  Future<void> pumpScope(WidgetTester tester, {bool signedIn = true}) async {
    await tester.pumpWidget(
      wrapWithScope(
        const ProgressSyncScope(child: SizedBox.shrink()),
        overrides: testOverrides(
          authStore: FakeAuthStore(token: signedIn ? 'valid' : null),
          authApi: signedIn
              ? (MockAuthApi()..stubCurrentUser())
              : MockAuthApi(),
          userApi: api,
          progressStore: store,
          connectivityMonitor: connectivity,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('起動してログイン済みになったら溜まっていた進捗を送る', (tester) async {
    await pumpScope(tester);

    expect(server.statuses[340]!.currentPage, 10);
    expect((await store.find(340))!.synced, isTrue);
  });

  testWidgets('未ログインでは送らない', (tester) async {
    // 401 を誘発してセッション失効の扱いを汚さないため。
    await pumpScope(tester, signedIn: false);

    expect(api.syncedBatches, isEmpty);
  });

  testWidgets('ネットワーク復帰で送り直す', (tester) async {
    api.syncError = const NetworkException();
    await pumpScope(tester);
    expect((await store.find(340))!.synced, isFalse, reason: '圏外では送れない');

    api.syncError = null;
    connectivity.restore();
    await tester.pumpAndSettle();

    expect(server.statuses[340]!.currentPage, 10);
  });

  testWidgets('フォアグラウンド復帰で送り直す', (tester) async {
    api.syncError = const NetworkException();
    await pumpScope(tester);

    api.syncError = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(server.statuses[340]!.currentPage, 10);
  });
}
