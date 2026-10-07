import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/data/api/books_api.dart';
import 'package:comic_laz/data/api/conditional_response.dart';
import 'package:comic_laz/data/api/paginated.dart';
import 'package:comic_laz/data/api/taxonomy_api.dart';
import 'package:comic_laz/data/api/user_api.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/domain/models/read_volume.dart';
import 'package:comic_laz/domain/models/reading_book.dart';
import 'package:comic_laz/domain/models/volume_status_sync.dart';

/// 本物のサーバー（`V2\BookController::show`）が返す詳細の 404（JSON の本文つき）。
const _detailNotFound = NotFoundException(serverMessage: 'Not Found');

/// ネットワークを触らない [BooksApi]。
///
/// 既定は空の一覧。[error] を設定するとその例外を投げる。
class FakeBooksApi implements BooksApi {
  FakeBooksApi({
    this.books = const [],
    this.userStatus = const UserStatus(),
    this.etag,
    this.bookDetail,
    this.readVolume,
    this.error,
    this.userStatusError,
    this.bookDetailError,
    this.readVolumeError,
    Map<int, BookDetail>? bookDetails,
  }) : bookDetails = {...?bookDetails};

  List<Book> books;
  UserStatus userStatus;
  String? etag;
  BookDetail? bookDetail;
  ReadVolume? readVolume;

  /// タイトルごとの詳細（あれば [bookDetail] より優先）。
  ///
  /// 空でないときに載っていないタイトルは 404 にする（複数タイトルの
  /// 「更新を確認」で一部だけ失敗する状況を作るため）。
  final Map<int, BookDetail> bookDetails;

  /// `fetchBookDetail` を呼ばれたタイトル（ネットワークに出たかの検証）。
  final fetchBookDetailCalls = <int>[];

  /// `fetchBooks` で投げる例外。
  ApiException? error;

  /// `fetchUserStatus` で投げる例外。
  ApiException? userStatusError;

  /// `fetchBookDetail` の応答を待たせる（問い合わせ中の連打・競合の再現）。
  Future<void> Function(int bookId)? onFetchBookDetail;

  /// `fetchBookDetail` で投げる例外（圏外の再現）。
  ApiException? bookDetailError;

  /// `fetchReadVolume` で投げる例外（圏外の再現）。
  ApiException? readVolumeError;

  /// `fetchBooks` に渡された `If-None-Match`（`null` は未指定）。
  final ifNoneMatchCalls = <String?>[];

  /// 304 を返すかどうか（`If-None-Match` が [etag] と一致したとき）。
  bool respondNotModified = false;

  /// 304 の応答に付ける ETag（`null` なら [etag]）。圧縮の有無などで
  /// 中身が同じまま ETag の表記だけ変わる状況の再現に使う。
  String? notModifiedEtag;

  int fetchBooksCount = 0;
  final favorites = <int>{};

  @override
  Future<ConditionalResponse<List<Book>>> fetchBooks({
    String? ifNoneMatch,
  }) async {
    fetchBooksCount++;
    ifNoneMatchCalls.add(ifNoneMatch);
    if (error case final error?) throw error;
    if (respondNotModified && ifNoneMatch != null && ifNoneMatch == etag) {
      return ConditionalResponse.notModified(etag: notModifiedEtag ?? etag);
    }
    return ConditionalResponse.modified(books, etag: etag);
  }

  @override
  Future<UserStatus> fetchUserStatus() async {
    if (userStatusError case final error?) throw error;
    return userStatus;
  }

  @override
  Future<BookDetail> fetchBookDetail(int bookId) async {
    fetchBookDetailCalls.add(bookId);
    await onFetchBookDetail?.call(bookId);
    if (bookDetailError case final error?) throw error;
    if (bookDetails.isNotEmpty) {
      final detail = bookDetails[bookId];
      if (detail == null) throw _detailNotFound;
      return detail;
    }
    final detail = bookDetail;
    if (detail == null) throw _detailNotFound;
    return detail;
  }

  @override
  Future<ReadVolume> fetchReadVolume(int volumeId) async {
    if (readVolumeError case final error?) throw error;
    final volume = readVolume;
    if (volume == null) throw const NotFoundException();
    return volume;
  }

  @override
  Future<bool> isFavorite(int bookId) async => favorites.contains(bookId);

  @override
  Future<bool> addFavorite(int bookId) async {
    favorites.add(bookId);
    return true;
  }

  @override
  Future<bool> removeFavorite(int bookId) async {
    favorites.remove(bookId);
    return false;
  }
}

/// ネットワークを触らない [UserApi]。
class FakeUserApi implements UserApi {
  FakeUserApi({
    this.reading = const [],
    this.stats = const UserStats(),
    this.history = const [],
    this.readingError,
  });

  List<ReadingBook> reading;
  UserStats stats;
  List<HistoryEntry> history;
  ApiException? readingError;

  final recorded =
      <({int volumeId, int currentPage, int maxPage, DateTime? readAt})>[];

  /// 一括同期の応答を作る（`null` なら全件を採用したことにする）。
  VolumeStatusSyncResult Function(List<VolumeStatusSyncItem> items)? onSync;

  /// 一括同期で投げる例外（圏外 / サーバーエラーの再現）。
  ApiException? syncError;

  /// 応答の `Date` ヘッダから読めたサーバー時刻（`null` なら読めなかった）。
  DateTime? serverTime;

  /// 応答を返す前に実行する処理（同期中に読み進める状況を作る）。
  Future<void> Function()? beforeSync;

  /// 送ったバッチ（何件ずつまとめたかの検証に使う）。
  final syncedBatches = <List<VolumeStatusSyncItem>>[];

  @override
  Future<List<ReadingBook>> fetchReading() async {
    if (readingError case final error?) throw error;
    return reading;
  }

  @override
  Future<UserStats> fetchStats() async => stats;

  @override
  Future<Paginated<HistoryEntry>> fetchHistory({int page = 1}) async =>
      Paginated(
        items: history,
        currentPage: page,
        lastPage: 1,
        total: history.length,
      );

  @override
  Future<void> recordVolumeStatus({
    required int volumeId,
    required int currentPage,
    required int maxPage,
    DateTime? readAt,
  }) async {
    recorded.add((
      volumeId: volumeId,
      currentPage: currentPage,
      maxPage: maxPage,
      readAt: readAt,
    ));
  }

  @override
  Future<VolumeStatusSyncResponse> syncVolumeStatuses(
    List<VolumeStatusSyncItem> items,
  ) async {
    syncedBatches.add(items);
    await beforeSync?.call();
    if (syncError case final error?) throw error;
    if (onSync case final onSync?) {
      return (result: onSync(items), serverTime: serverTime);
    }
    return (
      result: VolumeStatusSyncResult(
        applied: [
          for (final item in items)
            VolumeStatusSnapshot(
              volumeId: item.volumeId,
              currentPage: item.currentPage,
              maxPage: item.maxPage,
              isFinished: item.currentPage >= item.maxPage,
              readAt: item.readAt.toUtc(),
              updatedAt: item.readAt.toUtc(),
            ),
        ],
      ),
      serverTime: serverTime,
    );
  }
}

/// ネットワークを触らない [TaxonomyApi]。
class FakeTaxonomyApi implements TaxonomyApi {
  FakeTaxonomyApi({
    this.categories = const [],
    this.tags = const [],
    this.error,
  });

  List<Taxonomy> categories;
  List<Taxonomy> tags;

  /// 設定すると取得に失敗する。
  ApiException? error;

  @override
  Future<List<Taxonomy>> fetchCategories() async {
    if (error case final error?) throw error;
    return categories;
  }

  @override
  Future<List<Taxonomy>> fetchTags() async {
    if (error case final error?) throw error;
    return tags;
  }
}

/// テスト用の書籍。
Book testBook({
  required int id,
  String title = 'タイトル',
  String? kana,
  List<String> author = const [],
  bool isComplete = false,
  List<int> categories = const [],
  List<int> tags = const [],
  DateTime? volumeAddedAt,
  int? latestVolume,
  String? thumbnail,
}) => Book(
  id: id,
  title: title,
  kana: kana,
  author: author,
  isComplete: isComplete,
  categories: categories,
  tags: tags,
  volumeAddedAt: volumeAddedAt,
  latestVolume: latestVolume,
  thumbnail: thumbnail,
);
