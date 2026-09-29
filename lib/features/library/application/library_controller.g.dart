// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ライブラリ一覧の読み込み。

@ProviderFor(LibraryController)
final libraryControllerProvider = LibraryControllerProvider._();

/// ライブラリ一覧の読み込み。
final class LibraryControllerProvider
    extends $AsyncNotifierProvider<LibraryController, LibraryData> {
  /// ライブラリ一覧の読み込み。
  LibraryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noAutoRetry,
        name: r'libraryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryControllerHash();

  @$internal
  @override
  LibraryController create() => LibraryController();
}

String _$libraryControllerHash() => r'27f091c60c5eddd89eb7a03a278a244fa6197c44';

/// ライブラリ一覧の読み込み。

abstract class _$LibraryController extends $AsyncNotifier<LibraryData> {
  FutureOr<LibraryData> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<LibraryData>, LibraryData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<LibraryData>, LibraryData>,
              AsyncValue<LibraryData>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 絞り込み / 並び替えの状態。

@ProviderFor(LibraryFilterController)
final libraryFilterControllerProvider = LibraryFilterControllerProvider._();

/// 絞り込み / 並び替えの状態。
final class LibraryFilterControllerProvider
    extends $NotifierProvider<LibraryFilterController, LibraryFilter> {
  /// 絞り込み / 並び替えの状態。
  LibraryFilterControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryFilterControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryFilterControllerHash();

  @$internal
  @override
  LibraryFilterController create() => LibraryFilterController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryFilter>(value),
    );
  }
}

String _$libraryFilterControllerHash() =>
    r'2f259a0b8e0ac21b4f4f08358192f7c7537d40c1';

/// 絞り込み / 並び替えの状態。

abstract class _$LibraryFilterController extends $Notifier<LibraryFilter> {
  LibraryFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LibraryFilter, LibraryFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LibraryFilter, LibraryFilter>,
              LibraryFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 表示形式（グリッド / リスト）。

@ProviderFor(LibraryViewModeController)
final libraryViewModeControllerProvider = LibraryViewModeControllerProvider._();

/// 表示形式（グリッド / リスト）。
final class LibraryViewModeControllerProvider
    extends $NotifierProvider<LibraryViewModeController, LibraryViewMode> {
  /// 表示形式（グリッド / リスト）。
  LibraryViewModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryViewModeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryViewModeControllerHash();

  @$internal
  @override
  LibraryViewModeController create() => LibraryViewModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryViewMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryViewMode>(value),
    );
  }
}

String _$libraryViewModeControllerHash() =>
    r'adaa71555c1137c0f58226169644bf227c8d9bf0';

/// 表示形式（グリッド / リスト）。

abstract class _$LibraryViewModeController extends $Notifier<LibraryViewMode> {
  LibraryViewMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LibraryViewMode, LibraryViewMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LibraryViewMode, LibraryViewMode>,
              LibraryViewMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 検索・絞り込み・並び替えを適用した一覧。

@ProviderFor(visibleBooks)
final visibleBooksProvider = VisibleBooksProvider._();

/// 検索・絞り込み・並び替えを適用した一覧。

final class VisibleBooksProvider
    extends $FunctionalProvider<List<Book>, List<Book>, List<Book>>
    with $Provider<List<Book>> {
  /// 検索・絞り込み・並び替えを適用した一覧。
  VisibleBooksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'visibleBooksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$visibleBooksHash();

  @$internal
  @override
  $ProviderElement<List<Book>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Book> create(Ref ref) {
    return visibleBooks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Book> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Book>>(value),
    );
  }
}

String _$visibleBooksHash() => r'8550a2610dffc40be670dca3b1e3439966aedf24';
