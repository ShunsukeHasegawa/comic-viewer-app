import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';

import '../../../domain/models/volume_manifest.dart';

/// 重い処理を UI isolate の外で走らせる口（#25）。
///
/// 既定は [Isolate.run]。テストで「どの処理が外へ出たか」を数えられるように
/// 差し替え可能にしてある。渡す処理は送れる値（数値・文字列・リスト）だけを
/// 掴むこと（`this` を掴むと isolate へ送れない）。
typedef BackgroundRunner = Future<R> Function<R>(
  FutureOr<R> Function() computation,
);

/// ファイルの同一性の目印（サイズ + 更新時刻）。
///
/// 控えた解析結果が「今そこにあるファイル」のものかを、ページを読むたびに
/// isolate 側で確かめる。同じ世代のまま取り直された（削除 → rename）ZIP や、
/// 消された ZIP に古いオフセットで読みに行かないため。
typedef FileStamp = ({int size, int modified});

/// 1 エントリを読むのに要る位置情報（ローカルヘッダの先頭と、中央ディレクトリ
/// の圧縮 / 展開サイズ）。ディレクトリのエントリは `null`。
typedef ZipEntryRef = ({
  int localHeaderOffset,
  int compressedSize,
  int uncompressedSize,
});

/// 解析済みの ZIP のディレクトリとマニフェスト（巻 × 世代ごとに 1 つ）。
///
/// **ファイルハンドルは持たない**。中身はオフセットと数値だけなので、控えて
/// いる間も ZIP の削除（Windows では開いているファイルを消せない）や
/// rename による差し替えを妨げない。
class ZipPageIndex {
  const ZipPageIndex({
    required this.archiveStamp,
    required this.manifestStamp,
    required this.entries,
    required this.knownPages,
  });

  final FileStamp archiveStamp;

  /// マニフェストが無ければ `null`（後から書かれたら作り直す）。
  final FileStamp? manifestStamp;

  /// `ZipDecoder().decodeStream` の `files` と同じ並び。
  final List<ZipEntryRef?> entries;

  /// マニフェストが指す画像のエントリ番号。`null` は「絞り込まない」
  /// （マニフェストが無い / 読めない / ページ一覧が空）。
  final Set<int>? knownPages;
}

/// ページを読みに行った結果。
sealed class ZipPageRead {
  const ZipPageRead();
}

/// 読めた / 読めなかった（壊れている・空）。`bytes == null` は次の経路へ落とす。
final class ZipPageBytes extends ZipPageRead {
  const ZipPageBytes(this.bytes);
  final Uint8List? bytes;
}

/// 控えた解析結果が今のファイルと合わない（消えた / 差し替わった）。
final class ZipPageStale extends ZipPageRead {
  const ZipPageStale();
}

/// ZIP とマニフェストを [run] の先（既定は別 isolate）で解析する。
///
/// ZIP が無い・壊れているときは `null`。例外は投げない（読書を止めない）。
Future<ZipPageIndex?> buildZipPageIndexInBackground(
  BackgroundRunner run, {
  required String archivePath,
  required String manifestPath,
}) => run(() => _buildIndex(archivePath, manifestPath));

/// 控えた位置情報で 1 エントリだけを [run] の先（既定は別 isolate）で読んで展開する。
Future<ZipPageRead> readZipEntryInBackground(
  BackgroundRunner run, {
  required String archivePath,
  required String manifestPath,
  required FileStamp archiveStamp,
  required FileStamp? manifestStamp,
  required ZipEntryRef entry,
}) => run(
  () =>
      _readEntry(archivePath, manifestPath, archiveStamp, manifestStamp, entry),
);

FileStamp? _stampOf(String path) {
  final stat = File(path).statSync();
  if (stat.type != FileSystemEntityType.file) return null;
  return (size: stat.size, modified: stat.modified.millisecondsSinceEpoch);
}

ZipPageIndex? _buildIndex(String archivePath, String manifestPath) {
  try {
    final archiveStamp = _stampOf(archivePath);
    if (archiveStamp == null) return null;
    final manifestStamp = _stampOf(manifestPath);
    final manifest = manifestStamp == null ? null : _readManifest(manifestPath);

    final entries = _readDirectory(archivePath);
    if (entries == null) return null;
    final pages = manifest?.pages ?? const <VolumeManifestPage>[];
    return ZipPageIndex(
      archiveStamp: archiveStamp,
      manifestStamp: manifestStamp,
      entries: entries,
      knownPages: pages.isEmpty ? null : {for (final p in pages) p.index},
    );
  } on Object {
    return null;
  }
}

/// `DownloadStore.readManifest` と同じ解釈（読めなければ `null`）。
VolumeManifest? _readManifest(String path) {
  try {
    final json = jsonDecode(File(path).readAsStringSync());
    if (json is! Map<String, dynamic>) return null;
    return VolumeManifest.fromJson(json);
  } on Object {
    return null;
  }
}

/// エントリ番号はサーバー（`VolumeService::readPageFromZip`）の `getFromIndex()`
/// と同じ「セントラルディレクトリの並び順」。以前と同じく `ZipDecoder` の
/// `files` の並び（同名エントリは先勝ちで 1 つにまとまる）をそのまま使い、
/// 番号の数え方を変えない。
List<ZipEntryRef?>? _readDirectory(String archivePath) {
  final input = InputFileStream(archivePath);
  try {
    final decoded = ZipDecoder().decodeStream(input);
    return [
      for (final file in decoded.files)
        switch (file.rawContent) {
          final ZipFile zip when file.isFile && zip.header != null => (
            localHeaderOffset: zip.header!.localHeaderOffset,
            compressedSize: zip.header!.compressedSize,
            uncompressedSize: zip.header!.uncompressedSize,
          ),
          _ => null,
        },
    ];
  } on Object {
    return null;
  } finally {
    input.closeSync();
  }
}

ZipPageRead _readEntry(
  String archivePath,
  String manifestPath,
  FileStamp archiveStamp,
  FileStamp? manifestStamp,
  ZipEntryRef entry,
) {
  try {
    // 控えを作った後に消された / 差し替わった ZIP やマニフェストを、古い
    // オフセット・古いページ一覧で読まない。
    if (_stampOf(archivePath) != archiveStamp ||
        _stampOf(manifestPath) != manifestStamp) {
      return const ZipPageStale();
    }
  } on Object {
    return const ZipPageStale();
  }

  InputFileStream? input;
  try {
    input = InputFileStream(archivePath);
    input.setPosition(entry.localHeaderOffset);
    final header = ZipFileHeader()
      ..localHeaderOffset = entry.localHeaderOffset
      ..compressedSize = entry.compressedSize
      ..uncompressedSize = entry.uncompressedSize;
    final zip = ZipFile(header)..read(input);
    final bytes = ArchiveFile.file(
      zip.filename,
      entry.uncompressedSize,
      zip,
    ).readBytes();
    return ZipPageBytes(bytes == null || bytes.isEmpty ? null : bytes);
  } on Object {
    // 壊れた ZIP でも読書を止めない（キャッシュ / ネットワークへ落ちる）。
    return const ZipPageBytes(null);
  } finally {
    // 読み終えたらすぐ閉じる（開いたままだと Windows で削除できない）。
    input?.closeSync();
  }
}
