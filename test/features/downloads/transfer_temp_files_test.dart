import 'dart:io';

import 'package:comic_laz/features/downloads/data/archive_transport.dart';
import 'package:comic_laz/features/downloads/data/transfer_temp_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory support;

  setUp(() {
    support = Directory.systemTemp.createTempSync('temp_files_test');
    addTearDown(() => support.deleteSync(recursive: true));
  });

  File write(String name) =>
      File(p.join(support.path, name))..writeAsBytesSync([1, 2, 3]);

  test('失敗で置き去りになったパッケージの書きかけを消す', () async {
    // Android は失敗した転送の一時ファイル（巻 1 冊ぶん）を残し、パッケージは
    // 再開データを捨てるので、誰も指さなくなる（F9）。
    final orphan = write('${transferTempFilePrefix}12345');

    final deleted = await deleteTransferTempFiles([support]);

    expect(deleted, 1);
    expect(orphan.existsSync(), isFalse);
  });

  test('一時停止中の転送の書きかけは「再開」で続きに使うので残す', () async {
    final paused = write('${transferTempFilePrefix}777');
    final orphan = write('${transferTempFilePrefix}888');

    await deleteTransferTempFiles([support], keepPaths: {paused.path});

    expect(paused.existsSync(), isTrue);
    expect(orphan.existsSync(), isFalse);
  });

  test('走行中の転送があるときは、しばらく書き込まれていない書きかけだけを消す', () async {
    // まとめて積んだ巻が走り続けている間も、失敗した巻の書きかけ（数百 MB）を
    // 溜め込まない。一方で、走っている転送の書きかけは同じ名前で、消すと完了時の
    // 移動が失敗する。受信のたびに書き足されて更新時刻が新しいので、古さで見分ける。
    final now = DateTime(2026, 9, 29, 12);
    final orphan = write('${transferTempFilePrefix}111')
      ..setLastModifiedSync(now.subtract(const Duration(minutes: 3)));
    final running = write('${transferTempFilePrefix}222')
      ..setLastModifiedSync(now.subtract(const Duration(seconds: 5)));

    final deleted = await deleteTransferTempFiles(
      [support],
      olderThan: transferTempStaleAge,
      now: now,
    );

    expect(deleted, 1);
    expect(orphan.existsSync(), isFalse);
    expect(running.existsSync(), isTrue);
  });

  group('掃除の範囲', () {
    TransferSnapshot snapshot(String id, TransferState state) =>
        TransferSnapshot(taskId: id, state: state);

    test('待機中の転送が 1 本でもあれば、年齢でも消さない', () {
      // Android の時間切れ / Wi-Fi 設定の変更で再投入された転送は、再開データを
      // ネイティブにしか持たず keepPaths に入らない。Wi-Fi を待つ間に書きかけが
      // 古くなり、消すと走り出したときに先頭から落とし直しになる。
      for (final waiting in [
        TransferState.enqueued,
        TransferState.waitingToRetry,
      ]) {
        expect(
          tempSweepScopeFor([
            snapshot('a', TransferState.running),
            snapshot('b', waiting),
          ], staleOnly: true),
          TempSweepScope.none,
          reason: '$waiting',
        );
      }
    });

    test('生きている転送がすべて走っていれば、しばらく書き込まれていないものだけを消す', () {
      // 走っている転送は自分の書きかけを書き足し続けるので、古いものは失敗した
      // 巻の置き去り。まとめて積んだ巻が走る間も溜めない。
      expect(
        tempSweepScopeFor([
          snapshot('a', TransferState.running),
          snapshot('b', TransferState.paused),
        ], staleOnly: false),
        TempSweepScope.stale,
      );
    });

    test('ネイティブに何も生きていなければ全部消す（呼び出し側が絞れと言えば絞る）', () {
      final idle = [snapshot('a', TransferState.paused)];
      expect(tempSweepScopeFor(idle, staleOnly: false), TempSweepScope.all);
      expect(tempSweepScopeFor(idle, staleOnly: true), TempSweepScope.stale);
    });

    test('再投入を待つ転送の古い書きかけは残り、待つものが無くなれば消える', () async {
      final now = DateTime(2026, 9, 29, 12);
      final waiting = write('${transferTempFilePrefix}333')
        ..setLastModifiedSync(now.subtract(const Duration(minutes: 30)));

      Future<void> sweep(List<TransferSnapshot> snapshots) async {
        final scope = tempSweepScopeFor(snapshots, staleOnly: true);
        if (scope == TempSweepScope.none) return;
        await deleteTransferTempFiles(
          [support],
          olderThan: scope == TempSweepScope.stale
              ? transferTempStaleAge
              : null,
          now: now,
        );
      }

      await sweep([
        snapshot('a', TransferState.running),
        snapshot('b', TransferState.enqueued),
      ]);
      expect(waiting.existsSync(), isTrue);

      await sweep([snapshot('a', TransferState.running)]);
      expect(waiting.existsSync(), isFalse);
    });
  });

  test('パッケージの一時ファイル以外（ダウンロード済みの巻など）には触らない', () async {
    final other = write('downloads.sqlite');
    Directory(p.join(support.path, 'downloads')).createSync();

    await deleteTransferTempFiles([support]);

    expect(other.existsSync(), isTrue);
    expect(Directory(p.join(support.path, 'downloads')).existsSync(), isTrue);
  });

  test('無いディレクトリは飛ばす（キャッシュ領域が無い端末で落ちない）', () async {
    final missing = Directory(p.join(support.path, 'missing'));

    expect(await deleteTransferTempFiles([missing]), 0);
  });

  test('無いディレクトリがあっても、続くディレクトリの書きかけは消す', () async {
    // Android の support / cache をまとめて渡す。片方が無いだけで掃除を
    // やめると、もう片方の書きかけ（巻 1 冊ぶん）が溜まり続ける。
    final missing = Directory(p.join(support.path, 'missing'));
    final orphan = write('${transferTempFilePrefix}444');

    expect(await deleteTransferTempFiles([missing, support]), 1);
    expect(orphan.existsSync(), isFalse);
  });
}
