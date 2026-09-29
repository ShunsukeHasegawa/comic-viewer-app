import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:comic_laz/features/downloads/data/archive_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

/// 名前を指定して ZIP を作る（拡張子の表記を試すため）。
Uint8List zipWithNames(List<String> names) {
  final archive = Archive();
  for (final name in names) {
    archive.add(ArchiveFile.bytes(name, List<int>.filled(16, 0x42)));
  }
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('archive-verifier');
    addTearDown(() => workspace.deleteSync(recursive: true));
  });

  File archiveWith(List<String> names) {
    final file = File('${workspace.path}/340.zip');
    file.writeAsBytesSync(zipWithNames(names));
    return file;
  }

  test('画像のページだけを数える（メタデータとドットファイルは除く）', () async {
    final file = archiveWith([
      '001.jpg',
      '002.jpeg',
      '003.png',
      '004.avif',
      'info.txt',
      '__MACOSX/005.jpg',
      'book/.hidden.jpg',
    ]);

    expect(await verifyArchivePages(file), 4);
  });

  test('大文字の拡張子は数えない（サーバーが case-sensitive に数えるため）', () async {
    // サーバーの `getPageEntriesInZip` は `in_array($pathInfo['extension'],
    // ['jpg','jpeg','png','avif'])` で判定するので `002.JPG` は page_count に
    // 入らない。ここで小文字化して数えると page_count が必ず食い違い、
    // 数百 MB を落とし切ってから「ページ数が一致しません」で永久に失敗する。
    final file = archiveWith(['001.jpg', '002.JPG', '003.Png']);

    expect(await verifyArchivePages(file), 1);
  });

  test('ZIP として読めないデータはページ 0 になる（照合で落ちる）', () async {
    // `ZipDecoder` は壊れたバイト列でも例外を投げずに空を返すことがある。
    // そのぶんページ数の照合（`DownloadQueue._verify`）が最後の砦になるので、
    // 「例外にならないこともある」ことを仕様として固定しておく。
    final file = File('${workspace.path}/broken.zip')
      ..writeAsBytesSync(List<int>.filled(512, 0x41));

    expect(await verifyArchivePages(file), 0);
  });

  test('ファイルが無ければ検証の例外にする', () async {
    expect(
      () => verifyArchivePages(File('${workspace.path}/missing.zip')),
      throwsA(isA<ArchiveVerificationException>()),
    );
  });
}
