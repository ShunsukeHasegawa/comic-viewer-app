import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../domain/models/book.dart';

/// 一覧の控え（全タイトル）の JSON の出し入れ（#26）。
///
/// 1500 タイトルで数 MB になるので、`jsonDecode` + `Book.fromJson` /
/// `toJson` + `jsonEncode` を UI isolate で行うと数百 ms 単位でフレームが落ちる。
/// 大きいものは [compute] で別の isolate に回す。
///
/// 小さいものをその場で処理するのは、isolate の起動（数 ms）の方が高く付くため
/// （Dio の `BackgroundTransformer` が 50 KB 未満をその場で decode するのと同じ考え）。
/// `flutter_test` の擬似時間の中では isolate の完了を待てないので、テストの
/// 小さな一覧が `runAsync` 無しで通ることにもなる。
abstract final class LibraryPayloadCodec {
  /// これ未満の文字数の payload はその場で decode する。
  static const decodeInIsolateFrom = 64 * 1024;

  /// これ未満の冊数はその場で encode する（1 冊の JSON は数百バイト）。
  static const encodeInIsolateFrom = 200;

  /// 本体を decode する。形が違えば例外（呼び出し側で「無い」とみなして捨てる）。
  static Future<List<Book>> decodeBooks(String payload) =>
      payload.length < decodeInIsolateFrom
      ? Future.sync(() => decodeBooksSync(payload))
      : compute(decodeBooksSync, payload, debugLabel: 'decodeLibraryBooks');

  /// 本体を encode する。
  static Future<String> encodeBooks(List<Book> books) =>
      books.length < encodeInIsolateFrom
      ? Future.sync(() => encodeBooksSync(books))
      : compute(encodeBooksSync, books, debugLabel: 'encodeLibraryBooks');

  /// 旧形式（#26 より前。本体と `user_status` を 1 つの JSON に持つ）を
  /// 本体と `user_status` に分ける。
  ///
  /// どちらも JSON 文字列のまま返す（`Book` に戻して encode し直す手間を省く）。
  /// 形が違えば例外。
  static Future<LegacyLibraryParts> splitLegacy(String payload) =>
      payload.length < decodeInIsolateFrom
      ? Future.sync(() => splitLegacySync(payload))
      : compute(splitLegacySync, payload, debugLabel: 'splitLegacyLibrary');

  @visibleForTesting
  static List<Book> decodeBooksSync(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('一覧の控えがオブジェクトではない');
    }
    final books = decoded['books'];
    if (books is! List) throw const FormatException('一覧の控えに books が無い');
    return [
      for (final json in books)
        if (json is Map<String, dynamic>) Book.fromJson(json),
    ];
  }

  @visibleForTesting
  static String encodeBooksSync(List<Book> books) => jsonEncode({
    'books': [for (final book in books) book.toJson()],
  });

  @visibleForTesting
  static LegacyLibraryParts splitLegacySync(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('一覧の控えがオブジェクトではない');
    }
    final books = decoded['books'];
    if (books is! List) throw const FormatException('一覧の控えに books が無い');
    final status = decoded['user_status'];
    return (
      books: jsonEncode({'books': books}),
      userStatus: status is Map<String, dynamic> ? jsonEncode(status) : null,
    );
  }
}

/// 旧形式の控えを分けた結果（どちらも JSON 文字列）。
typedef LegacyLibraryParts = ({String books, String? userStatus});
