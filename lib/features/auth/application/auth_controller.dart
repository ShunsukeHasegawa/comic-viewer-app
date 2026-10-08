import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/device/device_name_resolver.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_data_purger.dart';
import '../../../core/session/session_purge_journal.dart';
import '../../../core/session/sign_out_hook.dart';
import '../../../core/storage/install_marker.dart';
import '../../../domain/models/user.dart';
import '../../downloads/data/safe_mode_revalidation_store.dart';
import '../data/auth_api.dart';
import '../data/auth_store.dart';
import '../domain/auth_state.dart';
import '../domain/session_cleanup_exception.dart';
import 'session_cleanup_notice.dart';

part 'auth_controller.g.dart';

/// ログイン状態の管理。
///
/// 端末内のコミックデータはログイン中のユーザーのものなので、
/// ログアウト / トークン失効では必ず [SessionDataPurger] を通して破棄する（#15）。
///
/// 前のセッションの破棄（[SessionPurgeScope.session]）の印が残っていれば、
/// 起動時とログイン時にセッションを始める**前に**やり直す。
///
/// **やり直しが失敗してもログイン / 復元は止めない**（#15 のレビュー指摘）。
/// これは個人用（利用者 1 人）のアプリとしての判断で、厳密なユーザー間の分離より
/// 使えることを優先した。止める（fail closed）と、毎回失敗する purger が 1 つ
/// あるだけ（例: 転送の記録の `reset` が投げ続ける）で二度とログインできなくなる。
/// 端末を使うのは同じ人なので、消し残るのはほぼ自分のデータで、締め出される
/// 損の方が大きい。止めない代わりに:
///   - 印は捨てる（残すと次の起動のやり直しが新しいセッションのデータまで消す）。
///   - ログイン時は [SessionCleanupNotice] で画面に知らせる（黙って通さない）。
///     起動時は同じユーザーのトークンで再開するだけなのでログに残す。
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  /// セッション終了処理（破棄）が走っている間だけ非 null。
  ///
  /// 複数リクエストが同時に 401 を受けても破棄を 1 回に抑える。
  Future<void>? _endSessionTask;

  /// 破棄の印のやり直しが走っている間だけ非 null（起動とログインで重ねない）。
  Future<bool>? _replayTask;

  /// 入れ直し直後の片付けが走っている間だけ非 null（起動とログインで重ねない）。
  Future<bool>? _installTask;

  /// 入れ直し直後の片付けを済ませた（または不要だった）か。
  bool _installChecked = false;

  /// 保存先に書いたまま確定していないログイン（その世代と、書く前の認証情報）。
  ///
  /// 失敗 / dispose で確定しなかったログインは、これが自分のものなら書く前に
  /// 戻す。後続のログインは引き継いで戻してから始め、ログアウトは戻さずに
  /// 手放す（全部消すので）。引き継がれた後の古いログインは保存先を触らない
  /// （後続の操作が書いたものを古い認証情報で上書きしない）。
  _UncommittedLogin? _uncommittedLogin;

  /// 確定しなかったログインを戻している処理（[_settleUncommittedLogin]）。
  /// 保存先を書き換える前に待つ（戻す書き込みと混ざらないため）。
  Future<void> _rollback = Future.value();

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
    } on Object catch (error) {
      if (_isStale(generation)) return;
      debugPrint('[session] restore failed: $error');
      // 復元できない = ログインし直してもらう（トークンは触らない）。
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> _restoreSession(int generation) async {
    // 入れ直し直後なら、Keychain に残った前のインストールのトークンを消す（#15）。
    // 片付けられないまま読むと、前の持ち主のセッションで自動ログインしてしまう。
    if (!await _forgetPreviousInstall()) {
      if (_isStale(generation)) return;
      state = const AuthState.unauthenticated();
      return;
    }
    if (_isStale(generation)) return;
    // 前回の破棄が途中で終わっていたら、トークンを読む前にやり直す（#15）。
    // ログアウト後はトークンも前のユーザーも無いので、ここでしか気づけない。
    final purged = await _replayPendingPurge();
    if (_isStale(generation)) return;
    final store = ref.read(authStoreProvider);
    final token = await store.readToken();
    if (_isStale(generation)) return;

    if (token == null || token.isEmpty) {
      // 端末内に何も残っていないので、以降の 401 で破棄を走らせる必要はない。
      _sessionCleared = true;
      state = const AuthState.unauthenticated();
      return;
    }

    if (!purged) {
      // 消し残しがあっても、保存済みトークン（= 同じユーザー）で再開する。
      // 個人用アプリなので、消えない purger 1 つで締め出されるより使える方を
      // 取る（クラスの説明）。印は捨てる。残すと起動のたびにログイン中の
      // ユーザーの進捗やダウンロードを消しにいく。
      debugPrint('[session] purge replay failed; resuming session anyway');
      await _abandonPendingPurge();
      if (_isStale(generation)) return;
    }

    try {
      final user = await ref.read(authApiProvider).fetchCurrentUser();
      if (_isStale(generation)) return;
      // 起動時は前のユーザーを読めなくても破棄しない（atLogin: false）。
      // ロック解除前のバックグラウンド起動では Keychain が読めず、同じユーザーの
      // データを消してしまうため（例外は restoreSession が未ログインにする）。
      // 破棄の失敗（cleaned: false）はログだけ（起動時は画面に知らせない）。
      final (:saveUser, cleaned: _) = await _purgeIfUserChanged(
        user,
        atLogin: false,
      );
      if (_isStale(generation)) return;
      if (saveUser) await store.writeUser(user);
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
      User? cached;
      try {
        cached = await store.readUser();
      } on StoredUserUnreadableException catch (error) {
        // 形式が変わった保存値ではオフライン続行できない（未ログインにする）。
        // 次のログインでは「持ち主不明」として全部片付ける。
        debugPrint('[session] cached user unreadable: $error');
      }
      if (_isStale(generation)) return;
      // トークンは残っているので `_sessionCleared` は立てない。
      state = cached == null
          ? const AuthState.unauthenticated()
          : AuthState.authenticated(cached);
    }
  }

  /// メール / パスワードでログインする。
  ///
  /// 通信の失敗は [ApiException]、入れ直し直後の認証情報を片付けられなかった
  /// ときは [SessionCleanupException] を投げる（どちらもトークンは保存しない）。
  ///
  /// 前のセッションのデータを消し切れなかったときはログインを止めず、印を
  /// 捨てて [SessionCleanupNotice] で知らせる（クラスの説明）。
  Future<void> login({required String email, required String password}) async {
    // 起動時の検証が走っていても、こちらの結果を優先させる。
    final generation = ++_generation;
    final store = ref.read(authStoreProvider);
    final deviceName = await ref.read(deviceNameResolverProvider).resolve();
    final result = await ref
        .read(authApiProvider)
        .createToken(email: email, password: password, deviceName: deviceName);
    if (_isStale(generation)) return;
    // 入れ直し直後の目印を片付けられなければ止める。片付けないまま通すと、
    // 次の起動が目印を見て新しいトークンを消す（ログインが保たれない）。発行
    // されたトークンはメモリ上で捨てるだけにする（サーバー側は期限で失効する）。
    final installChecked = await _forgetPreviousInstall();
    if (_isStale(generation)) return;
    if (!installChecked) throw const SessionCleanupException();
    // 新しいセッションを始める前に、端末に残った前のセッションを片付ける。
    final purged = await _replayPendingPurge();
    if (_isStale(generation)) return;
    if (!purged) {
      // 消し切れなくてもログインは止めない（個人用アプリの判断。クラスの説明）。
      // 印は捨てる。残すと次の起動のやり直しが新しいセッションのデータまで消す。
      await _abandonPendingPurge();
      if (_isStale(generation)) return;
    }
    // 前のログインが書いたまま確定していなければ、先に戻す（下で控える
    // 「前の認証情報」をそのログインの途中の書き込みにしない）。
    await _settleUncommittedLogin();
    if (_isStale(generation)) return;
    // 上書きする前に、前の認証情報を控えておく。確定しなかったら戻すためと、
    // 前のトークンが残っていたか（下の `_purgeIfUserChanged` で「持ち主の
    // 分からないセッション」を見分ける）を知るため。
    final previous = await _readStoredCredentials();
    if (_isStale(generation)) return;

    _uncommittedLogin = (
      generation: generation,
      store: store,
      previous: previous,
    );
    final User user;
    final bool cleaned;
    try {
      // 書き込みの失敗も戻す（途中まで書かれているかもしれない）。
      await store.writeToken(result.token);
      // トークンと一緒にユーザーが返らないサーバー実装でも動くようにする。
      user = result.user ?? await ref.read(authApiProvider).fetchCurrentUser();
      if (_isStale(generation)) return;
      final purge = await _purgeIfUserChanged(
        user,
        atLogin: true,
        hadPreviousToken: previous.hadToken,
      );
      cleaned = purge.cleaned;
      if (_isStale(generation)) return;
      if (purge.saveUser) await store.writeUser(user);
      if (_isStale(generation)) return;
      // ここで確定する（以降は戻さない）。
      _uncommittedLogin = null;
    } finally {
      // 失敗 / dispose / 後続の操作で確定しなかった。新しいトークンだけ /
      // 前のユーザーと新しいトークンの組を残すと、次の起動で前のユーザーのまま
      // （またはユーザーの分からないまま）新しいトークンで再開してしまう。
      // 後続の操作が引き継いでいれば、そちらに任せて触らない。
      if (_uncommittedLogin?.generation == generation) {
        await _settleUncommittedLogin();
      }
    }
    _sessionCleared = false;
    state = AuthState.authenticated(user);
    // 消し残しがあっても黙って通さない（`ComicLazApp` が SnackBar で 1 回知らせる）。
    if (!purged || !cleaned) {
      ref.read(sessionCleanupNoticeProvider.notifier).report();
    }
  }

  /// [SignOutHook] 1 つを待つ上限。圏外でもログアウトを待たせすぎない。
  static const signOutHookTimeout = Duration(seconds: 6);

  /// 明示的なログアウト。サーバーへの通知が失敗しても端末内は必ず片付ける。
  ///
  /// Bearer が要る後始末（プッシュ通知の登録の解除 #14）は、トークンを
  /// 失効させる**前に**済ませる（[SignOutHook]）。失敗 / 時間切れでも進める。
  Future<void> logout() async {
    for (final hook in ref.read(signOutHooksProvider)) {
      try {
        await hook.beforeSignOut().timeout(signOutHookTimeout);
      } on Object catch (error) {
        debugPrint('[session] sign-out hook ${hook.debugLabel} failed: $error');
      }
      if (!ref.mounted) return;
    }
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
    // 進行中の復元 / ログインの結果を無効にする。確定していないログインは
    // 戻さずに手放す（下で全部消す）。戻している最中なら、その書き込みが
    // 消した後に入らないよう待つ。
    _generation++;
    _uncommittedLogin = null;
    final rollback = _rollback;
    // 印はトークンより先に書く（#15）。トークンを消した直後に落ちると、次の
    // 起動ではトークンも前のユーザーも無く、データだけが残ってしまう。
    await _markPurgePending(SessionPurgeScope.session);
    if (!ref.mounted) return;
    await rollback;
    if (!ref.mounted) return;
    try {
      await ref.read(authStoreProvider).clear();
    } on Object {
      // ストレージが壊れていても、メモリ上のトークンは破棄済みなので続行する。
    }
    if (!ref.mounted) return;
    // 失敗しても印が残り、次の起動 / ログインでもう一度やり直す。
    await _purgeAndComplete(SessionPurgeScope.session);
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
  /// 前のユーザーが居ない（初回ログイン / ログアウト済み）ときは何もしない。
  /// ログアウトの消し残しは破棄の印（[SessionPurgeJournal]）が面倒を見る。
  /// ただしログイン時に前のトークンだけが残っていた（[hadPreviousToken]）なら、
  /// 誰かのセッションが片付かずに残っているので、持ち主不明として全部捨てる。
  ///
  /// `safe_mode` だけが変わったときは**取り直せるものだけ**捨てる（#11 の
  /// レビュー指摘）。同じユーザーなのにダウンロード済みの巻（数 GB）と未送信の
  /// 読書進捗まで消すのは行き過ぎで、未送信の進捗はサーバーにも無いので
  /// 永久に失われる。隠したいのは「前の設定で取った一覧・詳細・画像」だけ。
  /// OFF → ON のときは、ダウンロード済みの巻の再検証を予約する
  /// （`SafeModeRevalidator` がサーバーに 404 と言われたタイトルだけ消す。#15）。
  ///
  /// [atLogin] のときに前のユーザーを読めなければ（セキュアストレージの障害 /
  /// 保存値の形式が変わった）、別のユーザーとみなして全部捨てる。持ち主を
  /// 確かめられないデータを次のユーザーに見せないため。ログイン操作中は端末の
  /// ロックが解除されているので、ロック解除前の一時的な読めなさとは取り違えない。
  /// 起動時（トークンは置き換わっていない）に形式だけが読めないときは、
  /// トークンの持ち主 = 端末のデータの持ち主なので捨てずに上書きする。
  ///
  /// `saveUser` は新しいユーザーを保存してよいか。再検証の予約を書けなかった
  /// ときは保存しない（次の起動で同じ差分を見つけて予約し直すため）。
  /// `cleaned` は、セッション全体の破棄が要ったならそれが済んだか。失敗しても
  /// セッションは止めず印を捨てる（クラスの説明。知らせるのは呼び出し側）。
  Future<({bool saveUser, bool cleaned})> _purgeIfUserChanged(
    User next, {
    required bool atLogin,
    bool hadPreviousToken = false,
  }) async {
    const aborted = (saveUser: false, cleaned: true);
    final User? previous;
    try {
      previous = await ref.read(authStoreProvider).readUser();
    } on StoredUserUnreadableException catch (error) {
      debugPrint('[session] previous user undecodable: $error');
      if (!ref.mounted) return aborted;
      if (atLogin) return (saveUser: true, cleaned: await _purgeSession());
      // 前の設定が分からないので、セーフモードなら OFF → ON とみなす
      // （再検証の予約を取りこぼさない。取り直せるものを 1 回捨てるだけ）。
      final saveUser = await _applySafeModeChange(
        previousSafeMode: false,
        next: next,
      );
      return (saveUser: saveUser, cleaned: true);
    } on Object catch (error) {
      if (!atLogin) rethrow;
      debugPrint('[session] previous user unreadable: $error');
      if (!ref.mounted) return aborted;
      return (saveUser: true, cleaned: await _purgeSession());
    }
    if (!ref.mounted) return aborted;
    if (previous == null) {
      if (atLogin && hadPreviousToken) {
        debugPrint('[session] token without user; purging as unknown owner');
        return (saveUser: true, cleaned: await _purgeSession());
      }
      return (saveUser: true, cleaned: true);
    }
    if (previous.id != next.id) {
      return (saveUser: true, cleaned: await _purgeSession());
    }
    final saveUser = await _applySafeModeChange(
      previousSafeMode: previous.safeMode,
      next: next,
    );
    return (saveUser: saveUser, cleaned: true);
  }

  /// 同じユーザーのまま `safe_mode` が変わったときの片付け。
  /// 新しいユーザーを保存してよいかを返す。
  Future<bool> _applySafeModeChange({
    required bool previousSafeMode,
    required User next,
  }) async {
    if (previousSafeMode == next.safeMode) return true;
    var saveUser = true;
    if (!previousSafeMode && next.safeMode) {
      try {
        await ref.read(safeModeRevalidationStoreProvider).schedule();
      } on Object catch (error) {
        debugPrint('[session] schedule safe mode revalidation failed: $error');
        saveUser = false;
      }
      if (!ref.mounted) return false;
    }
    // 取り直せるものだけなので、失敗しても印が残って次の機会にやり直すだけ
    // （同じユーザーのキャッシュなので、セッションは止めない）。
    await _purgeWithJournal(SessionPurgeScope.refetchable);
    return saveUser;
  }

  /// ユーザーが替わった / 持ち主不明のときのセッション全体の破棄。
  ///
  /// 済んだら `true`。失敗してもセッションは止めないので印は捨てる（残すと
  /// 次の起動のやり直しが新しいセッションのデータまで消す。クラスの説明）。
  Future<bool> _purgeSession() async {
    if (await _purgeWithJournal(SessionPurgeScope.session)) return true;
    debugPrint('[session] purge on user change failed; continuing anyway');
    if (ref.mounted) await _abandonPendingPurge();
    return false;
  }

  /// 消し切れなかった破棄の印を捨てる（セッションを止めない代わり。#15）。
  ///
  /// 個人用アプリなので、消し残しより「始めたセッションのデータを後の起動で
  /// 消してしまう」方を避ける（クラスの説明）。捨てられなくても続行する
  /// （次の機会にもう一度やり直し、失敗すればまた捨てにいくだけ）。
  Future<void> _abandonPendingPurge() async {
    try {
      // セッション全体の完了はどの範囲の印も覆う（`purgeScopeCovers`）。
      await ref
          .read(sessionPurgeJournalProvider)
          .complete(SessionPurgeScope.session);
      debugPrint('[session] abandoned pending purge after failure');
    } on Object catch (error) {
      debugPrint('[session] abandon purge journal failed: $error');
    }
  }

  /// ログイン前に保存されていた認証情報（読めないものは `null`）。
  ///
  /// `hadToken` はトークンがあったか（読めなければ「あった」とみなす）。
  Future<_StoredCredentials> _readStoredCredentials() async {
    final store = ref.read(authStoreProvider);
    String? token;
    var hadToken = true;
    try {
      token = await store.readToken();
      hadToken = token != null && token.isNotEmpty;
    } on Object catch (error) {
      debugPrint('[session] read previous token failed: $error');
    }
    User? user;
    try {
      user = await store.readUser();
    } on Object catch (error) {
      // 読めないユーザーは戻せない。戻したトークンで起動すれば
      // 検証のときに保存し直される。
      debugPrint('[session] read previous user failed: $error');
    }
    return (token: hadToken ? token : null, hadToken: hadToken, user: user);
  }

  /// 確定していないログインがあれば保存先を書く前の認証情報に戻し、戻し
  /// 終わるまで待つ。
  ///
  /// dispose の後にも呼ばれるので `ref` を使わない（保存先はログインが控えた
  /// ものを使う）。
  Future<void> _settleUncommittedLogin() {
    if (_uncommittedLogin case final pending?) {
      _uncommittedLogin = null;
      _rollback = _rollback.then(
        (_) => _restoreCredentials(pending.store, pending.previous),
      );
    }
    return _rollback;
  }

  /// 保存先をログイン前の認証情報に戻す。
  ///
  /// 先に全部消してから書き直す。戻す途中で失敗しても、新しいトークンが
  /// 残る（前のユーザーと組になる）より、ログインし直してもらう方に倒す。
  /// 失敗は握る（呼び出し側はログインの失敗そのものを投げる）。
  static Future<void> _restoreCredentials(
    AuthStore store,
    _StoredCredentials previous,
  ) async {
    try {
      await store.clear();
      if (previous.token case final token?) await store.writeToken(token);
      if (previous.user case final user?) await store.writeUser(user);
    } on Object catch (error) {
      debugPrint('[session] restore previous credentials failed: $error');
    }
  }

  /// 入れ直し直後なら、前のインストールの認証情報を消す（#15）。
  ///
  /// iOS の Keychain はアプリを削除しても残るので、消さないと入れ直した端末が
  /// 前の持ち主のトークンで自動ログインする（[InstallMarker]）。消せたか、
  /// 消す必要が無ければ `true`。失敗したら目印を残し、次の機会にやり直す。
  Future<bool> _forgetPreviousInstall() {
    if (_installChecked) return Future.value(true);
    return _installTask ??= _checkInstall().whenComplete(
      () => _installTask = null,
    );
  }

  Future<bool> _checkInstall() async {
    final marker = ref.read(installMarkerProvider);
    try {
      if (await marker.isFreshInstall()) {
        if (!ref.mounted) return false;
        debugPrint('[session] fresh install; clearing leftover credentials');
        await ref.read(authStoreProvider).clear();
        if (!ref.mounted) return false;
        await marker.markHandled();
      }
      _installChecked = true;
      return true;
    } on Object catch (error) {
      debugPrint('[session] fresh install check failed: $error');
      return false;
    }
  }

  /// 前回の破棄の印が残っていれば、その範囲の破棄をやり直す（#15）。
  ///
  /// セッション全体の印が片付いた（または無かった）ら `true`。印を読めない /
  /// やり直しが失敗したら `false` で、呼び出し側は印を捨ててから続行する。
  /// 取り直せるものだけの印（同じユーザーの `safe_mode` の変更）は、消し残っても
  /// 前のユーザーのデータを見せることにはならないので `true` とする。
  /// 印はデータを消す意味しか持たないので、トークンには触らない。
  Future<bool> _replayPendingPurge() =>
      _replayTask ??= _replay().whenComplete(() => _replayTask = null);

  Future<bool> _replay() async {
    final SessionPurgeScope? pending;
    try {
      pending = await ref.read(sessionPurgeJournalProvider).readPending();
    } on Object catch (error) {
      debugPrint('[session] read purge journal failed: $error');
      return false;
    }
    if (pending == null) return true;
    if (!ref.mounted) return false;
    debugPrint('[session] replaying ${pending.name} purge');
    final completed = await _purgeAndComplete(pending);
    return completed || pending == SessionPurgeScope.refetchable;
  }

  /// 破棄の印を書く。書けなくても破棄は続ける（ログアウトを止めない）。
  Future<void> _markPurgePending(SessionPurgeScope scope) async {
    try {
      await ref.read(sessionPurgeJournalProvider).markPending(scope);
    } on Object catch (error) {
      debugPrint('[session] mark purge pending failed: $error');
    }
  }

  /// 印を書いてから破棄し、すべて成功したときだけ印を消す。
  /// 破棄と印の片付けがすべて済んだら `true`。
  Future<bool> _purgeWithJournal(SessionPurgeScope scope) async {
    await _markPurgePending(scope);
    if (!ref.mounted) return false;
    return _purgeAndComplete(scope);
  }

  /// 破棄し、すべて成功したときだけ印を消す（印は呼び出し側が書いておく）。
  /// 破棄と印の片付けがすべて済んだら `true`。
  Future<bool> _purgeAndComplete(SessionPurgeScope scope) async {
    final succeeded = await _purgeLocalData(scope: scope);
    if (!succeeded || !ref.mounted) return false;
    try {
      await ref.read(sessionPurgeJournalProvider).complete(scope);
      return true;
    } on Object catch (error) {
      // 消せなければ次の機会にもう一度破棄する（消し過ぎる方に倒れるだけ）。
      debugPrint('[session] complete purge journal failed: $error');
      return false;
    }
  }

  /// 破棄を走らせる。1 つでも失敗したら `false`（印を残して次の機会にやり直す）。
  Future<bool> _purgeLocalData({required SessionPurgeScope scope}) async {
    var succeeded = true;
    for (final purger in purgersInScope(
      ref.read(sessionDataPurgersProvider),
      scope,
    )) {
      try {
        await purger.purgeSessionData();
      } on Object catch (error) {
        // 1 つ失敗しても残りは消す（消せないデータがあってもログアウト自体は完了させる）。
        debugPrint('[session] purge ${purger.debugLabel} failed: $error');
        succeeded = false;
      }
      if (!ref.mounted) return false;
    }
    return succeeded;
  }

  /// この処理の結果を捨てるべきか（dispose 済み / 後続のログイン・ログアウトが発生）。
  bool _isStale(int generation) => !ref.mounted || generation != _generation;
}

/// ログイン前に保存されていた認証情報の控え（[AuthController.login] で戻す）。
typedef _StoredCredentials = ({String? token, bool hadToken, User? user});

/// 保存先に書いたまま確定していないログイン（[AuthController.login]）。
typedef _UncommittedLogin = ({
  int generation,
  AuthStore store,
  _StoredCredentials previous,
});
