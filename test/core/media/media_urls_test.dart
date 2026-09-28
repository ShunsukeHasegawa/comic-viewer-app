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
      final urls = buildMediaUrls();

      expect(
        urls.pageCacheKey(volumeId: 340, page: 12, filesVersion: 1),
        isNot(urls.pageCacheKey(volumeId: 340, page: 12, filesVersion: 2)),
      );
      expect(
        urls.pageCacheKey(volumeId: 340, page: 12, filesVersion: 1),
        urls.pageCacheKey(volumeId: 340, page: 12, filesVersion: 1),
      );
    });

    test('サムネイルキーは thumbnail() と同じ正規化をする', () {
      final urls = buildMediaUrls();

      expect(urls.thumbnailCacheKey(null), isNull);
      expect(urls.thumbnailCacheKey('   '), isNull);
      expect(
        urls.thumbnailCacheKey(' /books/thumbnail/340?m=1 '),
        urls.thumbnailCacheKey('/books/thumbnail/340?m=1'),
      );
    });

    test('サムネイルは ?m= の世代まで含める', () {
      final urls = buildMediaUrls();

      expect(
        urls.thumbnailCacheKey('/books/thumbnail/340?m=1'),
        isNot(urls.thumbnailCacheKey('/books/thumbnail/340?m=2')),
      );
      expect(
        urls.thumbnailCacheKey('/books/thumbnail/340?m=1'),
        isNot(urls.thumbnailCacheKey('/books/thumbnail/341?m=1')),
      );
    });

    // 保存先（キャッシュディレクトリ / DB）は配信元で分かれていないため、
    // キーが同じだと開発ビルドで本番サーバーの画像が出てしまう。
    test('配信元が違えばキーも違う（開発ビルドと本番ビルドで混ざらない）', () {
      final production = buildMediaUrls();
      final development = buildMediaUrls('http://192.168.0.2:8000');

      expect(
        production.pageCacheKey(volumeId: 340, page: 12, filesVersion: 1),
        isNot(
          development.pageCacheKey(volumeId: 340, page: 12, filesVersion: 1),
        ),
      );
      expect(
        production.thumbnailCacheKey('/books/thumbnail/340?m=1'),
        isNot(development.thumbnailCacheKey('/books/thumbnail/340?m=1')),
      );
    });

    // 巻の古い世代の掃除は `v{巻 ID}/` の接頭辞で行の候補を絞るので、
    // 配信元は末尾に付いていなければならない。
    test('ページキーは巻 ID / バージョンの接頭辞で始まる（古い世代の掃除が効く）', () {
      final urls = buildMediaUrls();

      expect(
        urls.pageCacheKey(volumeId: 340, page: 12, filesVersion: 7),
        startsWith('v340/7/12'),
      );
    });
  });
}
