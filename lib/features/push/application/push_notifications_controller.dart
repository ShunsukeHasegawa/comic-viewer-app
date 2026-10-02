import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/device/app_resume_monitor.dart';
import '../../../core/device/device_name_resolver.dart';
import '../../../core/device/notification_permission_log.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../data/api/device_token_api.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../data/foreground_notifier.dart';
import '../data/push_messaging.dart';
import '../data/push_settings_store.dart';
import '../domain/push_message.dart';
import '../domain/push_status.dart';
import 'push_token_eraser.dart';

part 'push_notifications_controller.g.dart';

typedef PushClock = DateTime Function();

@Riverpod(keepAlive: true)
PushClock pushClock(Ref ref) => DateTime.now;

/// 通知を押したときに画面を開く。
///
/// `go`（積まずに置き換える）にする。通知から開いたタイトル詳細は戻り先が
/// 無く、`AppBackButton` がライブラリへ戻す（ディープリンクと同じ扱い）。
/// ログイン前 / トークンの確認中に呼ばれても、ルータの redirect が `from` に
/// 引き継いでログイン後に開く。
typedef PushRouteOpener = void Function(String location);

@Riverpod(keepAlive: true)
PushRouteOpener pushRouteOpener(Ref ref) =>
    (location) => ref.read(routerProvider).go(location);

/// サーバーへ送る `platform`。
@visibleForTesting
String? pushPlatformName(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => DeviceTokenApi.platformAndroid,
  TargetPlatform.iOS => DeviceTokenApi.platformIos,
  _ => null,
};

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
@Riverpod(keepAlive: true)
class PushNotifications extends _$PushNotifications {
  /// 同じトークンを登録し直すまでの間隔。
  static const reRegisterInterval = Duration(hours: 24);

  /// 自動の登録が失敗した後、前面復帰でやり直すまでの間隔。
  ///
  /// 自宅サーバー（HDD）が落ちている / 5xx を返している間に、アプリを
  /// 切り替えるたびに POST しない（`SafeModeRevalidator` の前面復帰と同じ 1 時間）。
  static const retryInterval = Duration(hours: 1);

  /// ログアウトでサーバーの登録を消すのを待つ上限（ログアウトを止めない）。
  static const signOutTimeout = Duration(seconds: 5);

  late Future<bool> _ready;

  /// 登録 / 解除を 1 本ずつ流す（設定の連打や前面復帰が重なっても順に処理する）。
  Future<void> _queue = Future.value();

  final _subscriptions = <StreamSubscription<Object?>>[];

  /// 自動の確かめがキューで待っている（まだ始まっていない）か。
  ///
  /// 待っている間に頼まれた分は、その 1 回にまとめる（始まった時点の
  /// 状態を読むので取りこぼさない）。起動時に初期化の終わりと復元の
  /// 両方から頼まれても、失敗時に POST を 2 回続けて送らないため。
  bool _syncQueued = false;

  /// 待っている確かめのどれかが [retryInterval] の間引きを飛ばしてよいか。
  bool _queuedBypassBackoff = false;

  /// 直近の登録の失敗の時刻（成功で消える）。メモリだけに持つ: 次の起動では
  /// 一度やり直してよい。
  DateTime? _lastFailureAt;

  /// 送信中の登録。応答が来るまで控えに無いので、ログアウトではこれも消す。
  ({String token, Future<void> request})? _registering;

  @override
  PushStatus build() {
    ref.onDispose(() {
      for (final subscription in _subscriptions) {
        unawaited(subscription.cancel());
      }
      _subscriptions.clear();
    });
    ref.listen(authControllerProvider, _onAuthChanged);
    _subscriptions.add(
      ref
          .read(appResumeMonitorProvider)
          .onResumed
          .listen((_) => _scheduleSync()),
    );
    _ready = _initialize();
    return const PushStatus();
  }

  // ------------------------------------------------------------ 画面からの操作

  /// 「新刊通知」の切り替え。保存できなければ投げる（表示は変えない）。
  ///
  /// ON はその場で許可を求めて登録する（断られた後でも聞き直す。ユーザーが
  /// 自分で ON にしたので）。OFF はサーバーの登録を消し、端末のトークンも捨てる
  /// （DELETE が通らなくても届かなくなるように）。どちらも、できなければ投げ、
  /// 失敗を状態にも残す（SnackBar が消えた後も「登録しています…」/「通知しません」
  /// と事実と違う表示を続けない）。
  Future<void> setEnabled(bool enabled) => _enqueue(() async {
    await ref.read(pushSettingsStoreProvider).writeEnabled(enabled);
    if (!ref.mounted) return;
    state = state.copyWith(enabled: enabled, failure: null);
    if (!await _ready || !ref.mounted) return;
    try {
      if (enabled) {
        await _sync(userInitiated: true);
      } else {
        await _unregister(awaitErase: true);
      }
    } on Object catch (error) {
      if (ref.mounted) {
        if (enabled) _lastFailureAt = ref.read(pushClockProvider)();
        state = state.copyWith(
          registered: false,
          failure: describePushError(error),
        );
      }
      rethrow;
    }
  });

  /// テスト通知を送ってもらう（このユーザーの全端末に届く）。
  Future<void> sendTest() => ref.read(deviceTokenApiProvider).sendTest();

  /// OS の通知設定を開く（断った後に許可してもらう導線）。
  Future<void> openSystemSettings() =>
      ref.read(foregroundNotificationsProvider).openSystemSettings();

  // ------------------------------------------------------------ 認証からの呼び出し

  /// 明示的なログアウトの前に、この端末の登録をサーバーから消す。
  ///
  /// `AuthController.logout` がトークンを失効させる**前に**呼ぶ（後だと Bearer が
  /// 無効で消せない）。[signOutTimeout] を超えたら待たずに戻る（ログアウトを
  /// 止めない。消し損ねた行は端末のトークンを捨てたことで FCM が無効と返し、
  /// サーバーが送信時に掃除する）。投げない。
  ///
  /// 待つのをやめても DELETE 自体は続く。遅れて戻ってきたときに次のセッションの
  /// 登録を消さないよう、[_unregister] が世代を見て後始末を飛ばす。
  Future<void> unregisterBeforeSignOut() async {
    try {
      await _unregister().timeout(signOutTimeout);
    } on Object catch (error) {
      debugPrint('[push] unregister before sign-out failed: $error');
    }
  }

  // ------------------------------------------------------------ 内部

  Future<bool> _initialize() async {
    final messaging = ref.read(pushMessagingProvider);
    var enabled = true;
    try {
      enabled = await ref.read(pushSettingsStoreProvider).readEnabled();
    } on Object catch (error) {
      // 読めなければ既定（ON）として扱う。保存し直せば直る。
      debugPrint('[push] read setting failed: $error');
    }
    if (!ref.mounted) return false;
    final available = await messaging.initialize();
    if (!ref.mounted) return false;
    state = state.copyWith(
      availability: available
          ? PushAvailability.available
          : PushAvailability.unavailable,
      enabled: enabled,
    );
    if (!available) return false;

    final notifier = ref.read(foregroundNotificationsProvider);
    try {
      await notifier.initialize(onTap: _open);
    } on Object catch (error) {
      // 前面での表示だけが出なくなる（背面の通知は OS が出す）。
      debugPrint('[push] local notifications init failed: $error');
    }
    if (!ref.mounted) return false;
    _subscriptions
      // 新しいトークンは登録しないと届かないので、失敗の後でもすぐ送る。
      ..add(
        messaging.onTokenRefresh.listen(
          (_) => _scheduleSync(bypassBackoff: true),
        ),
      )
      ..add(messaging.onMessage.listen(_showInForeground))
      ..add(messaging.onMessageOpenedApp.listen((m) => _open(m.data)));

    // 終了中に通知を押して起動した（OS が出した通知 / 前面で出した通知）。
    try {
      final initial = await messaging.getInitialMessage();
      if (!ref.mounted) return false;
      if (initial != null) {
        _open(initial.data);
      } else if (await notifier.takeLaunchData() case final data?) {
        if (!ref.mounted) return false;
        _open(data);
      }
    } on Object catch (error) {
      debugPrint('[push] read launch message failed: $error');
    }
    if (!ref.mounted) return false;
    // 前回消せなかったトークンを消し直し、ログイン済みなら登録を確かめる。
    _scheduleSync();
    return true;
  }

  void _onAuthChanged(AuthState? previous, AuthState next) {
    if (next is AuthAuthenticated) {
      final previousUser = previous is AuthAuthenticated
          ? previous.user.id
          : null;
      // ログインは利用者の操作なので、失敗の後でも間引かない。
      if (previousUser != next.user.id) _scheduleSync(bypassBackoff: true);
      return;
    }
    if (previous is AuthAuthenticated) {
      // 登録は前のセッションのもの。トークンを捨てるのは破棄（PushRegistrationPurger）。
      state = state.copyWith(registered: false, failure: null);
    }
  }

  /// 自動の確かめ（起動 / ログイン / 前面復帰 / トークンの更新）。
  ///
  /// [bypassBackoff] が `false`（前面復帰 / 起動）なら、直前の失敗から
  /// [retryInterval] の間は POST しない。
  void _scheduleSync({bool bypassBackoff = false}) {
    _queuedBypassBackoff = _queuedBypassBackoff || bypassBackoff;
    if (_syncQueued) return;
    _syncQueued = true;
    unawaited(
      _enqueue(() async {
        final ready = await _ready.catchError((Object _) => false);
        // ここから先に頼まれた分は次の 1 回に回す（この回はもう状態を読み始める）。
        _syncQueued = false;
        final bypass = _queuedBypassBackoff;
        _queuedBypassBackoff = false;
        if (!ready || !ref.mounted) return;
        try {
          await _sync(userInitiated: false, bypassBackoff: bypass);
        } on Object catch (error) {
          debugPrint('[push] register failed: $error');
          if (!ref.mounted) return;
          _lastFailureAt = ref.read(pushClockProvider)();
          state = state.copyWith(
            registered: false,
            failure: describePushError(error),
          );
        }
      }),
    );
  }

  /// 登録を確かめ、要るときだけ POST する。
  Future<void> _sync({
    required bool userInitiated,
    bool bypassBackoff = false,
  }) async {
    final eraser = ref.read(pushTokenEraserProvider);
    // 前のセッション / OFF で捨てると決めたトークンを先に捨てる（ログインして
    // いなくても）。消せなくても続ける: 下の登録が通ればサーバーが持ち主を
    // 移すので、前のユーザーには届かなくなる。
    final flushed = await eraser.flush();
    if (!ref.mounted) return;
    if (flushed && state.enabled == false && state.failure != null) {
      // OFF にしたときに止めきれなかったトークンを、いま捨てられた。
      state = state.copyWith(failure: null);
    }

    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) return;
    final userId = auth.user.id;
    final generation = eraser.generation;
    // 途中でセッションが終わった / OFF にした / 別のユーザーになったら結果を捨てる。
    bool stale() {
      if (!ref.mounted || eraser.generation != generation) return true;
      final current = ref.read(authControllerProvider);
      return current is! AuthAuthenticated || current.user.id != userId;
    }

    final store = ref.read(pushSettingsStoreProvider);
    final enabled = await store.readEnabled();
    if (stale()) return;
    state = state.copyWith(enabled: enabled);
    if (!enabled) return;

    final messaging = ref.read(pushMessagingProvider);
    var permission = await messaging.permissionStatus();
    if (stale()) return;
    if (permission != PushPermission.granted &&
        (userInitiated || !await _permissionAlreadyRequested())) {
      if (stale()) return;
      await ref.read(notificationPermissionLogProvider).markRequested();
      permission = await messaging.requestPermission();
      if (stale()) return;
    }
    state = state.copyWith(permission: permission);
    // 断られたら登録しない（届いても出せない通知をサーバーに送らせない）。
    // OS の設定で許可されたら、次の前面復帰で登録する。
    if (permission != PushPermission.granted) {
      state = state.copyWith(registered: false, failure: null);
      return;
    }

    final token = await messaging.getToken();
    if (stale()) return;
    if (token == null || token.isEmpty) {
      throw const PushRegistrationException('通知用のトークンを取得できませんでした。');
    }
    final now = ref.read(pushClockProvider)();
    final saved = await store.readRegistration();
    if (stale()) return;
    if (!userInitiated && _isFresh(saved, userId: userId, token: token, now)) {
      state = state.copyWith(registered: true, failure: null);
      return;
    }
    if (!userInitiated && !bypassBackoff && _backingOff(now)) {
      // 直前に失敗したばかり。失敗の表示は残したまま、間隔を空けてやり直す。
      return;
    }

    final deviceName = await ref.read(deviceNameResolverProvider).resolve();
    // ここより後に始まった解除（invalidate）は、送信中の登録として消しにくる。
    if (stale()) return;
    final request = ref
        .read(deviceTokenApiProvider)
        .register(
          token: token,
          platform:
              pushPlatformName(defaultTargetPlatform) ??
              DeviceTokenApi.platformAndroid,
          deviceName: deviceName,
        );
    _registering = (token: token, request: request);
    try {
      await request;
    } finally {
      if (_registering?.request == request) _registering = null;
    }
    if (stale()) return;
    await store.writeRegistration(
      PushRegistration(userId: userId, token: token, registeredAt: now),
    );
    // 捨てられずに残っていたトークンでも、登録できたならサーバーが持ち主を
    // このユーザーへ移している（前のユーザーには届かない）。予約は要らない。
    await store.writeTokenDeletionPending(false);
    if (!ref.mounted) return;
    _lastFailureAt = null;
    state = state.copyWith(registered: true, failure: null);
  }

  /// 控えが同じユーザー・同じトークンで、[reRegisterInterval] 以内か。
  /// 時計が戻った（控えが未来）ときは古いとみなして送り直す。
  static bool _isFresh(
    PushRegistration? saved,
    DateTime now, {
    required int userId,
    required String token,
  }) {
    if (saved == null || saved.userId != userId || saved.token != token) {
      return false;
    }
    final elapsed = now.difference(saved.registeredAt);
    return !elapsed.isNegative && elapsed < reRegisterInterval;
  }

  /// 直前の失敗から [retryInterval] が経っていないか。時計が戻ったら間引かない。
  bool _backingOff(DateTime now) {
    final last = _lastFailureAt;
    if (last == null) return false;
    final elapsed = now.difference(last);
    return !elapsed.isNegative && elapsed < retryInterval;
  }

  Future<bool> _permissionAlreadyRequested() async {
    try {
      return await ref.read(notificationPermissionLogProvider).wasRequested();
    } on Object catch (error) {
      // 読めなければ聞かない側に倒す（断った人に何度も出さない）。
      debugPrint('[push] read permission log failed: $error');
      return true;
    }
  }

  /// サーバーの登録を消し、端末のトークンを捨てる（OFF / ログアウト）。
  ///
  /// キューを通さない。ログアウトを登録の通信の後ろで待たせないため
  /// （進行中の登録は [PushTokenEraser.invalidate] で結果を捨てさせ、送信中の
  /// トークンはここで消す）。
  ///
  /// [awaitErase] が `true`（OFF）なら端末のトークンを捨て終わるまで待ち、
  /// サーバーの登録も端末のトークンも消せなかった（= まだ届く）ときは投げる。
  Future<void> _unregister({bool awaitErase = false}) async {
    final eraser = ref.read(pushTokenEraserProvider)..invalidate();
    final generation = eraser.generation;
    if (!await _ready || !ref.mounted) return;
    final auth = ref.read(authControllerProvider);
    final userId = auth is AuthAuthenticated ? auth.user.id : null;
    final saved = await ref.read(pushSettingsStoreProvider).readRegistration();
    if (!ref.mounted) return;
    // 送信中の登録は控えにまだ無いが、POST は Bearer 付きでサーバーへ届く。
    // Bearer があるうちに消さないと、端末のトークンを捨て損ねたときに前の
    // ユーザーの通知がログアウトした端末に届き続ける。
    final registering = _registering;
    final tokens = {?saved?.token, ?registering?.token};
    var serverCleared = userId == null || tokens.isEmpty;
    if (!serverCleared) {
      if (registering != null) {
        // DELETE が POST より先にサーバーへ着くと消えずに残るので、応答を待つ。
        // 失敗していてもサーバーには届いていることがあるので消しにいく。
        try {
          await registering.request;
        } on Object catch (_) {}
      }
      serverCleared = true;
      for (final token in tokens) {
        if (!ref.mounted || !_isSignedInAs(userId)) {
          serverCleared = false;
          break;
        }
        try {
          await ref.read(deviceTokenApiProvider).unregister(token);
        } on ApiException catch (error) {
          // 圏外など。端末のトークンを捨てれば届かなくなり、サーバーに残った行は
          // 次の送信で FCM が無効と返して消える。
          serverCleared = false;
          debugPrint('[push] unregister failed: $error');
        }
      }
    }
    // ログアウトで待つのをやめられた（時間切れの）解除が、遅れて戻ってきた。
    // 端末側の後始末はセッションの破棄（PushRegistrationPurger）が済ませており、
    // ここで捨てると次のセッションで登録したばかりのトークンと控えを消してしまう。
    if (!ref.mounted || eraser.generation != generation) return;
    await eraser.schedule();
    final erased = !awaitErase || await eraser.flush();
    if (!ref.mounted) return;
    if (!erased && !serverCleared) {
      // 予約は残っているので、次の前面復帰 / 起動で捨て直す（成功すれば表示も消える）。
      throw const PushRegistrationException(
        '通信できないため、この端末への通知をまだ止められていません。通信できるときに自動でやり直します。',
      );
    }
    state = state.copyWith(registered: false, failure: null);
  }

  bool _isSignedInAs(int? userId) {
    final current = ref.read(authControllerProvider);
    return current is AuthAuthenticated && current.user.id == userId;
  }

  void _showInForeground(PushMessage message) {
    // OFF にした直後（トークンを捨て切る前）に届いたもの / ログアウト後に届いた
    // 前のユーザー宛てのものは出さない。
    if (state.enabled == false || !message.hasNotification) return;
    if (ref.read(authControllerProvider) is! AuthAuthenticated) return;
    unawaited(
      ref
          .read(foregroundNotificationsProvider)
          .show(message)
          .catchError(
            (Object error) => debugPrint('[push] show failed: $error'),
          ),
    );
  }

  void _open(Map<String, String> data) {
    if (!ref.mounted) return;
    ref.read(pushRouteOpenerProvider)(pushRouteFor(data));
  }

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

/// 画面に出す失敗の文言。
String describePushError(Object error) => switch (error) {
  ApiException(:final message) => message,
  PushRegistrationException(:final message) => message,
  _ => '端末の通知の設定を処理できませんでした。',
};

/// 登録の前提が揃わなかった（トークンが取れないなど）。
class PushRegistrationException implements Exception {
  const PushRegistrationException(this.message);

  final String message;

  @override
  String toString() => 'PushRegistrationException: $message';
}
