import 'dart:io';
import 'dart:typed_data';

import 'package:comic_laz/core/theme/app_colors.dart';
import 'package:comic_laz/core/theme/app_theme.dart';
import 'package:comic_laz/features/auth/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// OS のスプラッシュ（pubspec.yaml の `flutter_native_splash`）と Flutter 側の
/// [SplashScreen] が食い違うと、起動のたびに色や絵が一瞬で切り替わって見える（#16）。
/// どちらもビルドやほかのテストでは気づけないので、ここで揃っていることを押さえる。
void main() {
  /// [platform] は OS の明暗、[themeMode] はアプリの表示テーマの設定（#17）。
  Future<Color?> pumpSplash(
    WidgetTester tester, {
    Brightness platform = Brightness.light,
    ThemeMode themeMode = ThemeMode.system,
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = platform;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: const SplashScreen(),
      ),
    );
    return tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor;
  }

  testWidgets('OS がライトなら OS のスプラッシュと同じ teal を背景にする（テーマの明るい背景だと白く光って見えるため）', (
    tester,
  ) async {
    expect(await pumpSplash(tester), AppColors.brand);
  });

  testWidgets('OS がダークなら OS のスプラッシュと同じ暗い背景にする', (tester) async {
    expect(
      await pumpSplash(tester, platform: Brightness.dark),
      AppColors.darkBackground,
    );
  });

  // OS のスプラッシュはアプリの設定を知らず、OS の明暗だけで色を選ぶ。
  // アプリのテーマに合わせると、設定と OS が食い違うときに一瞬で色が切り替わる。
  testWidgets('アプリをライトに固定していても OS がダークなら暗い背景のまま（OS のスプラッシュに揃える）', (
    tester,
  ) async {
    expect(
      await pumpSplash(
        tester,
        platform: Brightness.dark,
        themeMode: ThemeMode.light,
      ),
      AppColors.darkBackground,
    );
  });

  testWidgets('アプリをダークに固定していても OS がライトなら teal のまま', (tester) async {
    expect(
      await pumpSplash(tester, themeMode: ThemeMode.dark),
      AppColors.brand,
    );
  });

  testWidgets('OS のスプラッシュと同じ絵を同じ幅で出す（ずれると切り替わりで絵が跳ねるため）', (tester) async {
    await pumpSplash(tester);

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/branding/splash_logo.png',
    );
    expect(image.width, SplashScreen.logoWidth);
  });

  group('pubspec.yaml の生成設定', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    /// 行頭から始まる `name:` のセクションの本文（次のトップレベルのキーまで）。
    String section(String name) {
      final match = RegExp(
        '^$name:\\n((?:[ #].*\\n|\\n)*)',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(match, isNotNull, reason: '$name の設定が無い');
      return match!.group(1)!;
    }

    String hex(Color color) =>
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

    List<String> values(String body, String key) => RegExp(
      '^\\s+$key:\\s*"(#[0-9A-Fa-f]{6})"',
      multiLine: true,
    ).allMatches(body).map((m) => m.group(1)!.toLowerCase()).toList();

    test('スプラッシュの背景色は Android 12 以上の設定も含めて AppColors と同じ', () {
      final splash = section('flutter_native_splash');

      // 通常の設定と android_12 の設定の 2 か所ずつ。
      expect(values(splash, 'color'), [
        hex(AppColors.brand),
        hex(AppColors.brand),
      ]);
      expect(values(splash, 'color_dark'), [
        hex(AppColors.darkBackground),
        hex(AppColors.darkBackground),
      ]);
    });

    test('アダプティブアイコンの背景はブランド色（前景の吹き出しは透過で背景色に載せる前提）', () {
      expect(
        values(section('flutter_launcher_icons'), 'adaptive_icon_background'),
        [hex(AppColors.brand)],
      );
    });

    test(
      'splash_logo.png は SplashScreen.logoWidth の 4 倍の幅（OS 側は xxxhdpi として扱うため）',
      () {
        final bytes = File('assets/branding/splash_logo.png')
            .readAsBytesSync()
            .buffer
            .asByteData();
        // PNG の IHDR の幅（シグネチャ 8 バイト + 長さ 4 + 種別 4 の後ろ）。
        final width = bytes.getUint32(16, Endian.big);

        expect(width, SplashScreen.logoWidth * 4);
      },
    );
  });
}
