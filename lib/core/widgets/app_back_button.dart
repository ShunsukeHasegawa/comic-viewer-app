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
    final router = GoRouter.of(context);
    final canPop = router.canPop();
    return IconButton(
      icon: Icon(canPop ? Icons.arrow_back : Icons.home_outlined),
      tooltip: canPop ? '戻る' : 'ライブラリへ',
      onPressed: () {
        if (canPop) {
          router.pop();
        } else {
          router.go(AppRoutes.library);
        }
      },
    );
  }
}
