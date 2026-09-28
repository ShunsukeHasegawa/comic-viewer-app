import 'package:comic_laz/core/config/app_config.dart';
import 'package:comic_laz/core/media/media_urls.dart';
import 'package:flutter_test/flutter_test.dart';

MediaUrls buildMediaUrls([String baseUrl = 'https://comic.lazgram.com']) =>
    MediaUrls(AppConfig.from(apiBaseUrl: baseUrl, flavor: 'production'));

void main() {
  group('page', () {
    test('files_version を必ず ?v= として付ける', () {
      final urls = buildMediaUrls();

      expect(
        urls.page(volumeId: 340, page: 12, filesVersion: 1758763245).toString(),
        'https://comic.lazgram.com/books/view/340/12?v=1758763245',
      );
    });

    test('ZIP 差し替え（files_version 変化）で URL が変わる', () {
      final urls = buildMediaUrls();

      final before = urls.page(volumeId: 340, page: 1, filesVersion: 1);
      final after = urls.page(volumeId: 340, page: 1, filesVersion: 2);

      expect(before, isNot(after));
    });

    test('サブパス付きのベース URL でも配下に組み立てる', () {
      final urls = buildMediaUrls('https://example.com/comic');

      expect(
        urls.page(volumeId: 1, page: 2, filesVersion: 3).toString(),
        'https://example.com/comic/books/view/1/2?v=3',
      );
    });
  });

  group('thumbnail', () {
    test('API が返した相対 URL（?m= 付き）をそのまま絶対 URL にする', () {
      final urls = buildMediaUrls();

      expect(
        urls.thumbnail('/books/thumbnail/340?m=1758763245').toString(),
        'https://comic.lazgram.com/books/thumbnail/340?m=1758763245',
      );
    });

    test('null / 空文字はサムネイル無しとして null を返す', () {
      final urls = buildMediaUrls();

      expect(urls.thumbnail(null), isNull);
      expect(urls.thumbnail('   '), isNull);
    });

    test('絶対 URL はそのまま使う', () {
      final urls = buildMediaUrls();

      expect(
        urls.thumbnail('https://cdn.example.com/t/1.jpg').toString(),
        'https://cdn.example.com/t/1.jpg',
      );
    });

    test('サブパス付きのベース URL でもパスを保つ', () {
      final urls = buildMediaUrls('https://example.com/comic');

      expect(
        urls.thumbnail('/books/thumbnail/340?m=1').toString(),
        'https://example.com/comic/books/thumbnail/340?m=1',
      );
    });
  });

  group('別ホストの URL', () {
    test('スキーム省略の URL を API ホストに書き換えない', () {
      final urls = buildMediaUrls();

      expect(
        urls.thumbnail('//cdn.example.com/t/1.jpg').toString(),
        'https://cdn.example.com/t/1.jpg',
      );
    });

    test('パーセントエンコードを壊さない', () {
      final urls = buildMediaUrls();

      expect(
        urls.thumbnail('/books/thumbnail/a%2Fb?m=1').toString(),
        'https://comic.lazgram.com/books/thumbnail/a%2Fb?m=1',
      );
    });
  });

  group('キャッシュキー', () {
    test('ページは巻 / バージョン / ページで一意', () {
      expect(
        MediaUrls.pageCacheKey(volumeId: 340, page: 12, filesVersion: 1),
        isNot(MediaUrls.pageCacheKey(volumeId: 340, page: 12, filesVersion: 2)),
      );
      expect(
        MediaUrls.pageCacheKey(volumeId: 340, page: 12, filesVersion: 1),
        MediaUrls.pageCacheKey(volumeId: 340, page: 12, filesVersion: 1),
      );
    });

    test('サムネイルキーは thumbnail() と同じ正規化をする', () {
      expect(MediaUrls.thumbnailCacheKey(null), isNull);
      expect(MediaUrls.thumbnailCacheKey('   '), isNull);
      expect(
        MediaUrls.thumbnailCacheKey(' /books/thumbnail/340?m=1 '),
        MediaUrls.thumbnailCacheKey('/books/thumbnail/340?m=1'),
      );
    });

    test('サムネイルは ?m= の世代まで含める', () {
      expect(
        MediaUrls.thumbnailCacheKey('/books/thumbnail/340?m=1'),
        isNot(MediaUrls.thumbnailCacheKey('/books/thumbnail/340?m=2')),
      );
      expect(
        MediaUrls.thumbnailCacheKey('/books/thumbnail/340?m=1'),
        isNot(MediaUrls.thumbnailCacheKey('/books/thumbnail/341?m=1')),
      );
    });
  });
}
