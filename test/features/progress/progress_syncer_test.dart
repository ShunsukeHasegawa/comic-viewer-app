import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/data/api/user_api.dart';
import 'package:comic_laz/domain/models/volume_status_sync.dart';
import 'package:comic_laz/features/progress/application/progress_syncer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';
import '../../support/progress_fakes.dart';

void main() {
  late InMemoryProgressStore store;
  late FakeUserApi api;
  late FakeStatusServer server;
  late ProgressSyncer syncer;

  final base = DateTime.utc(2026, 9, 25, 10);

  setUp(() {
    store = InMemoryProgressStore();
    server = FakeStatusServer();
    api = FakeUserApi()..onSync = server.sync;
    syncer = ProgressSyncer(store: store, api: api);
  });

  /// オフラインで [volumeId] を [page] ページまで読んだ状態。
  Future<void> readOffline(
    int volumeId, {
    required int page,
    int maxPage = 30,
    Duration after = Duration.zero,
  }) => store.save(
    volumeId: volumeId,
    currentPage: page,
    maxPage: maxPage,
    readAt: base.add(after),
  );

  test('オフラインで進めた複数巻が復帰後に 1 リクエストで全件同期される', () async {
    await readOffline(340, page: 10);
    await readOffline(341, page: 5, after: const Duration(minutes: 1));
    await readOffline(342, page: 22, after: const Duration(minutes: 2));

    expect(await syncer.sync(), isTrue);

    expect(server.batches, hasLength(1), reason: 'HDD サーバーへの往復を 1 回に寄せる');
    expect(server.statuses[340]!.currentPage, 10);
    expect(server.statuses[341]!.currentPage, 5);
    expect(server.statuses[342]!.currentPage, 22);
    expect(await store.pending(limit: 100), isEmpty, reason: '送れた行は synced');
  });

  test('他端末が先に進めた巻は巻き戻らず、ローカルがサーバー値で上書きされる', () async {
    // 圏外で 3 ページまで読んだが、その後に別端末で 20 ページまで進んでいた。
    await readOffline(340, page: 3);
    server.record(
      volumeId: 340,
      currentPage: 20,
      maxPage: 30,
      readAt: base.add(const Duration(hours: 1)),
    );

    expect(await syncer.sync(), isTrue);

    expect(server.statuses[340]!.currentPage, 20, reason: 'サーバーを巻き戻さない');
    final local = await store.find(340);
    expect(local!.currentPage, 20, reason: 'サーバーの方が新しいのでローカルを上書き');
    expect(local.synced, isTrue, reason: '同じ行を送り続けない');
  });

  test('自端末の方が新しければサーバーへ反映される', () async {
    server.record(
      volumeId: 340,
      currentPage: 3,
      maxPage: 30,
      readAt: base.subtract(const Duration(hours: 1)),
    );
    await readOffline(340, page: 18);

    expect(await syncer.sync(), isTrue);

    expect(server.statuses[340]!.currentPage, 18);
    expect((await store.find(340))!.synced, isTrue);
  });

  test('送信に失敗した進捗は synced にせず、次の同期で送り直す', () async {
    await readOffline(340, page: 10);
    api.syncError = const NetworkException();

    expect(await syncer.sync(), isFalse);

    final pending = await store.pending(limit: 100);
    expect(pending.single.currentPage, 10, reason: '圏外でも進捗は消えない');
    expect(pending.single.synced, isFalse);

    // 復帰したら同じ行が送られる。
    api.syncError = null;
    expect(await syncer.sync(), isTrue);
    expect(server.statuses[340]!.currentPage, 10);
  });

  test('0 ページの巻はそもそも溜まらない（送らない）', () async {
    await store.save(volumeId: 340, currentPage: 1, maxPage: 0, readAt: base);

    expect(await syncer.sync(), isFalse);
    expect(api.syncedBatches, isEmpty, reason: '送る中身が無ければ通信しない');
  });

  test('消えた巻（not_found）は捨てて再送しない', () async {
    await readOffline(340, page: 10);
    await readOffline(999, page: 2, after: const Duration(minutes: 1));
    server.knownVolumes = {340};

    await syncer.sync();

    expect(await store.find(999), isNull);
    expect((await store.find(340))!.synced, isTrue);
    expect(server.batches, hasLength(1), reason: '捨てた行を送り直さない');
  });

  test('端末時計が進みすぎた進捗（future_read_at）は残すが送り続けない', () async {
    await readOffline(340, page: 10);
    // サーバーは信用できない時刻の進捗を書かない（巻き戻しもしない）。
    api.onSync = (items) => VolumeStatusSyncResult(
      skipped: [
        for (final item in items)
          VolumeStatusSkip(
            volumeId: item.volumeId,
            reason: VolumeStatusSkipReason.futureReadAt,
          ),
      ],
    );

    expect(await syncer.sync(), isFalse);

    expect((await store.find(340))!.synced, isFalse, reason: '時計が直れば送れる');
    expect(api.syncedBatches, hasLength(1), reason: '同じバッチを回し続けない');
  });

  test('上限（100 件）を超える未送信は複数回に分けて送る', () async {
    for (var i = 0; i < 150; i++) {
      await readOffline(500 + i, page: 2, after: Duration(seconds: i));
    }

    await syncer.sync();

    expect(
      [for (final batch in server.batches) batch.length],
      [UserApi.bulkStatusMaxItems, 50],
    );
    expect(await store.pending(limit: 200), isEmpty);
  });

  test('同期中に読み進めた分は未送信のまま残り、続けて送られる', () async {
    await readOffline(340, page: 5);
    var advanced = false;
    api.beforeSync = () async {
      if (advanced) return;
      advanced = true;
      // 送信の往復中にページ送り（ビューアからの保存）が入った。
      await readOffline(340, page: 9, after: const Duration(seconds: 30));
    };

    await syncer.sync();

    expect(server.statuses[340]!.currentPage, 9, reason: '最新ページまで送る');
    final local = await store.find(340);
    expect(local!.currentPage, 9);
    expect(local.synced, isTrue);
  });

  test('送信の往復中に同じ秒でページを送っても最新ページが消えない', () async {
    // read_at は秒精度（drift の unix 秒 / MySQL の TIMESTAMP）なので、1 秒以内の
    // ページ送りは送った行と時刻では区別できない。応答をそのまま書き戻すと
    // 9 ページ目が消えたうえ「送信済み」になり、二度と送られない。
    await readOffline(340, page: 5, after: const Duration(milliseconds: 100));
    var advanced = false;
    api.beforeSync = () async {
      if (advanced) return;
      advanced = true;
      await readOffline(340, page: 9, after: const Duration(milliseconds: 800));
    };

    expect(await syncer.sync(), isTrue);

    expect(server.statuses[340]!.currentPage, 9, reason: '最新ページまで送る');
    final local = await store.find(340);
    expect(local!.currentPage, 9);
    expect(local.synced, isTrue);
  });

  test('同期した直後に同じ秒でページを送っても stale で潰されない', () async {
    // サーバーの比較は「read_at がより新しいときだけ採用」。同期した秒のうちに
    // ページ送りが入ると永久に stale になり、サーバーの古い値でローカルが
    // 上書きされて synced まで立つ（次に開くと古いページから再開する）。
    await readOffline(340, page: 20);
    expect(await syncer.sync(), isTrue);
    await readOffline(340, page: 25, after: const Duration(milliseconds: 700));

    expect(await syncer.sync(), isTrue);

    expect(server.statuses[340]!.currentPage, 25, reason: '25 ページ目がサーバーに届く');
    final local = await store.find(340);
    expect(local!.currentPage, 25, reason: 'サーバーの古い値で潰さない');
    expect(local.synced, isTrue);
  });

  test('端末時計が進みすぎていてもサーバー時刻に合わせ直して送れる', () async {
    // サーバーは 300 秒以上未来の read_at を書かない。放置すると進捗は永久に
    // 届かないのに手元には最新があるので、アプリ上は正常に見えてしまう。
    // サーバー側のコメントどおり、応答の Date ヘッダで分かった時刻に合わせ直す。
    final serverNow = base.subtract(const Duration(days: 1));
    server.now = serverNow;
    api.serverTime = serverNow;
    await readOffline(340, page: 10);

    expect(await syncer.sync(), isTrue);

    expect(server.statuses[340]!.currentPage, 10);
    final local = await store.find(340);
    expect(local!.synced, isTrue);
    expect(
      local.readAt.isAtSameMomentAs(serverNow),
      isTrue,
      reason: 'サーバー時刻で送り直す',
    );
    expect(api.syncedBatches, hasLength(2), reason: '棄却 → 合わせ直し → 再送');
  });

  test('受け取られない行が混ざっても、片付いた行のために送り直さない', () async {
    // 停滞行を除かず「未送信の集合が変わったか」だけで判断すると、flush ごとに
    // 同じ停滞行を含むリクエストをもう 1 回投げてしまう（HDD への無駄な往復）。
    await readOffline(340, page: 10);
    await readOffline(341, page: 4, after: const Duration(seconds: 1));
    api.onSync = (items) => VolumeStatusSyncResult(
      applied: [
        for (final item in items)
          if (item.volumeId == 340)
            VolumeStatusSnapshot(
              volumeId: item.volumeId,
              currentPage: item.currentPage,
              maxPage: item.maxPage,
              readAt: item.readAt.toUtc(),
              updatedAt: item.readAt.toUtc(),
            ),
      ],
      skipped: [
        for (final item in items)
          if (item.volumeId != 340)
            VolumeStatusSkip(
              volumeId: item.volumeId,
              reason: VolumeStatusSkipReason.unknown,
            ),
      ],
    );

    await syncer.sync();

    expect((await store.find(340))!.synced, isTrue);
    expect((await store.find(341))!.synced, isFalse, reason: '次の同期で送り直す');
    expect(api.syncedBatches, hasLength(1), reason: '停滞行だけの往復を増やさない');
  });
}
