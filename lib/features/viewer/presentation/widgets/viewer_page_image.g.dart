// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'viewer_page_image.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 既定はディスクキャッシュつきのネットワーク画像。
///
/// **読み込み完了まで画像を出さない**（途中まで描かれた JPEG を見せない）。
/// 取得元の解決順（ダウンロード済みローカル → キャッシュ → ネットワーク）は
/// #11 でここに差し込む。

@ProviderFor(viewerImageBuilder)
final viewerImageBuilderProvider = ViewerImageBuilderProvider._();

/// 既定はディスクキャッシュつきのネットワーク画像。
///
/// **読み込み完了まで画像を出さない**（途中まで描かれた JPEG を見せない）。
/// 取得元の解決順（ダウンロード済みローカル → キャッシュ → ネットワーク）は
/// #11 でここに差し込む。

final class ViewerImageBuilderProvider
    extends
        $FunctionalProvider<
          ViewerImageBuilder,
          ViewerImageBuilder,
          ViewerImageBuilder
        >
    with $Provider<ViewerImageBuilder> {
  /// 既定はディスクキャッシュつきのネットワーク画像。
  ///
  /// **読み込み完了まで画像を出さない**（途中まで描かれた JPEG を見せない）。
  /// 取得元の解決順（ダウンロード済みローカル → キャッシュ → ネットワーク）は
  /// #11 でここに差し込む。
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
    r'830f2468c3e927044acb1e2bfcfc83cce7279542';

/// 既定はデコードまで済ませる `precacheImage`。

@ProviderFor(pagePrecacher)
final pagePrecacherProvider = PagePrecacherProvider._();

/// 既定はデコードまで済ませる `precacheImage`。

final class PagePrecacherProvider
    extends $FunctionalProvider<PagePrecacher, PagePrecacher, PagePrecacher>
    with $Provider<PagePrecacher> {
  /// 既定はデコードまで済ませる `precacheImage`。
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

String _$pagePrecacherHash() => r'b06a7acbdfc3097cc8a99691c0e80964ed58ab1c';
