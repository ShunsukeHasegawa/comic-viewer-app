import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// アプリのテーマ定義（Light / Dark 両対応）。
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = brightness == Brightness.dark
        ? _darkScheme()
        : _lightScheme();

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primary.withValues(
          alpha: brightness == Brightness.dark ? 0.32 : 0.16,
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
    );
  }

  static ColorScheme _lightScheme() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.light,
    );
    return base.copyWith(
      primary: AppColors.brand,
      onPrimary: AppColors.onBrand,
      surface: AppColors.lightBackground,
    );
  }

  static ColorScheme _darkScheme() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.dark,
    );
    // ダークでは前景に使える明るい teal を `primary` にし、
    // 濃いブランド色は塗り面（`primaryContainer`）側へ回す。
    return base.copyWith(
      primary: AppColors.brandLight,
      onPrimary: AppColors.onBrandLight,
      primaryContainer: AppColors.brand,
      onPrimaryContainer: AppColors.onBrand,
      surface: AppColors.darkBackground,
      surfaceDim: AppColors.darkBackground,
      surfaceBright: AppColors.darkSurfaceHighest,
      surfaceContainerLowest: AppColors.darkSurfaceLowest,
      surfaceContainerLow: AppColors.darkSurfaceLow,
      surfaceContainer: AppColors.darkSurfaceContainer,
      surfaceContainerHigh: AppColors.darkSurfaceHigh,
      surfaceContainerHighest: AppColors.darkSurfaceHighest,
    );
  }
}
