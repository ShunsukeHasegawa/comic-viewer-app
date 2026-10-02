import 'package:comic_laz/core/router/app_routes.dart';
import 'package:comic_laz/features/push/domain/push_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pushRouteFor', () {
    test('data の無い通知（いまのサーバーの新刊通知）はライブラリを開く', () {
      expect(pushRouteFor(const {}), AppRoutes.library);
    });

    test('book_id があればそのタイトルの詳細を開く（サーバーが載せたときの備え）', () {
      expect(pushRouteFor(const {'book_id': '12'}), AppRoutes.bookDetail(12));
    });

    test('book_ids が 1 件だけならそのタイトルを開く', () {
      expect(
        pushRouteFor(const {'book_ids': ' 34 '}),
        AppRoutes.bookDetail(34),
      );
    });

    test('book_ids が複数ならライブラリ（どれを開くか決められないため）', () {
      expect(pushRouteFor(const {'book_ids': '1,2'}), AppRoutes.library);
    });

    test('読めない / 0 以下の ID はライブラリ（通知を押して行き止まりにしない）', () {
      expect(pushRouteFor(const {'book_id': 'abc'}), AppRoutes.library);
      expect(pushRouteFor(const {'book_id': '0'}), AppRoutes.library);
      expect(pushRouteFor(const {'book_ids': 'x'}), AppRoutes.library);
    });

    test('book_id が読めなくても book_ids が 1 件なら使う', () {
      expect(
        pushRouteFor(const {'book_id': '', 'book_ids': '5'}),
        AppRoutes.bookDetail(5),
      );
    });
  });

  group('payload', () {
    test('前面で出した通知の data を押したときに取り戻せる', () {
      const data = {'book_id': '12', 'kind': 'new_volume'};

      expect(decodePushPayload(encodePushPayload(data)), data);
    });

    test('壊れた payload は空として読む（ライブラリへ遷移する）', () {
      expect(decodePushPayload(null), isEmpty);
      expect(decodePushPayload('not json'), isEmpty);
      expect(decodePushPayload('[1,2]'), isEmpty);
    });

    test('FCM の data は数値などが混ざっても文字列にそろえる', () {
      expect(stringifyPushData({'book_id': 12, 'x': null}), {'book_id': '12'});
    });
  });
}
