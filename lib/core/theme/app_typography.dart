/// フォント設定。
///
/// `Noto Sans JP` は端末にあれば使われ、無ければ [fontFamilyFallback] →
/// OS 既定フォントの順で解決される（日本語は OS 既定でも表示できる）。
/// 表示を完全に固定したい場合は `assets/fonts/` に同梱して
/// `pubspec.yaml` の `fonts:` に登録する。
abstract final class AppTypography {
  static const fontFamily = 'Noto Sans JP';

  static const fontFamilyFallback = <String>[
    'Hiragino Sans',
    'Hiragino Kaku Gothic ProN',
    'Yu Gothic',
    'Meiryo',
    'Noto Sans CJK JP',
  ];
}
