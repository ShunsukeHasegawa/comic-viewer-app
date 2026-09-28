import 'package:comic_laz/core/theme/app_colors.dart';
import 'package:comic_laz/core/theme/app_theme.dart';
import 'package:comic_laz/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG のコントラスト比。
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('dark テーマはダーク基調の背景を使う', () {
    final theme = AppTheme.dark();

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.surface, AppColors.darkBackground);
    expect(theme.scaffoldBackgroundColor, AppColors.darkBackground);
    // 濃いブランド色は塗り面として残す
    expect(theme.colorScheme.primaryContainer, AppColors.brand);
  });

  test('light テーマはブランド色をそのまま primary に使う', () {
    final theme = AppTheme.light();

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, AppColors.brand);
    expect(theme.scaffoldBackgroundColor, AppColors.lightBackground);
  });

  test('FilledButton のラベルが読める（onPrimary と primary のコントラスト）', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final scheme = theme.colorScheme;
      expect(
        contrastRatio(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
        reason: '${scheme.brightness}: onPrimary がボタン背景に埋もれている',
      );
      expect(
        contrastRatio(scheme.onPrimaryContainer, scheme.primaryContainer),
        greaterThanOrEqualTo(4.5),
        reason: '${scheme.brightness}: onPrimaryContainer が読めない',
      );
    }
  });

  test('primary はアイコン / テキストとして背景から識別できる', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final scheme = theme.colorScheme;
      expect(
        contrastRatio(scheme.primary, scheme.surface),
        greaterThanOrEqualTo(3),
        reason: '${scheme.brightness}: primary が背景に溶けている',
      );
      expect(
        contrastRatio(scheme.primary, scheme.surfaceContainer),
        greaterThanOrEqualTo(3),
        reason: '${scheme.brightness}: ナビゲーションバー上の primary が見えない',
      );
    }
  });

  test('dark の面はすべて青みの統一されたランプになっている', () {
    final scheme = AppTheme.dark().colorScheme;
    final tiers = [
      scheme.surfaceContainerLowest,
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
      scheme.surfaceContainerHigh,
      scheme.surfaceContainerHighest,
    ];

    for (final color in tiers) {
      // 青 > 緑 > 赤（灰色に転ばない）
      expect(color.b, greaterThan(color.g), reason: '$color が灰色寄り');
      expect(color.g, greaterThanOrEqualTo(color.r), reason: '$color が灰色寄り');
    }
    // 低い面から高い面へ単調に明るくなる
    for (var i = 1; i < tiers.length; i++) {
      expect(
        tiers[i].computeLuminance(),
        greaterThan(tiers[i - 1].computeLuminance()),
        reason: '面の明度が単調でない: ${tiers[i - 1]} -> ${tiers[i]}',
      );
    }
  });

  test('日本語フォントのフォールバックが設定されている', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(theme.textTheme.bodyMedium?.fontFamily, AppTypography.fontFamily);
      expect(
        theme.textTheme.bodyMedium?.fontFamilyFallback,
        AppTypography.fontFamilyFallback,
      );
    }
  });
}
