/// サーバー実装（comic-viewer の `BookResource` 等）と同じ形の応答サンプル。
abstract final class ApiFixtures {
  /// `GET /api/books` の 1 件（`data` ラップ無しの配列要素）。
  static Map<String, dynamic> get book => {
    'id': 12,
    'title': '進撃の巨人',
    'kana': 'しんげきのきょじん',
    'thumbnail': '/books/thumbnail/340?m=1758763245',
    'is_complete': 1,
    'is_unsafe': 0,
    'volume_added_at': '2026-09-20 12:34:56',
    'latest_volume': 34,
    'author': ['諫山創'],
    'tags': [3, 7],
    'categories': [1],
  };

  /// `GET /api/books/read/volume/{id}`。
  static Map<String, dynamic> get readVolume => {
    'id': 340,
    'volume': 34,
    'current_page': 12,
    'next_volume_id': 341,
    'next_volume_thumbnail': '/books/thumbnail/341?m=1758763999',
    'files': [1, 2, 3, 4, 5],
    'files_version': 1758763245,
    'book': book,
  };

  /// `GET /api/v2/books/{id}`。
  static Map<String, dynamic> get bookDetail => {
    'id': 12,
    'title': '進撃の巨人',
    'overview': 'あらすじ',
    'is_complete': true,
    'is_favorite': false,
    'authors': ['諫山創'],
    'publisher': '講談社',
    'label': '少年マガジンコミックス',
    'tags': ['アクション', 'ダーク'],
    'categories': [
      {'id': 1, 'name': '少年'},
    ],
    'volumes': [
      {
        'id': 340,
        'volume': 1,
        'thumbnail': '/books/thumbnail/340?m=1758763245',
        'total_pages': 190,
        'archive_bytes': 104857600,
        'files_version': 1758763245,
        'user_volume_status': {
          'current_page': 12,
          'max_page': 190,
          'is_finished': false,
        },
      },
      {
        'id': 341,
        'volume': 2,
        'thumbnail': null,
        'total_pages': null,
        'archive_bytes': null,
        'files_version': null,
        'user_volume_status': null,
      },
    ],
    'total_archive_bytes': 104857600,
    'reading_progress': {
      'read_volumes': 0,
      'total_volumes': 2,
      'current_volume': 1,
      'current_page': 12,
      'total_pages': 190,
    },
  };

  /// `GET /api/v2/user/reading`（`data` ラップあり）。
  static Map<String, dynamic> get reading => {
    'data': [
      {
        'book_id': 12,
        'title': '進撃の巨人',
        'thumbnail': '/books/thumbnail/340?m=1758763245',
        'volume_number': 1,
        'volume_id': 340,
        'current_page': 12,
        'max_page': 190,
        'progress_percent': 6,
      },
    ],
  };

  /// `GET /api/v2/user/stats`。
  static Map<String, dynamic> get stats => {
    'titles_completed': 3,
    'volumes_completed': 42,
    'monthly': [
      {'month': '2026-08', 'count': 7},
      {'month': '2026-09', 'count': 5},
    ],
  };

  /// `GET /api/user-volume-status/history?page=`（Laravel のページネーション）。
  static Map<String, dynamic> get history => {
    'data': [
      {
        'title': '進撃の巨人',
        'id': 340,
        'book_id': 12,
        'volume': 1,
        'thumbnail': '/books/thumbnail/340?m=1758763245',
        'current_page': 190,
        'max_page': 190,
        'is_finished': 1,
        'updated_at': '2026-09-25T01:00:45.000000Z',
      },
    ],
    'links': {
      'first': '?page=1',
      'last': '?page=3',
      'prev': null,
      'next': '?page=2',
    },
    'meta': {'current_page': 1, 'last_page': 3, 'per_page': 10, 'total': 25},
  };
}
