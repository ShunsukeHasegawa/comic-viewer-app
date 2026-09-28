import 'package:comic_laz/core/json/json_bool.dart';
import 'package:comic_laz/core/json/json_date_time.dart';
import 'package:comic_laz/core/json/json_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('boolFromJson', () {
    test('bool / 数値 / 文字列を読む', () {
      expect(boolFromJson(true), isTrue);
      expect(boolFromJson(false), isFalse);
      expect(boolFromJson(1), isTrue);
      expect(boolFromJson(0), isFalse);
      expect(boolFromJson('1'), isTrue);
      expect(boolFromJson('true'), isTrue);
      expect(boolFromJson('0'), isFalse);
      expect(boolFromJson(null), isFalse);
      expect(boolFromJson('yes'), isFalse);
    });

    test('isBoolLike は真偽値として解釈できる形だけを通す', () {
      expect(isBoolLike(true), isTrue);
      expect(isBoolLike(0), isTrue);
      expect(isBoolLike('1'), isTrue);
      expect(isBoolLike(' false '), isTrue);
      expect(isBoolLike('yes'), isFalse);
      expect(isBoolLike(null), isFalse);
      expect(isBoolLike({'favorite': true}), isFalse);
    });
  });

  group('dateTimeFromJson', () {
    test('ISO8601（Z 付き）をそのまま読む', () {
      expect(
        dateTimeFromJson('2026-09-25T01:00:45.000000Z'),
        DateTime.utc(2026, 9, 25, 1, 0, 45),
      );
    });

    test('タイムゾーン無しは UTC として読む（端末 TZ で解釈しない）', () {
      expect(
        dateTimeFromJson('2026-09-20 12:34:56'),
        DateTime.utc(2026, 9, 20, 12, 34, 56),
      );
      expect(
        dateTimeFromJson('2026-09-20T12:34:56'),
        DateTime.utc(2026, 9, 20, 12, 34, 56),
      );
    });

    test('日付だけなら 0 時として読む', () {
      expect(dateTimeFromJson('2026-09-20'), DateTime.utc(2026, 9, 20));
    });

    test('オフセット付きは UTC に正規化する', () {
      expect(
        dateTimeFromJson('2026-09-20T21:34:56+09:00'),
        DateTime.utc(2026, 9, 20, 12, 34, 56),
      );
    });

    test('解釈できない値は null（一覧全体のパースを失敗させない）', () {
      expect(dateTimeFromJson(null), isNull);
      expect(dateTimeFromJson(''), isNull);
      expect(dateTimeFromJson('0000-00-00 00:00:00'), isNull);
      expect(dateTimeFromJson(12345), isNull);
    });

    test('往復できる', () {
      final value = DateTime.utc(2026, 9, 25, 1, 0, 45);
      expect(dateTimeFromJson(dateTimeToJson(value)), value);
      expect(dateTimeToJson(null), isNull);
    });
  });

  group('リスト', () {
    test('intListFromJson は数値と数字文字列を拾う', () {
      expect(intListFromJson([1, '2', 3.0, null, 'x']), [1, 2, 3]);
      expect(intListFromJson(null), isEmpty);
      expect(intListFromJson('not a list'), isEmpty);
    });

    test('stringListFromJson は null 要素を落とす', () {
      expect(stringListFromJson(['a', null, 1]), ['a', '1']);
      expect(stringListFromJson(null), isEmpty);
    });
  });
}
