import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/models/reading_book.dart';
import 'api_client.dart';
import 'paginated.dart';

part 'user_api.g.dart';

/// ユーザーの読書状態に関するエンドポイント。
class UserApi {
  const UserApi(this._client);

  static const readingPath = 'api/v2/user/reading';
  static const statsPath = 'api/v2/user/stats';
  static const historyPath = 'api/user-volume-status/history';

  final ApiClient _client;

  /// 「続きを読む」（`GET /api/v2/user/reading`）。応答は `data` でラップされている。
  Future<List<ReadingBook>> fetchReading() async {
    final json = await _client.getObject(readingPath);
    final items = json['data'];
    return ApiClient.parseList(
      ApiClient.asObjectList(items, readingPath),
      ReadingBook.fromJson,
      path: readingPath,
    );
  }

  /// 読書統計（`GET /api/v2/user/stats`）。
  Future<UserStats> fetchStats() async {
    final json = await _client.getObject(statsPath);
    return ApiClient.parse(json, UserStats.fromJson, path: statsPath);
  }

  /// 読書履歴（`GET /api/user-volume-status/history?page=`）。1 ページ 10 件。
  Future<Paginated<HistoryEntry>> fetchHistory({int page = 1}) async {
    final json = await _client.getObject(
      historyPath,
      queryParameters: {'page': page},
    );
    return Paginated.fromJson(json, HistoryEntry.fromJson, path: historyPath);
  }

  /// 読書進捗の記録（`POST /api/user-volume-status/{volumeId}`）。
  ///
  /// サーバーは `OK`（プレーンテキスト）を返すので JSON として解釈しない。
  /// [readAt] は端末時刻。一括同期 API（#12）と時計の基準を揃えるために送る。
  ///
  /// 注意: サーバーは `max()` を取らない upsert なので、**古い進捗を送ると
  /// 他端末の進捗を巻き戻す**。呼び出し側で送る値を吟味すること。
  Future<void> recordVolumeStatus({
    required int volumeId,
    required int currentPage,
    required int maxPage,
    DateTime? readAt,
  }) async {
    await _client.send(
      'api/user-volume-status/$volumeId',
      method: 'POST',
      data: {
        'current_page': currentPage,
        'max_page': maxPage,
        if (readAt != null) 'read_at': readAt.toUtc().toIso8601String(),
      },
      responseType: ResponseType.plain,
    );
  }
}

@Riverpod(keepAlive: true)
UserApi userApi(Ref ref) => UserApi(ref.watch(apiClientProvider));
