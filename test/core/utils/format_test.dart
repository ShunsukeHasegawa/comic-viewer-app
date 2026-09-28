import 'package:comic_laz/core/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatBytes', () {
    test('単位を切り替える', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(1536), '2 KB', reason: 'KB は小数を出さない');
      expect(formatBytes(1048576), '1.0 MB');
      expect(formatBytes(104857600), '100.0 MB');
      expect(formatBytes(1073741824), '1.0 GB');
      expect(formatBytes(5 * 1024 * 1024 * 1024), '5.0 GB');
    });

    test('負の値は - にする', () {
      expect(formatBytes(-1), '-');
    });
  });

  group('formatYearMonth', () {
    test('YYYY-MM を和暦表記にする', () {
      expect(formatYearMonth('2026-09'), '2026年9月');
      expect(formatYearMonth('2026-12'), '2026年12月');
    });

    test('解釈できない値はそのまま返す', () {
      expect(formatYearMonth('2026'), '2026');
      expect(formatYearMonth('abc-de'), 'abc-de');
    });
  });

  test('formatDateTime は端末のタイムゾーンで表示する', () {
    final value = DateTime(2026, 9, 25, 1, 5);

    expect(formatDateTime(value), '2026/09/25 01:05');
  });
}
