import 'package:comic_laz/features/auth/application/auth_controller.dart';
import 'package:comic_laz/features/progress/data/progress_purger.dart';
import 'package:comic_laz/features/viewer/data/progress_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/auth_fakes.dart';
import '../../support/progress_fakes.dart';
import '../../support/test_scope.dart';

void main() {
  late InMemoryProgressStore store;
  late MockAuthApi authApi;

  final readAt = DateTime.utc(2026, 9, 25, 10, 5);

  setUp(() {
    store = InMemoryProgressStore([
      testProgress(volumeId: 340, currentPage: 10, maxPage: 30),
    ]);
    authApi = MockAuthApi()..stubCurrentUser();
    when(authApi.deleteToken).thenAnswer((_) async {});
  });

  /// ログイン済みまで進めた container（進捗の破棄は本物の [ProgressPurger]）。
  Future<({ProgressRecorder recorder, AuthController auth})> signIn() async {
    final container = createContainer(
      authStore: FakeAuthStore(token: 'valid', user: testUser),
      authApi: authApi,
      purgers: [ProgressPurger(store)],
      progressStore: store,
    );
    addTearDown(container.dispose);
    await settleAuth(container);
    return (
      recorder: container.read(progressRecorderProvider),
      auth: container.read(authControllerProvider.notifier),
    );
  }

  test('ログアウト後に呼ばれても進捗行を作り直さない', () async {
    // ログアウトは「ProgressPurger で全件削除 → 未ログインへ」の順で走り、
    // 未ログインになってから router がビューアを外す。その dispose の
    // flushProgress がここへ来るので、消した**後**に行が復活してはいけない。
    // 残すと、次にログインしたユーザーのトークンで前のユーザーの読書位置が
    // 一括送信され、読んでいない巻が「続きを読む」に出る。
    final signedIn = await signIn();

    await signedIn.auth.logout();
    await signedIn.recorder.savePage(
      volumeId: 340,
      currentPage: 12,
      maxPage: 30,
      readAt: readAt,
    );

    expect(await store.loadAll(), isEmpty);
  });

  test('ログイン中はそのまま保存する', () async {
    // 上のガードが常に効いてしまっていないことの確認。
    final signedIn = await signIn();

    await signedIn.recorder.savePage(
      volumeId: 340,
      currentPage: 12,
      maxPage: 30,
      readAt: readAt,
    );

    expect((await store.find(340))!.currentPage, 12);
  });
}
