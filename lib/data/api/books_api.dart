import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/json/json_bool.dart';
import '../../core/network/api_exception.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_detail.dart';
import '../../domain/models/read_volume.dart';
import 'api_client.dart';
import 'conditional_response.dart';

part 'books_api.g.dart';

/// 書籍関連のエンドポイント。
class BooksApi {
  const BooksApi(this._client);

  static const booksPath = 'api/books';
  static const userStatusPath = 'api/books/user_status';

  final ApiClient _client;

  /// ライブラリ一覧（`GET /api/books`）。
  ///
  /// `data` ラップ無しの素の配列。ETag による条件付き GET に対応しており、
  /// [ifNoneMatch] を渡して 304 が返ったら手元のキャッシュを使う。
  /// プルリフレッシュ（強制再取得）では [ifNoneMatch] を渡さない。
  Future<ConditionalResponse<List<Book>>> fetchBooks({
    String? ifNoneMatch,
  }) async {
    final response = await _client.send(
      booksPath,
      headers: {'If-None-Match': ?ifNoneMatch},
      allowNotModified: ifNoneMatch != null,
    );
    final etag = response.headers.value('etag');

    if (response.statusCode == 304) {
      return ConditionalResponse.notModified(etag: etag ?? ifNoneMatch);
    }

    final books = ApiClient.parseList(
      ApiClient.asObjectList(response.data, booksPath),
      Book.fromJson,
      path: booksPath,
    );
    return ConditionalResponse.modified(books, etag: etag);
  }

  /// 一覧に重ねるユーザー状態（`GET /api/books/user_status`）。
  Future<UserStatus> fetchUserStatus() async {
    final json = await _client.getObject(userStatusPath);
    return ApiClient.parse(json, UserStatus.fromJson, path: userStatusPath);
  }

  /// ビューアを開くための巻情報（`GET /api/books/read/volume/{volumeId}`）。
  ///
  /// 削除済みの巻は 404（[NotFoundException]）。通信エラーとは型で区別されるので、
  /// 呼び出し側は通信エラーで手元の進捗を捨ててはいけない。
  Future<ReadVolume> fetchReadVolume(int volumeId) async {
    final path = 'api/books/read/volume/$volumeId';
    final json = await _client.getObject(path);
    return ApiClient.parse(json, ReadVolume.fromJson, path: path);
  }

  /// タイトル詳細（`GET /api/v2/books/{bookId}`）。
  Future<BookDetail> fetchBookDetail(int bookId) async {
    final path = 'api/v2/books/$bookId';
    final json = await _client.getObject(path);
    return ApiClient.parse(json, BookDetail.fromJson, path: path);
  }

  /// お気に入り状態（`GET /api/favorites/{bookId}`）。
  Future<bool> isFavorite(int bookId) async {
    final response = await _client.send('api/favorites/$bookId');
    return _asBool(response.data);
  }

  /// お気に入りに追加（`POST /api/favorites/{bookId}`）。
  Future<bool> addFavorite(int bookId) async {
    final response = await _client.send(
      'api/favorites/$bookId',
      method: 'POST',
    );
    return _asBool(response.data);
  }

  /// お気に入りから削除（`DELETE /api/favorites/{bookId}`）。
  Future<bool> removeFavorite(int bookId) async {
    final response = await _client.send(
      'api/favorites/$bookId',
      method: 'DELETE',
    );
    return _asBool(response.data);
  }

  /// お気に入り API は真偽値だけを返す。
  ///
  /// 解釈できない応答を `false` に倒すと、書き込みが成功しているのに UI が
  /// 「お気に入りでない」に戻ってしまうので、エラーとして扱う。
  static bool _asBool(Object? data) {
    if (!isBoolLike(data)) {
      throw UnexpectedResponseException(detail: 'favorites: 真偽値ではない応答 ($data)');
    }
    return boolFromJson(data is String ? data.trim() : data);
  }
}

@Riverpod(keepAlive: true)
BooksApi booksApi(Ref ref) => BooksApi(ref.watch(apiClientProvider));
