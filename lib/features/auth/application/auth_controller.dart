import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/device/device_name_resolver.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_data_purger.dart';
import '../../../core/session/session_purge_journal.dart';
import '../../../core/storage/install_marker.dart';
import '../../../domain/models/user.dart';
import '../../downloads/data/safe_mode_revalidation_store.dart';
import '../data/auth_api.dart';
import '../data/auth_store.dart';
import '../domain/auth_state.dart';
import '../domain/session_cleanup_exception.dart';

part 'auth_controller.g.dart';

/// ログイン状態の管理。
///
/// 端末内のコミックデータはログイン中のユーザーのものなので、
/// ログアウト / トークン失効では必ず [SessionDataPurger] を通して破棄する（#15）。
///
/// **セッション全体の破棄（[SessionPurgeScope.session]）が済んでいない間は
/// ログイン済みにしない**（#15 のレビュー指摘）。進捗の行には持ち主が無いので、
/// 前のユーザーの未送信の進捗が新しいユーザーのトークンでサーバーへ送られ
/// （取り消せない）、前のユーザーの巻も新しいユーザーに見えてしまうため。
/// これにより「ログイン中なのに破棄の印が残っている」状態も生まれず、起動の
/// たびのやり直しがログイン中のユーザーの進捗やダウンロードを消すこともない。
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
      // 持ち主を確かめられないデータが残っている。その上でセッションを
      // 再開しない（ログインし直すときに、もう一度片付けてから始める）。
      debugPrint('[session] purge still pending; not restoring session');
      state = const AuthState.unauthenticated();
      return;
    }

    try {
      final user = await ref.read(authApiProvider).fetchCurrentUser();
      if (_isStale(generation)) return;
      // 起動時は前のユーザーを読めなくても破棄しない（atLogin: false）。
      // ロック解除前のバックグラウンド起動では Keychain が読めず、同じユーザーの
      // データを消してしまうため（例外は restoreSession が未ログインにする）。
      final saveUser = await _purgeIfUserChanged(user, atLogin: false);
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
  /// 通信の失敗は [ApiException]、前のセッションを片付けられなかったときは
  /// [SessionCleanupException] を投げる（どちらもトークンは保存しない）。
  Future<void> login({required String email, required String password}) async {
    // 起動時の検証が走っていても、こちらの結果を優先させる。
    final generation = ++_generation;
    final store = ref.read(authStoreProvider);
    final deviceName = await ref.read(deviceNameResolverProvider).resolve();
    final result = await ref
        .read(authApiProvider)
        .createToken(email: email, password: password, deviceName: deviceName);
    if (_isStale(generation)) return;
    // 新しいセッションを始める前に、端末に残った前のセッションを片付ける。
    // 片付けられなければトークンを保存せずに止める（fail closed）。発行された
    // トークンはメモリ上で捨てるだけにする（サーバー側は期限で失効する）。
    final installChecked = await _forgetPreviousInstall();
    if (_isStale(generation)) return;
    if (!installChecked) throw const SessionCleanupException();
    // ここで片付けないと、次の起動のやり直しが新しいセッションのデータまで消す。
    final purged = await _replayPendingPurge();
    if (_isStale(generation)) return;
    if (!purged) throw const SessionCleanupException();
    // 上書きする前に、前のトークンが残っていたかを見ておく（下の
    // `_purgeIfUserChanged` で「持ち主の分からないセッション」を見分ける）。
    final hadPreviousToken = await _hasStoredToken();
    if (_isStale(generation)) return;

    await store.writeToken(result.token);
    // トークンと一緒にユーザーが返らないサーバー実装でも動くようにする。
    final user =
        result.user ?? await ref.read(authApiProvider).fetchCurrentUser();
    if (_isStale(generation)) return;
    final bool saveUser;
    try {
      saveUser = await _purgeIfUserChanged(
        user,
        atLogin: true,
        hadPreviousToken: hadPreviousToken,
      );
    } on SessionCleanupException {
      // 前のユーザーのデータを消せなかった。新しいトークンを残すと、次の起動で
      // 前のユーザーのデータの上にセッションを復元してしまう。前のユーザーの
      // 記録も一緒に消えるが、破棄の印が残っているので次のログインで片付く。
      if (!_isStale(generation)) {
        try {
          await store.clear();
        } on Object catch (error) {
          debugPrint('[session] clear token after failed purge: $error');
        }
      }
      rethrow;
    }
    if (_isStale(generation)) return;
    if (saveUser) await store.writeUser(user);
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
    // 印はトークンより先に書く（#15）。トークンを消した直後に落ちると、次の
    // 起動ではトークンも前のユーザーも無く、データだけが残ってしまう。
    await _markPurgePending(SessionPurgeScope.session);
    if (!ref.mounted) return;
    try {
      await ref.read(authStoreProvider).clear();
    } on Object {
      // ストレージが壊れていても、メモリ上のトークンは破棄済みなので続行する。
    }
    if (!ref.mounted) return;
    // 失敗しても印が残り、次のログインは片付くまで始まらない（上のクラスの説明）。
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
  /// 新しいユーザーを保存してよいかを返す。再検証の予約を書けなかったときは
  /// 保存しない（次の起動で同じ差分を見つけて予約し直すため）。
  /// セッション全体の破棄に失敗したら [SessionCleanupException] を投げる
  /// （呼び出し側はログイン済みにしない）。
  Future<bool> _purgeIfUserChanged(
    User next, {
    required bool atLogin,
    bool hadPreviousToken = false,
  }) async {
    final User? previous;
    try {
      previous = await ref.read(authStoreProvider).readUser();
    } on StoredUserUnreadableException catch (error) {
      debugPrint('[session] previous user undecodable: $error');
      if (!ref.mounted) return false;
      if (atLogin) {
        await _purgeSession();
        return true;
      }
      // 前の設定が分からないので、セーフモードなら OFF → ON とみなす
      // （再検証の予約を取りこぼさない。取り直せるものを 1 回捨てるだけ）。
      return _applySafeModeChange(previousSafeMode: false, next: next);
    } on Object catch (error) {
      if (!atLogin) rethrow;
      debugPrint('[session] previous user unreadable: $error');
      if (!ref.mounted) return false;
      await _purgeSession();
      return true;
    }
    if (!ref.mounted) return false;
    if (previous == null) {
      if (atLogin && hadPreviousToken) {
        debugPrint('[session] token without user; purging as unknown owner');
        await _purgeSession();
      }
      return true;
    }
    if (previous.id != next.id) {
      await _purgeSession();
      return true;
    }
    return _applySafeModeChange(
      previousSafeMode: previous.safeMode,
      next: next,
    );
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
  /// 失敗したら [SessionCleanupException] を投げる（印は残る）。
  Future<void> _purgeSession() async {
    if (!await _purgeWithJournal(SessionPurgeScope.session)) {
      throw const SessionCleanupException();
    }
  }

  /// ログインの前に保存済みのトークンがあったか（読めなければ「あった」とみなす）。
  Future<bool> _hasStoredToken() async {
    try {
      final token = await ref.read(authStoreProvider).readToken();
      return token != null && token.isNotEmpty;
    } on Object catch (error) {
      debugPrint('[session] read previous token failed: $error');
      return true;
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
  /// やり直しが失敗したら `false` で、呼び出し側はログイン済みにしない。
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
