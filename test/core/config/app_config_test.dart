import 'package:comic_laz/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.from', () {
    test('末尾スラッシュを落として正規化する', () {
      final config = AppConfig.from(
        apiBaseUrl: 'https://comic.lazgram.com/',
        flavor: 'production',
      );

      expect(config.apiBaseUrlString, 'https://comic.lazgram.com');
      expect(config.flavor, AppFlavor.production);
      expect(config.flavor.isProduction, isTrue);
    });

    test('前後の空白を許容する', () {
      final config = AppConfig.from(
        apiBaseUrl: '  http://192.168.0.2:8000  ',
        flavor: 'development',
      );

      expect(config.apiBaseUrlString, 'http://192.168.0.2:8000');
      expect(config.flavor, AppFlavor.development);
      expect(config.flavor.isProduction, isFalse);
    });

    test('サブパス付きのベース URL を保持する', () {
      final config = AppConfig.from(
        apiBaseUrl: 'https://example.com/comic/',
        flavor: 'production',
      );

      expect(config.apiBaseUrlString, 'https://example.com/comic');
      expect(
        config.resolvePath('/api/books').toString(),
        'https://example.com/comic/api/books',
      );
    });

    test('空 / 相対 / 不正スキーム / クエリ付きは例外', () {
      for (final invalid in [
        '',
        '   ',
        'comic.lazgram.com',
        'ftp://comic.lazgram.com',
        'https://comic.lazgram.com?a=1',
        'https://comic.lazgram.com#top',
        'https:///api',
      ]) {
        expect(
          () => AppConfig.from(apiBaseUrl: invalid, flavor: 'production'),
          throwsA(isA<AppConfigException>()),
          reason: 'apiBaseUrl="$invalid" は拒否されるべき',
        );
      }
    });

    test('未知の flavor は例外', () {
      expect(
        () => AppConfig.from(
          apiBaseUrl: 'https://comic.lazgram.com',
          flavor: 'prod',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });
  });

  group('AppConfig.resolvePath', () {
    final config = AppConfig.from(
      apiBaseUrl: 'https://comic.lazgram.com',
      flavor: 'production',
    );

    test('先頭スラッシュの有無に関わらず同じ URL になる', () {
      expect(
        config.resolvePath('api/books').toString(),
        'https://comic.lazgram.com/api/books',
      );
      expect(
        config.resolvePath('/api/books').toString(),
        'https://comic.lazgram.com/api/books',
      );
    });

    test('クエリパラメータを付与できる', () {
      expect(
        config
            .resolvePath('/books/view/12/001.jpg', queryParameters: {'v': '3'})
            .toString(),
        'https://comic.lazgram.com/books/view/12/001.jpg?v=3',
      );
    });
  });

  group('AppConfig.fromEnvironment', () {
    test('dart-define 未指定なら本番設定になる', () {
      final config = AppConfig.fromEnvironment();

      expect(config.apiBaseUrlString, 'https://comic.lazgram.com');
      expect(config.flavor, AppFlavor.production);
    });
  });
}
