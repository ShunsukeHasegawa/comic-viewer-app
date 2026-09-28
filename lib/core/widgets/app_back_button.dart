import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';

/// 全画面表示のページ（ビューア / タイトル詳細 など）用の戻るボタン。
///
/// 通知やディープリンクで直接開かれた場合は戻り先が無いため、
/// pop できないときはライブラリへ遷移する（行き止まりを作らない）。
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    // go_router の外（単体テストやダイアログ内）でも動くようにする。
    final router = GoRouter.maybeOf(context);
    final canPop = router?.canPop() ?? Navigator.of(context).canPop();

    return IconButton(
      icon: Icon(canPop ? Icons.arrow_back : Icons.home_outlined),
      tooltip: canPop ? '戻る' : 'ライブラリへ',
      onPressed: () {
        if (canPop) {
          if (router != null) {
            router.pop();
          } else {
            Navigator.of(context).pop();
          }
          return;
        }
        router?.go(AppRoutes.library);
      },
    );
  }
}
