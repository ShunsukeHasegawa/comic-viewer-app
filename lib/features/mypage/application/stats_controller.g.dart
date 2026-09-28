// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 読書統計（`GET /api/v2/user/stats`）。

@ProviderFor(StatsController)
final statsControllerProvider = StatsControllerProvider._();

/// 読書統計（`GET /api/v2/user/stats`）。
final class StatsControllerProvider
    extends $AsyncNotifierProvider<StatsController, UserStats> {
  /// 読書統計（`GET /api/v2/user/stats`）。
  StatsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noAutoRetry,
        name: r'statsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$statsControllerHash();

  @$internal
  @override
  StatsController create() => StatsController();
}

String _$statsControllerHash() => r'd62186b4f39ee42fd78aae416b9f1c9ce45f2c97';

/// 読書統計（`GET /api/v2/user/stats`）。

abstract class _$StatsController extends $AsyncNotifier<UserStats> {
  FutureOr<UserStats> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<UserStats>, UserStats>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UserStats>, UserStats>,
              AsyncValue<UserStats>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
