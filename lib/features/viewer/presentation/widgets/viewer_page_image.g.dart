// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'viewer_page_image.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 既定は自前の一時キャッシュ（#8）経由の画像。
///
/// **読み込み完了まで画像を出さない**（途中まで描かれた JPEG を見せない）。
/// 取得元の解決順（ダウンロード済みローカル → キャッシュ → ネットワーク）は
/// `ComicImageLoader` に集約してある（#11）。ここは描画だけを受け持つ。

@ProviderFor(viewerImageBuilder)
final viewerImageBuilderProvider = ViewerImageBuilderProvider._();

/// 既定は自前の一時キャッシュ（#8）経由の画像。
///
/// **読み込み完了まで画像を出さない**（途中まで描かれた JPEG を見せない）。
/// 取得元の解決順（ダウンロード済みローカル → キャッシュ → ネットワーク）は
/// `ComicImageLoader` に集約してある（#11）。ここは描画だけを受け持つ。

final class ViewerImageBuilderProvider
    extends
        $FunctionalProvider<
          ViewerImageBuilder,
          ViewerImageBuilder,
          ViewerImageBuilder
        >
    with $Provider<ViewerImageBuilder> {
  /// 既定は自前の一時キャッシュ（#8）経由の画像。
  ///
  /// **読み込み完了まで画像を出さない**（途中まで描かれた JPEG を見せない）。
  /// 取得元の解決順（ダウンロード済みローカル → キャッシュ → ネットワーク）は
  /// `ComicImageLoader` に集約してある（#11）。ここは描画だけを受け持つ。
  ViewerImageBuilderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewerImageBuilderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewerImageBuilderHash();

  @$internal
  @override
  $ProviderElement<ViewerImageBuilder> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ViewerImageBuilder create(Ref ref) {
    return viewerImageBuilder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewerImageBuilder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewerImageBuilder>(value),
    );
  }
}

String _$viewerImageBuilderHash() =>
    r'56188852847f8f74a8ec63f19fffdad05ed063bf';

/// 既定はデコードまで済ませる `precacheImage`。
///
/// 表示と同じ [ComicImageProvider] を使う（同じキャッシュを温める。
/// 先読みだけ別経路にすると二重ダウンロードになる）。

@ProviderFor(pagePrecacher)
final pagePrecacherProvider = PagePrecacherProvider._();

/// 既定はデコードまで済ませる `precacheImage`。
///
/// 表示と同じ [ComicImageProvider] を使う（同じキャッシュを温める。
/// 先読みだけ別経路にすると二重ダウンロードになる）。

final class PagePrecacherProvider
    extends $FunctionalProvider<PagePrecacher, PagePrecacher, PagePrecacher>
    with $Provider<PagePrecacher> {
  /// 既定はデコードまで済ませる `precacheImage`。
  ///
  /// 表示と同じ [ComicImageProvider] を使う（同じキャッシュを温める。
  /// 先読みだけ別経路にすると二重ダウンロードになる）。
  PagePrecacherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pagePrecacherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pagePrecacherHash();

  @$internal
  @override
  $ProviderElement<PagePrecacher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PagePrecacher create(Ref ref) {
    return pagePrecacher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PagePrecacher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PagePrecacher>(value),
    );
  }
}

String _$pagePrecacherHash() => r'6fcde774b0706e7a735001ea09306ec458b2c987';
