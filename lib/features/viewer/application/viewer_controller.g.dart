// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'viewer_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ビューアの読み込みとページ送り・進捗記録。

@ProviderFor(ViewerController)
final viewerControllerProvider = ViewerControllerFamily._();

/// ビューアの読み込みとページ送り・進捗記録。
final class ViewerControllerProvider
    extends $AsyncNotifierProvider<ViewerController, ViewerState> {
  /// ビューアの読み込みとページ送り・進捗記録。
  ViewerControllerProvider._({
    required ViewerControllerFamily super.from,
    required int super.argument,
  }) : super(
         retry: noAutoRetry,
         name: r'viewerControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$viewerControllerHash();

  @override
  String toString() {
    return r'viewerControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ViewerController create() => ViewerController();

  @override
  bool operator ==(Object other) {
    return other is ViewerControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$viewerControllerHash() => r'62b16e02e913ca7ab5727afbf948306d915e5393';

/// ビューアの読み込みとページ送り・進捗記録。

final class ViewerControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ViewerController,
          AsyncValue<ViewerState>,
          ViewerState,
          FutureOr<ViewerState>,
          int
        > {
  ViewerControllerFamily._()
    : super(
        retry: noAutoRetry,
        name: r'viewerControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// ビューアの読み込みとページ送り・進捗記録。

  ViewerControllerProvider call(int volumeId) =>
      ViewerControllerProvider._(argument: volumeId, from: this);

  @override
  String toString() => r'viewerControllerProvider';
}

/// ビューアの読み込みとページ送り・進捗記録。

abstract class _$ViewerController extends $AsyncNotifier<ViewerState> {
  late final _$args = ref.$arg as int;
  int get volumeId => _$args;

  FutureOr<ViewerState> build(int volumeId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ViewerState>, ViewerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ViewerState>, ViewerState>,
              AsyncValue<ViewerState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
