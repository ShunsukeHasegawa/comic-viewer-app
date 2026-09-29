import 'dart:io';

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
}
