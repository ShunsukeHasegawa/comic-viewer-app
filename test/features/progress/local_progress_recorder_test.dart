import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/features/progress/application/progress_syncer.dart';
import 'package:comic_laz/features/progress/data/local_progress_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';
import '../../support/progress_fakes.dart';

void main() {
  late InMemoryProgressStore store;
  late FakeUserApi api;
  late FakeStatusServer server;
  late LocalProgressRecorder recorder;

  final readAt = DateTime.utc(2026, 9, 25, 10);

  setUp(() {
    store = InMemoryProgressStore();
    server = FakeStatusServer();
    api = FakeUserApi()..onSync = server.sync;
    recorder = LocalProgressRecorder(
      store: store,
      syncer: ProgressSyncer(store: store, api: api),
    );
  });

  test('ページ送りの保存は端末に書くだけで送信しない', () async {
    await recorder.savePage(
      volumeId: 340,
      currentPage: 7,
      maxPage: 30,
      readAt: readAt,
    );

    expect((await store.find(340))!.currentPage, 7);
    expect(api.syncedBatches, isEmpty, reason: 'ページ送りごとにサーバーを叩かない');
    expect(await recorder.unsyncedPage(340), 7);
  });

  test('オンラインなら送信まで済んで synced が立つ', () async {
    final sent = await recorder.record(
      volumeId: 340,
      currentPage: 7,
      maxPage: 30,
      readAt: readAt,
    );

    expect(sent, isTrue);
    expect(server.statuses[340]!.currentPage, 7);
    expect((await store.find(340))!.synced, isTrue);
    expect(await recorder.unsyncedPage(340), isNull);
  });

  test('圏外では送信できなかったことを返し、進捗は端末に残る', () async {
    api.syncError = const NetworkException();

    final sent = await recorder.record(
      volumeId: 340,
      currentPage: 7,
      maxPage: 30,
      readAt: readAt,
    );

    expect(sent, isFalse, reason: '送れていないので記録済みにしない');
    final saved = await store.find(340);
    expect(saved!.currentPage, 7);
    expect(saved.synced, isFalse);
    // 次に開いたときはこのページから再開する（サーバーの古い値に戻さない）。
    expect(await recorder.unsyncedPage(340), 7);
  });

  test('ページ番号は min(page, files.length) に丸める', () async {
    await recorder.record(
      volumeId: 340,
      // 巻末オーバーレイ（最終ページ + 1）。
      currentPage: 31,
      maxPage: 30,
      readAt: readAt,
    );

    expect(api.syncedBatches.single.single.currentPage, 30);
  });

  test('0 ページの巻は保存も送信もしない', () async {
    final sent = await recorder.record(
      volumeId: 340,
      currentPage: 1,
      maxPage: 0,
      readAt: readAt,
    );

    expect(sent, isFalse);
    expect(await store.find(340), isNull);
    expect(api.syncedBatches, isEmpty);
  });

  test('溜まっていた他の巻も一緒に送られる', () async {
    // 圏外で 341 を読んでいた状態で、341 を閉じて 340 を読み終えた。
    await recorder.savePage(
      volumeId: 341,
      currentPage: 4,
      maxPage: 12,
      readAt: readAt,
    );

    await recorder.record(
      volumeId: 340,
      currentPage: 9,
      maxPage: 30,
      readAt: readAt.add(const Duration(minutes: 1)),
    );

    expect(api.syncedBatches.single, hasLength(2));
    expect(server.statuses[341]!.currentPage, 4);
    expect(server.statuses[340]!.currentPage, 9);
  });

  group('ログアウト後', () {
    // ログアウトは「authStore.clear() → ProgressPurger で全件削除 → 未ログインへ」
    // の順で走り、未ログインになってからビューアが外れる。その dispose の
    // flushProgress がここへ来るので、消した後に行を作り直してはいけない。
    // 残すと、次にログインしたユーザーのトークンで前のユーザーの読書位置が
    // 一括送信され、読んでいない巻が「続きを読む」に出る。
    setUp(() => recorder.isSignedIn = false);

    test('ページ送りの保存は行を作らない', () async {
      await recorder.savePage(
        volumeId: 340,
        currentPage: 7,
        maxPage: 30,
        readAt: readAt,
      );

      expect(await store.find(340), isNull);
    });

    test('record も行を作らず、送信もしない', () async {
      final sent = await recorder.record(
        volumeId: 340,
        currentPage: 7,
        maxPage: 30,
        readAt: readAt,
      );

      expect(sent, isFalse);
      expect(await store.find(340), isNull);
      expect(api.syncedBatches, isEmpty, reason: 'トークンが無いので 401 を誘発しない');
    });
  });
}
