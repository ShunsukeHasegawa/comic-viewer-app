import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'archive_verifier.g.dart';

/// 落としたアーカイブが壊れていることを表す。
///
/// 通信の失敗（[ApiException]）とは別物として扱う。再試行の判断が違う
/// （壊れた ZIP は同じ条件で取り直しても直るとは限らないので、自動で回さない）。
class ArchiveVerificationException implements Exception {
  const ArchiveVerificationException(this.message);

  /// ユーザーに見せる日本語。
  final String message;

  @override
  String toString() => 'ArchiveVerificationException: $message';
}

/// ZIP を開いて、中の画像ページ数を数える。
///
/// 失敗（開けない / 画像が無い）は [ArchiveVerificationException]。
typedef ArchiveVerifier = Future<int> Function(File archive);

/// サーバー（`VolumeService::getPageEntriesInZip`）と同じ判定で画像を数える。
///
/// 数え方がずれるとページ数の突き合わせが常に失敗するので、
/// 拡張子と除外条件はサーバー側に合わせる。
///
/// サーバーは `in_array($pathInfo['extension'], ['jpg','jpeg','png','avif'])` と
/// **大文字小文字を区別して**数えるため、こちらも小文字化しない。小文字化すると
/// `002.JPG` のようなエントリを含む ZIP で `page_count` が必ず食い違い、
/// 数百 MB を落とし切ってから検証で落ちる（何度やり直しても完了しない）。
/// 大文字拡張子のページはサーバー側も配信対象外なので、ここで数えないのが正。
const _imageExtensions = {'jpg', 'jpeg', 'png', 'avif'};

/// 既定の検証。
///
/// `ZipDecoder.decodeStream` は**セントラルディレクトリだけ**を読む
/// （各エントリの展開はしない）ので、数百 MB の ZIP でも末尾の数十 KB を
/// 読むだけで済む。ここで全ページを展開すると検証だけで数十秒かかる。
Future<int> verifyArchivePages(File archive) async {
  if (!archive.existsSync()) {
    throw const ArchiveVerificationException('ダウンロードしたファイルが見つかりません。');
  }

  final input = InputFileStream(archive.path);
  try {
    final decoded = ZipDecoder().decodeStream(input);
    var pages = 0;
    for (final file in decoded.files) {
      if (!file.isFile) continue;
      final name = file.name;
      // macOS が作るメタデータとドットファイルはページではない。
      if (name.contains('__MACOSX') || name.contains('/.')) continue;
      final extension = p.extension(name).replaceFirst('.', '');
      if (!_imageExtensions.contains(extension)) continue;
      pages++;
    }
    return pages;
  } on ArchiveVerificationException {
    rethrow;
  } on Object catch (error) {
    throw ArchiveVerificationException('ダウンロードしたファイルを開けませんでした（$error）。');
  } finally {
    await input.close();
  }
}

@Riverpod(keepAlive: true)
ArchiveVerifier archiveVerifier(Ref ref) => verifyArchivePages;
