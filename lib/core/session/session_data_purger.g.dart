// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_data_purger.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 登録済みの破棄処理。
///
/// 端末内にユーザー固有のデータを持つ機能は、ここに実装を足す
/// （画像キャッシュ #8 / ダウンロード #9 / 進捗 #12）。

@ProviderFor(sessionDataPurgers)
final sessionDataPurgersProvider = SessionDataPurgersProvider._();

/// 登録済みの破棄処理。
///
/// 端末内にユーザー固有のデータを持つ機能は、ここに実装を足す
/// （画像キャッシュ #8 / ダウンロード #9 / 進捗 #12）。

final class SessionDataPurgersProvider
    extends
        $FunctionalProvider<
          List<SessionDataPurger>,
          List<SessionDataPurger>,
          List<SessionDataPurger>
        >
    with $Provider<List<SessionDataPurger>> {
  /// 登録済みの破棄処理。
  ///
  /// 端末内にユーザー固有のデータを持つ機能は、ここに実装を足す
  /// （画像キャッシュ #8 / ダウンロード #9 / 進捗 #12）。
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
    r'fe7e0f712fc87ebd949561403bdd057a8ce06ff4';
