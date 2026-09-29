import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/features/progress/data/progress_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftProgressStore store;

  final readAt = DateTime.utc(2026, 9, 25, 10, 11, 22);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = DriftProgressStore(database);
  });
  tearDown(() => database.close());

  test('保存した進捗は未送信として残る', () async {
    await store.save(
      volumeId: 340,
      currentPage: 12,
      maxPage: 30,
      readAt: readAt,
    );

    final saved = await store.find(340);
    expect(saved!.currentPage, 12);
    expect(saved.maxPage, 30);
    // drift の DateTime は秒精度の unix time で保存され、読み戻しはローカル時刻に
    // なる（サーバーの TIMESTAMP と同じ粒度）。同じ瞬間かどうかで比べる。
    expect(saved.readAt.isAtSameMomentAs(readAt), isTrue);
    expect(saved.synced, isFalse);
    expect(saved.isPending, isTrue);
  });

  test('ページ番号は min(page, files.length) に丸める', () async {
    // 巻末オーバーレイ（最終ページ + 1）の番号を保存しないため。
    await store.save(
      volumeId: 340,
      currentPage: 31,
      maxPage: 30,
      readAt: readAt,
    );

    expect((await store.find(340))!.currentPage, 30);
  });

  test('0 ページの巻は保存しない', () async {
    // ZIP が無い巻は読めない。送ると max_page の検証（min:1）で弾かれるうえ、
    // 他端末の進捗を 0 ページで潰しかねない。
    await store.save(volumeId: 340, currentPage: 1, maxPage: 0, readAt: readAt);

    expect(await store.find(340), isNull);
  });

  test('複数巻を保持し、未送信だけを古い順に返す', () async {
    for (final volumeId in [340, 341, 342]) {
      await store.save(
        volumeId: volumeId,
        currentPage: 3,
        maxPage: 20,
        // 読んだ順に時刻をずらす。
        readAt: readAt.add(Duration(minutes: volumeId - 340)),
      );
    }
    // 341 だけ同期が済んだ状態にする。
    final synced = readAt.add(const Duration(minutes: 1));
    await store.overwriteFromServer(
      volumeId: 341,
      sentReadAt: synced,
      sentCurrentPage: 3,
      currentPage: 3,
      maxPage: 20,
      readAt: synced,
    );

    final pending = await store.pending(limit: 100);
    expect([for (final row in pending) row.volumeId], [340, 342]);
    expect((await store.loadAll()).keys, containsAll([340, 341, 342]));
  });

  test('上限を超える未送信は limit 件までしか返さない', () async {
    for (var i = 0; i < 5; i++) {
      await store.save(
        volumeId: 400 + i,
        currentPage: 1,
        maxPage: 10,
        readAt: readAt.add(Duration(seconds: i)),
      );
    }

    expect(await store.pending(limit: 3), hasLength(3));
  });

  test('送信の往復中に読み進めた行はサーバー応答で上書きしない', () async {
    // 古い read_at のつもりで書き戻すと最新ページが消え、しかも「送信済み」
    // 扱いになって二度と送られない。
    await store.save(
      volumeId: 340,
      currentPage: 5,
      maxPage: 30,
      readAt: readAt,
    );
    final newer = readAt.add(const Duration(seconds: 30));
    await store.save(volumeId: 340, currentPage: 8, maxPage: 30, readAt: newer);

    final written = await store.overwriteFromServer(
      volumeId: 340,
      sentReadAt: readAt,
      sentCurrentPage: 5,
      currentPage: 20,
      maxPage: 30,
      readAt: readAt.add(const Duration(seconds: 10)),
    );

    expect(written, isFalse);
    expect((await store.find(340))!.currentPage, 8);
  });

  test('同じ秒に入ったページ送りもサーバー応答で上書きしない', () async {
    // drift も MySQL の TIMESTAMP も秒精度なので、送信の往復中（1 秒以内）に
    // 入ったページ送りは read_at では区別できない。ページ番号まで見ないと、
    // 最新ページがサーバー値で潰されたうえ「送信済み」になって二度と送られない。
    await store.save(
      volumeId: 340,
      currentPage: 5,
      maxPage: 30,
      readAt: readAt.add(const Duration(milliseconds: 100)),
    );
    await store.save(
      volumeId: 340,
      currentPage: 9,
      maxPage: 30,
      readAt: readAt.add(const Duration(milliseconds: 800)),
    );

    final written = await store.overwriteFromServer(
      volumeId: 340,
      // 送ったのは 5 ページ目。read_at は同じ秒に丸められている。
      sentReadAt: readAt,
      sentCurrentPage: 5,
      currentPage: 5,
      maxPage: 30,
      readAt: readAt,
    );

    expect(written, isFalse);
    final saved = await store.find(340);
    expect(saved!.currentPage, 9, reason: '往復中に進んだページを残す');
    expect(saved.synced, isFalse, reason: '未送信のままにして送り直させる');
  });

  test('read_at の付け替えはページと synced を変えない', () async {
    // サーバーが同じ秒の記録を持っていると「より新しいときだけ採用」の比較で
    // 永久に負けるので、1 秒進めて送り直せるようにする。
    await store.save(
      volumeId: 340,
      currentPage: 9,
      maxPage: 30,
      readAt: readAt,
    );
    final later = readAt.add(const Duration(seconds: 1));

    final written = await store.rebaseReadAt(
      volumeId: 340,
      sentReadAt: readAt,
      sentCurrentPage: 9,
      readAt: later,
    );

    expect(written, isTrue);
    final saved = await store.find(340);
    expect(saved!.readAt.isAtSameMomentAs(later), isTrue);
    expect(saved.currentPage, 9);
    expect(saved.synced, isFalse, reason: 'まだ送れていない');
  });

  test('付け替えようとした行が進んでいたら何もしない', () async {
    await store.save(
      volumeId: 340,
      currentPage: 9,
      maxPage: 30,
      readAt: readAt,
    );
    // 同じ秒のうちに読み進めた（read_at では区別できない）。
    await store.save(
      volumeId: 340,
      currentPage: 12,
      maxPage: 30,
      readAt: readAt.add(const Duration(milliseconds: 400)),
    );

    final written = await store.rebaseReadAt(
      volumeId: 340,
      sentReadAt: readAt,
      sentCurrentPage: 9,
      readAt: readAt.add(const Duration(seconds: 1)),
    );

    expect(written, isFalse);
    expect((await store.find(340))!.currentPage, 12);
  });

  test('サーバーの方が新しければローカルを上書きして送信済みにする', () async {
    await store.save(
      volumeId: 340,
      currentPage: 5,
      maxPage: 30,
      readAt: readAt,
    );
    final serverReadAt = readAt.add(const Duration(hours: 1));

    final written = await store.overwriteFromServer(
      volumeId: 340,
      sentReadAt: readAt,
      sentCurrentPage: 5,
      currentPage: 25,
      maxPage: 30,
      readAt: serverReadAt,
    );

    expect(written, isTrue);
    final saved = await store.find(340);
    expect(saved!.currentPage, 25);
    expect(saved.readAt.isAtSameMomentAs(serverReadAt), isTrue);
    expect(saved.synced, isTrue);
  });

  test('ログアウトで全件消える', () async {
    await store.save(
      volumeId: 340,
      currentPage: 5,
      maxPage: 30,
      readAt: readAt,
    );
    await store.save(
      volumeId: 341,
      currentPage: 5,
      maxPage: 30,
      readAt: readAt,
    );

    await store.deleteAll();

    expect(await store.loadAll(), isEmpty);
  });
}
