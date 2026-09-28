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
  });

  List<Book> books;
  UserStatus userStatus;
  String? etag;
  BookDetail? bookDetail;
  ReadVolume? readVolume;

  /// `fetchBooks` で投げる例外。
  ApiException? error;

  /// `fetchUserStatus` で投げる例外。
  ApiException? userStatusError;

  /// `fetchBooks` に渡された `If-None-Match`（`null` は未指定）。
  final ifNoneMatchCalls = <String?>[];

  /// 304 を返すかどうか（`If-None-Match` が [etag] と一致したとき）。
  bool respondNotModified = false;

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
      return ConditionalResponse.notModified(etag: etag);
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
    final detail = bookDetail;
    if (detail == null) throw const NotFoundException();
    return detail;
  }

  @override
  Future<ReadVolume> fetchReadVolume(int volumeId) async {
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
