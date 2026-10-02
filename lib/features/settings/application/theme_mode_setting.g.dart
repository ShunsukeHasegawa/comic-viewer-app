// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode_setting.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(themeModeStore)
final themeModeStoreProvider = ThemeModeStoreProvider._();

final class ThemeModeStoreProvider
    extends $FunctionalProvider<ThemeModeStore, ThemeModeStore, ThemeModeStore>
    with $Provider<ThemeModeStore> {
  ThemeModeStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeStoreHash();

  @$internal
  @override
  $ProviderElement<ThemeModeStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeModeStore create(Ref ref) {
    return themeModeStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeModeStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeModeStore>(value),
    );
  }
}

String _$themeModeStoreHash() => r'48afff06767e1c784c365db1061693f6e865bcf9';

/// 表示テーマの設定。
///
/// アプリ全体（`ComicLazApp`）が watch する。起動直後の切り替わりを避けるため、
/// `main` で最初の画面を描く前に [preloadThemeMode] で読み込んでおく。
///
/// 読めなかったときに自動で再試行しない。再試行の間（最大 40 秒ほど）は
/// 読み込み中として切り替えも塞がれ、そのうえ読めた時点で画面全体の色が
/// 前触れなく変わる。端末内の DB が読めないのは一時的なことではまず無いので、
/// 「読み込めなかった」と出して選び直してもらう（保存できればそれで直る）。

@ProviderFor(ThemeModeSetting)
final themeModeSettingProvider = ThemeModeSettingProvider._();

/// 表示テーマの設定。
///
/// アプリ全体（`ComicLazApp`）が watch する。起動直後の切り替わりを避けるため、
/// `main` で最初の画面を描く前に [preloadThemeMode] で読み込んでおく。
///
/// 読めなかったときに自動で再試行しない。再試行の間（最大 40 秒ほど）は
/// 読み込み中として切り替えも塞がれ、そのうえ読めた時点で画面全体の色が
/// 前触れなく変わる。端末内の DB が読めないのは一時的なことではまず無いので、
/// 「読み込めなかった」と出して選び直してもらう（保存できればそれで直る）。
final class ThemeModeSettingProvider
    extends $AsyncNotifierProvider<ThemeModeSetting, ThemeMode> {
  /// 表示テーマの設定。
  ///
  /// アプリ全体（`ComicLazApp`）が watch する。起動直後の切り替わりを避けるため、
  /// `main` で最初の画面を描く前に [preloadThemeMode] で読み込んでおく。
  ///
  /// 読めなかったときに自動で再試行しない。再試行の間（最大 40 秒ほど）は
  /// 読み込み中として切り替えも塞がれ、そのうえ読めた時点で画面全体の色が
  /// 前触れなく変わる。端末内の DB が読めないのは一時的なことではまず無いので、
  /// 「読み込めなかった」と出して選び直してもらう（保存できればそれで直る）。
  ThemeModeSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: noAutoRetry,
        name: r'themeModeSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeSettingHash();

  @$internal
  @override
  ThemeModeSetting create() => ThemeModeSetting();
}

String _$themeModeSettingHash() => r'058844abe30fe323e0fb772878d0a0c82e65dcbc';

/// 表示テーマの設定。
///
/// アプリ全体（`ComicLazApp`）が watch する。起動直後の切り替わりを避けるため、
/// `main` で最初の画面を描く前に [preloadThemeMode] で読み込んでおく。
///
/// 読めなかったときに自動で再試行しない。再試行の間（最大 40 秒ほど）は
/// 読み込み中として切り替えも塞がれ、そのうえ読めた時点で画面全体の色が
/// 前触れなく変わる。端末内の DB が読めないのは一時的なことではまず無いので、
/// 「読み込めなかった」と出して選び直してもらう（保存できればそれで直る）。

abstract class _$ThemeModeSetting extends $AsyncNotifier<ThemeMode> {
  FutureOr<ThemeMode> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ThemeMode>, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ThemeMode>, ThemeMode>,
              AsyncValue<ThemeMode>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
