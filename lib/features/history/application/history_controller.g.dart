// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 読書履歴の読み込み（`GET /api/user-volume-status/history?page=`、1 ページ 10 件）。

@ProviderFor(HistoryController)
final historyControllerProvider = HistoryControllerProvider._();

/// 読書履歴の読み込み（`GET /api/user-volume-status/history?page=`、1 ページ 10 件）。
final class HistoryControllerProvider
    extends $AsyncNotifierProvider<HistoryController, HistoryState> {
  /// 読書履歴の読み込み（`GET /api/user-volume-status/history?page=`、1 ページ 10 件）。
  HistoryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noAutoRetry,
        name: r'historyControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyControllerHash();

  @$internal
  @override
  HistoryController create() => HistoryController();
}

String _$historyControllerHash() => r'46cc5ef561ad8679e0f01714f28821c9479660fd';

/// 読書履歴の読み込み（`GET /api/user-volume-status/history?page=`、1 ページ 10 件）。

abstract class _$HistoryController extends $AsyncNotifier<HistoryState> {
  FutureOr<HistoryState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<HistoryState>, HistoryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<HistoryState>, HistoryState>,
              AsyncValue<HistoryState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
