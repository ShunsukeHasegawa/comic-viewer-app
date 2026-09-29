// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// タイトル詳細の読み込みとお気に入り操作。

@ProviderFor(BookDetailController)
final bookDetailControllerProvider = BookDetailControllerFamily._();

/// タイトル詳細の読み込みとお気に入り操作。
final class BookDetailControllerProvider
    extends $AsyncNotifierProvider<BookDetailController, BookDetailData> {
  /// タイトル詳細の読み込みとお気に入り操作。
  BookDetailControllerProvider._({
    required BookDetailControllerFamily super.from,
    required int super.argument,
  }) : super(
         retry: noAutoRetry,
         name: r'bookDetailControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookDetailControllerHash();

  @override
  String toString() {
    return r'bookDetailControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BookDetailController create() => BookDetailController();

  @override
  bool operator ==(Object other) {
    return other is BookDetailControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookDetailControllerHash() =>
    r'97657ac36ea7f566db2d727458ac388c97044113';

/// タイトル詳細の読み込みとお気に入り操作。

final class BookDetailControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          BookDetailController,
          AsyncValue<BookDetailData>,
          BookDetailData,
          FutureOr<BookDetailData>,
          int
        > {
  BookDetailControllerFamily._()
    : super(
        retry: noAutoRetry,
        name: r'bookDetailControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// タイトル詳細の読み込みとお気に入り操作。

  BookDetailControllerProvider call(int bookId) =>
      BookDetailControllerProvider._(argument: bookId, from: this);

  @override
  String toString() => r'bookDetailControllerProvider';
}

/// タイトル詳細の読み込みとお気に入り操作。

abstract class _$BookDetailController extends $AsyncNotifier<BookDetailData> {
  late final _$args = ref.$arg as int;
  int get bookId => _$args;

  FutureOr<BookDetailData> build(int bookId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<BookDetailData>, BookDetailData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<BookDetailData>, BookDetailData>,
              AsyncValue<BookDetailData>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
