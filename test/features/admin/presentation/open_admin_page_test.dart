import 'package:comic_laz/core/config/app_config.dart';
import 'package:comic_laz/features/admin/presentation/open_admin_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('adminPageUrl', () {
    test('ベース URL のサブパスを保つ（Web 版も同じ配信元の下にあるため）', () {
      final config = AppConfig.from(
        apiBaseUrl: 'https://example.com/comic/',
        flavor: 'production',
      );

      expect(
        adminPageUrl(config),
        Uri.parse('https://example.com/comic/admin'),
      );
      expect(
        adminPageUrl(config, bookId: 12),
        Uri.parse('https://example.com/comic/admin/books/12'),
      );
    });
  });
}
