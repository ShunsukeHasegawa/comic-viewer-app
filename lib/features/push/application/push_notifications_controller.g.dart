// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_notifications_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pushClock)
final pushClockProvider = PushClockProvider._();

final class PushClockProvider
    extends $FunctionalProvider<PushClock, PushClock, PushClock>
    with $Provider<PushClock> {
  PushClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushClockHash();

  @$internal
  @override
  $ProviderElement<PushClock> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushClock create(Ref ref) {
    return pushClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushClock value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushClock>(value),
    );
  }
}

String _$pushClockHash() => r'c3082d961750fadbe878ab90611be4246dd0595b';

@ProviderFor(pushRouteOpener)
final pushRouteOpenerProvider = PushRouteOpenerProvider._();

final class PushRouteOpenerProvider
    extends
        $FunctionalProvider<PushRouteOpener, PushRouteOpener, PushRouteOpener>
    with $Provider<PushRouteOpener> {
  PushRouteOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushRouteOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushRouteOpenerHash();

  @$internal
  @override
  $ProviderElement<PushRouteOpener> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushRouteOpener create(Ref ref) {
    return pushRouteOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushRouteOpener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushRouteOpener>(value),
    );
  }
}

String _$pushRouteOpenerHash() => r'1c9821284f746387204871df83057208ca6940af';

/// プッシュ通知（#14）。トークンの登録 / 解除、前面での表示、通知を押したときの遷移。
///
/// - ログイン / 起動時の復元で、設定が ON なら許可を確かめてトークンを登録する。
/// - 同じユーザー・同じトークンを [reRegisterInterval] 以内に登録済みなら送らない
///   （サーバーは `last_used_at` を更新するだけ。自宅サーバーを叩きすぎない）。
///   前面復帰でも同じ規則で確かめるので、送るのは 1 日 1 回まで。
/// - トークンが変わったら（`onTokenRefresh`）登録し直す。
/// - ログアウトはトークンを消す**前に**サーバーの登録を消す
///   （[unregisterBeforeSignOut]。DELETE に Bearer が要る）。その後で端末側の
///   トークンも捨てる（[PushTokenEraser]。失効時はこちらだけ）。
///
/// 失敗は黙らない。自動の登録の失敗は設定画面に出し、前面復帰でのやり直しは
/// [retryInterval] に 1 回まで（ログイン / トークンの更新 / ユーザー操作はすぐ
/// やり直す）。ユーザー操作の失敗は呼び出し側に投げ（SnackBar）、状態にも残す。

@ProviderFor(PushNotifications)
final pushNotificationsProvider = PushNotificationsProvider._();

/// プッシュ通知（#14）。トークンの登録 / 解除、前面での表示、通知を押したときの遷移。
///
/// - ログイン / 起動時の復元で、設定が ON なら許可を確かめてトークンを登録する。
/// - 同じユーザー・同じトークンを [reRegisterInterval] 以内に登録済みなら送らない
///   （サーバーは `last_used_at` を更新するだけ。自宅サーバーを叩きすぎない）。
///   前面復帰でも同じ規則で確かめるので、送るのは 1 日 1 回まで。
/// - トークンが変わったら（`onTokenRefresh`）登録し直す。
/// - ログアウトはトークンを消す**前に**サーバーの登録を消す
///   （[unregisterBeforeSignOut]。DELETE に Bearer が要る）。その後で端末側の
///   トークンも捨てる（[PushTokenEraser]。失効時はこちらだけ）。
///
/// 失敗は黙らない。自動の登録の失敗は設定画面に出し、前面復帰でのやり直しは
/// [retryInterval] に 1 回まで（ログイン / トークンの更新 / ユーザー操作はすぐ
/// やり直す）。ユーザー操作の失敗は呼び出し側に投げ（SnackBar）、状態にも残す。
final class PushNotificationsProvider
    extends $NotifierProvider<PushNotifications, PushStatus> {
  /// プッシュ通知（#14）。トークンの登録 / 解除、前面での表示、通知を押したときの遷移。
  ///
  /// - ログイン / 起動時の復元で、設定が ON なら許可を確かめてトークンを登録する。
  /// - 同じユーザー・同じトークンを [reRegisterInterval] 以内に登録済みなら送らない
  ///   （サーバーは `last_used_at` を更新するだけ。自宅サーバーを叩きすぎない）。
  ///   前面復帰でも同じ規則で確かめるので、送るのは 1 日 1 回まで。
  /// - トークンが変わったら（`onTokenRefresh`）登録し直す。
  /// - ログアウトはトークンを消す**前に**サーバーの登録を消す
  ///   （[unregisterBeforeSignOut]。DELETE に Bearer が要る）。その後で端末側の
  ///   トークンも捨てる（[PushTokenEraser]。失効時はこちらだけ）。
  ///
  /// 失敗は黙らない。自動の登録の失敗は設定画面に出し、前面復帰でのやり直しは
  /// [retryInterval] に 1 回まで（ログイン / トークンの更新 / ユーザー操作はすぐ
  /// やり直す）。ユーザー操作の失敗は呼び出し側に投げ（SnackBar）、状態にも残す。
  PushNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushNotificationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushNotificationsHash();

  @$internal
  @override
  PushNotifications create() => PushNotifications();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushStatus>(value),
    );
  }
}

String _$pushNotificationsHash() => r'6058446e9e99d18172822cb54f9d7885020ecebc';

/// プッシュ通知（#14）。トークンの登録 / 解除、前面での表示、通知を押したときの遷移。
///
/// - ログイン / 起動時の復元で、設定が ON なら許可を確かめてトークンを登録する。
/// - 同じユーザー・同じトークンを [reRegisterInterval] 以内に登録済みなら送らない
///   （サーバーは `last_used_at` を更新するだけ。自宅サーバーを叩きすぎない）。
///   前面復帰でも同じ規則で確かめるので、送るのは 1 日 1 回まで。
/// - トークンが変わったら（`onTokenRefresh`）登録し直す。
/// - ログアウトはトークンを消す**前に**サーバーの登録を消す
///   （[unregisterBeforeSignOut]。DELETE に Bearer が要る）。その後で端末側の
///   トークンも捨てる（[PushTokenEraser]。失効時はこちらだけ）。
///
/// 失敗は黙らない。自動の登録の失敗は設定画面に出し、前面復帰でのやり直しは
/// [retryInterval] に 1 回まで（ログイン / トークンの更新 / ユーザー操作はすぐ
/// やり直す）。ユーザー操作の失敗は呼び出し側に投げ（SnackBar）、状態にも残す。

abstract class _$PushNotifications extends $Notifier<PushStatus> {
  PushStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PushStatus, PushStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PushStatus, PushStatus>,
              PushStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
