import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// 起動直後、保存済みトークンの検証が終わるまで表示する画面。
///
/// OS のスプラッシュ（`flutter_native_splash`。設定は pubspec.yaml）と同じ背景色・
/// 同じ絵を同じ大きさで中央に出す。テーマの背景（ライトは `#F7F8FA`）のままだと、
/// 起動のたびに teal から明るい灰色へ一瞬で切り替わり、白く光ったように見えるため（#16）。
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  /// `splash_logo.png` の表示幅（dp）。OS 側は同じ PNG を xxxhdpi（4 倍）として
  /// 扱うので 616px = 154dp。Android 12 以上のスプラッシュの絵も同じ大きさに
  /// 揃えてある（ずれると切り替わりで絵が跳ねる）。
  static const logoWidth = 154.0;

  /// 絵の中心からスピナーの中心までの距離。絵（高さ約 146dp）の下に置き、
  /// 絵そのものは OS のスプラッシュと同じ画面の真ん中から動かさない。
  static const _spinnerOffset = 128.0;

  @override
  Widget build(BuildContext context) {
    // アプリのテーマ設定（#17）ではなく OS の明暗に合わせる。OS のスプラッシュは
    // アプリの設定を知らずに OS の明暗で色を選ぶので、テーマに合わせると
    // 「OS はダーク・アプリはライト」のときに暗い背景から teal へ一瞬で切り替わる。
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 濃い背景の上なので、ライトテーマでもステータスバーのアイコンは白にする。
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: dark ? AppColors.darkBackground : AppColors.brand,
        // Scaffold の body は左上寄せのゆるい制約で置かれるので、そのままでは
        // Stack が絵の大きさに縮み、絵とスピナーが左上に出る。画面いっぱいに
        // 広げてから中央に置く（OS のスプラッシュの絵と同じ位置にするため）。
        body: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/branding/splash_logo.png',
                width: logoWidth,
                semanticLabel: 'Comic LAZ',
              ),
              Transform.translate(
                offset: const Offset(0, _spinnerOffset),
                child: CircularProgressIndicator(
                  // 既定の primary（ライトは brand）だと背景と同じ色で見えない。
                  color: dark ? AppColors.brandLight : AppColors.onBrand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
