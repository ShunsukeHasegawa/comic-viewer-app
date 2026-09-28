import 'package:flutter/material.dart';

/// Comic LAZ のブランドカラー（Web 版と揃える）。
abstract final class AppColors {
  /// アクセント（teal）。ライトテーマの `primary`、ダークテーマの `primaryContainer`。
  static const brand = Color(0xFF244C60);

  /// ダーク背景の上で前景色（アイコン・ラベル）として使える明るい teal。
  ///
  /// `brand` 自体は暗すぎて `#0a0f1a` 上では 2:1 程度しかコントラストが出ないため、
  /// ダークテーマの `primary` にはこちらを使う。
  static const brandLight = Color(0xFF7FB3C8);

  /// `brandLight` の上に載せる文字色。
  static const onBrandLight = Color(0xFF08222E);

  /// `brand` の上に載せる文字色。
  static const onBrand = Color(0xFFFFFFFF);

  /// ダーク基調の背景色。
  static const darkBackground = Color(0xFF0A0F1A);

  /// ダーク時の面（低い順）。青みを統一し、ダイアログやシートだけ灰色に浮かないようにする。
  static const darkSurfaceLowest = Color(0xFF070B13);
  static const darkSurfaceLow = Color(0xFF0F1522);
  static const darkSurfaceContainer = Color(0xFF141B2B);
  static const darkSurfaceHigh = Color(0xFF1A2334);
  static const darkSurfaceHighest = Color(0xFF212C3F);

  /// ライト時の背景色。
  static const lightBackground = Color(0xFFF7F8FA);

  /// ビューアの背景（テーマに依らず黒）。
  static const viewerBackground = Color(0xFF000000);
}
