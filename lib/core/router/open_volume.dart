import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// タイトル詳細を挟んで巻を開く（#21）。
///
/// 「続きを読む」や履歴から開いた巻を閉じたとき、元の一覧ではなくタイトル
/// 詳細へ戻す。次の巻を選ぶ・ダウンロードするなど、読み終えた後の操作は
/// 詳細で行うため。
void pushVolumeViaTitle(
  BuildContext context, {
  required int bookId,
  required int volumeId,
}) {
  final router = GoRouter.of(context);
  // redirect が同期なので 1 回目の push で積み終わり、2 回目はその上に積まれる
  // （`app_router_test.dart` がこの前提を確かめている）。
  router
    ..push(AppRoutes.bookDetail(bookId))
    ..push(AppRoutes.viewer(volumeId));
}
