// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comic_image_loader.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// アプリ共通の画像取得口。
///
/// DB とキャッシュディレクトリの用意が終わるまで解決しないため、
/// 表示側は解決まで「読み込み中」を出す（ヘッダ無しで投げて 401 にしない）。

@ProviderFor(comicImageLoader)
final comicImageLoaderProvider = ComicImageLoaderProvider._();

/// アプリ共通の画像取得口。
///
/// DB とキャッシュディレクトリの用意が終わるまで解決しないため、
/// 表示側は解決まで「読み込み中」を出す（ヘッダ無しで投げて 401 にしない）。

final class ComicImageLoaderProvider
    extends
        $FunctionalProvider<
          AsyncValue<ComicImageLoader>,
          ComicImageLoader,
          FutureOr<ComicImageLoader>
        >
    with $FutureModifier<ComicImageLoader>, $FutureProvider<ComicImageLoader> {
  /// アプリ共通の画像取得口。
  ///
  /// DB とキャッシュディレクトリの用意が終わるまで解決しないため、
  /// 表示側は解決まで「読み込み中」を出す（ヘッダ無しで投げて 401 にしない）。
  ComicImageLoaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'comicImageLoaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$comicImageLoaderHash();

  @$internal
  @override
  $FutureProviderElement<ComicImageLoader> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ComicImageLoader> create(Ref ref) {
    return comicImageLoader(ref);
  }
}

String _$comicImageLoaderHash() => r'f95ca9e5e9f2a8af22dd4307dc7315c678243d62';
