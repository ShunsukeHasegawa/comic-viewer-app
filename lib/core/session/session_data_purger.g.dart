// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_data_purger.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 登録済みの破棄処理。各機能の Issue で override して追加する。

@ProviderFor(sessionDataPurgers)
final sessionDataPurgersProvider = SessionDataPurgersProvider._();

/// 登録済みの破棄処理。各機能の Issue で override して追加する。

final class SessionDataPurgersProvider
    extends
        $FunctionalProvider<
          List<SessionDataPurger>,
          List<SessionDataPurger>,
          List<SessionDataPurger>
        >
    with $Provider<List<SessionDataPurger>> {
  /// 登録済みの破棄処理。各機能の Issue で override して追加する。
  SessionDataPurgersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionDataPurgersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionDataPurgersHash();

  @$internal
  @override
  $ProviderElement<List<SessionDataPurger>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<SessionDataPurger> create(Ref ref) {
    return sessionDataPurgers(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SessionDataPurger> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SessionDataPurger>>(value),
    );
  }
}

String _$sessionDataPurgersHash() =>
    r'b0a24cabe4ee741728c6a2b74a770778d9f37d3c';
