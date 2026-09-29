import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/device/device_name_resolver.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_data_purger.dart';
import '../../../domain/models/user.dart';
import '../data/auth_api.dart';
import '../data/auth_store.dart';
import '../domain/auth_state.dart';

part 'auth_controller.g.dart';

/// ログイン状態の管理。
///
/// 端末内のコミックデータはログイン中のユーザーのものなので、
/// ログアウト / トークン失効では必ず [SessionDataPurger] を通して破棄する（#15）。
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  /// セッション終了処理（破棄）が走っている間だけ非 null。
  ///
  /// 複数リクエストが同時に 401 を受けても破棄を 1 回に抑える。
  Future<void>? _endSessionTask;

  /// 進行中 / 直近の破棄の理由。明示ログアウトが失効より優先される。
  SessionEndReason _endReason = SessionEndReason.signedOut;

  /// 端末内のセッションデータを片付け済みか（トークンが無いと分かっているか）。
  ///
  /// これが `false` の間は 401 を受けたら必ず破棄を走らせる。
  /// 「未ログインだがトークンは残っている」状態（圏外起動）を取りこぼさないため、
  /// 状態ではなくこのフラグで判定する。
  bool _sessionCleared = false;

  /// ログイン / ログアウトのたびに増える世代番号。
  ///
  /// 起動時のトークン検証中にログアウトされた場合などに、
  /// 古い処理が新しい状態を上書きしないようにする。
  int _generation = 0;

  @override
  AuthState build() {
    // 保存済みトークンの検証は非同期で進める。
    unawaited(restoreSession());
    return const AuthState.restoring();
  }

  /// 起動時の自動ログイン。
  ///
  /// セキュアストレージは端末の鍵が作り直された場合などに
  /// `PlatformException` を投げる。ここで握らないと状態が
  /// [AuthRestoring] のまま固まり、スプラッシュから抜けられなくなる。
  Future<void> restoreSession() async {
    final generation = _generation;
    try {
      await _restoreSession(generation);
    } on Object {
      if (_isStale(generation)) return;
      // 復元できない = ログインし直してもらう（トークンは触らない）。
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> _restoreSession(int generation) async {
    final store = ref.read(authStoreProvider);
    final token = await store.readToken();
    if (_isStale(generation)) return;

    if (token == null || token.isEmpty) {
      // 端末内に何も残っていないので、以降の 401 で破棄を走らせる必要はない。
      _sessionCleared = true;
      state = const AuthState.unauthenticated();
      return;
    }

    try {
      final user = await ref.read(authApiProvider).fetchCurrentUser();
      if (_isStale(generation)) return;
      await _purgeIfUserChanged(user);
      if (_isStale(generation)) return;
      await store.writeUser(user);
      if (_isStale(generation)) return;
      _sessionCleared = false;
      state = AuthState.authenticated(user);
    } on UnauthorizedException {
      if (_isStale(generation)) return;
      // トークンが失効している。端末内のデータも破棄する。
      await _endSessionOnce(SessionEndReason.expired);
    } on ApiException {
      // 圏外・サーバー障害ではログアウトしない（トークンは残す）。
      // 直前のユーザーが分かればオフラインのまま続行する（#11）。
      if (_isStale(generation)) return;
      final cached = await store.readUser();
      if (_isStale(generation)) return;
      // トークンは残っているので `_sessionCleared` は立てない。
      state = cached == null
          ? const AuthState.unauthenticated()
          : AuthState.authenticated(cached);
    }
  }

  /// メール / パスワードでログインする。失敗時は [ApiException] を投げる。
  Future<void> login({required String email, required String password}) async {
    // 起動時の検証が走っていても、こちらの結果を優先させる。
    final generation = ++_generation;
    final store = ref.read(authStoreProvider);
    final deviceName = await ref.read(deviceNameResolverProvider).resolve();
    final result = await ref
        .read(authApiProvider)
        .createToken(email: email, password: password, deviceName: deviceName);
    if (_isStale(generation)) return;

    await store.writeToken(result.token);
    // トークンと一緒にユーザーが返らないサーバー実装でも動くようにする。
    final user =
        result.user ?? await ref.read(authApiProvider).fetchCurrentUser();
    if (_isStale(generation)) return;
    await _purgeIfUserChanged(user);
    if (_isStale(generation)) return;
    await store.writeUser(user);
    if (_isStale(generation)) return;
    _sessionCleared = false;
    state = AuthState.authenticated(user);
  }

  /// 明示的なログアウト。サーバーへの通知が失敗しても端末内は必ず片付ける。
  Future<void> logout() async {
    try {
      await ref.read(authApiProvider).deleteToken();
    } on ApiException {
      // 圏外でもログアウトはできるようにする（トークンはサーバー側に残る）。
      // 401（サーバー側で既に失効）でもインターセプタ経由の破棄に合流するだけ。
    }
    if (!ref.mounted) return;
    await _endSessionOnce(SessionEndReason.signedOut);
  }

  /// インターセプタが 401 を検出したときに呼ばれる。
  Future<void> handleSessionExpired() =>
      _endSessionOnce(SessionEndReason.expired);

  /// 破棄処理を 1 回だけ走らせる。
  Future<void> _endSessionOnce(SessionEndReason reason) {
    if (!ref.mounted) return Future.value();

    if (_endSessionTask case final pending?) {
      // 進行中の破棄に相乗りする。明示ログアウトなら理由を上書きする。
      if (reason == SessionEndReason.signedOut) _endReason = reason;
      return pending;
    }

    if (_sessionCleared) {
      // 既に片付け済み。理由だけ整える（ログアウト直後の 401 連発など）。
      final current = state;
      if (reason == SessionEndReason.signedOut ||
          current is! AuthUnauthenticated ||
          current.reason == null) {
        state = AuthState.unauthenticated(reason: reason);
      }
      return Future.value();
    }

    _endReason = reason;
    // `??=` は await を挟まずに代入されるので、同時に呼ばれても 1 つに集約される。
    return _endSessionTask ??= _endSession().whenComplete(
      () => _endSessionTask = null,
    );
  }

  Future<void> _endSession() async {
    // 進行中の復元 / ログインの結果を無効にする。
    _generation++;
    try {
      await ref.read(authStoreProvider).clear();
    } on Object {
      // ストレージが壊れていても、メモリ上のトークンは破棄済みなので続行する。
    }
    if (!ref.mounted) return;
    await _purgeLocalData();
    if (!ref.mounted) return;
    _sessionCleared = true;
    state = AuthState.unauthenticated(reason: _endReason);
  }

  /// 別のユーザー / 別のセーフモード設定になったら端末内のデータを捨てる（#11）。
  ///
  /// セーフモードの制御はサーバー側が正なので、`is_unsafe` の巻はそもそも
  /// 端末に落ちていない。それでも破棄するのは、**前のユーザー / 前の設定で
  /// 取得した一覧・詳細・サムネイルが端末に残っている**ためで、オフラインでは
  /// それがそのまま表示されてしまう（キャッシュ経由で見えてしまわないこと）。
  ///
  /// 前のユーザーが分からない（初回ログイン / ログアウト済み）ときは何もしない。
  ///
  /// `safe_mode` だけが変わったときは**取り直せるものだけ**捨てる（#11 の
  /// レビュー指摘）。同じユーザーなのにダウンロード済みの巻（数 GB）と未送信の
  /// 読書進捗まで消すのは行き過ぎで、未送信の進捗はサーバーにも無いので
  /// 永久に失われる。隠したいのは「前の設定で取った一覧・詳細・画像」だけ。
  Future<void> _purgeIfUserChanged(User next) async {
    final previous = await ref.read(authStoreProvider).readUser();
    if (previous == null) return;
    if (previous.id != next.id) {
      if (!ref.mounted) return;
      await _purgeLocalData();
      return;
    }
    if (previous.safeMode == next.safeMode) return;
    if (!ref.mounted) return;
    await _purgeLocalData(scope: SessionPurgeScope.refetchable);
  }

  Future<void> _purgeLocalData({
    SessionPurgeScope scope = SessionPurgeScope.session,
  }) async {
    for (final purger in purgersInScope(
      ref.read(sessionDataPurgersProvider),
      scope,
    )) {
      try {
        await purger.purgeSessionData();
      } on Object {
        // 1 つ失敗しても残りは消す（消せないデータがあってもログアウト自体は完了させる）。
      }
      if (!ref.mounted) return;
    }
  }

  /// この処理の結果を捨てるべきか（dispose 済み / 後続のログイン・ログアウトが発生）。
  bool _isStale(int generation) => !ref.mounted || generation != _generation;
}
