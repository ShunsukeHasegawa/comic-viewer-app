import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';

/// 全画面表示のページ（ビューア / タイトル詳細 など）用の戻るボタン。
///
/// 通知やディープリンクで直接開かれた場合は戻り先が無いため、
/// pop できないときはライブラリへ遷移する（行き止まりを作らない）。
class AppBackButton extends StatelessWidget {
  const AppBackButton({this.style, super.key});

  /// 画像の上に重ねるときなど、既定の配色では見えない場所で差し替える。
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    // go_router の外（単体テストやダイアログ内）でも動くようにする。
    final router = GoRouter.maybeOf(context);
    final canPop = router?.canPop() ?? Navigator.of(context).canPop();

    return IconButton(
      style: style,
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
