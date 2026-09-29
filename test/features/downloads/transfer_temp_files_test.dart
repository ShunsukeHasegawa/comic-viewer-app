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
