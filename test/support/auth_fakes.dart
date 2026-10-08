import 'package:comic_laz/core/device/device_name_resolver.dart';
import 'package:comic_laz/core/session/session_data_purger.dart';
import 'package:comic_laz/core/session/session_purge_journal.dart';
import 'package:comic_laz/core/storage/install_marker.dart';
import 'package:comic_laz/domain/models/user.dart';
import 'package:comic_laz/features/auth/data/auth_api.dart';
import 'package:comic_laz/features/auth/data/auth_store.dart';
import 'package:comic_laz/features/downloads/data/safe_mode_revalidation_store.dart';
import 'package:mocktail/mocktail.dart';

/// テスト用ユーザー。
const testUser = User(id: 1, name: 'テスト太郎', email: 'test@example.com');

class FakeAuthStore implements AuthStore {
  FakeAuthStore({this.token, this.user, this.log});

  String? token;
  User? user;
  int clearCount = 0;

  /// 呼び出し順の記録（破棄の印との前後を確かめる）。
  final List<String>? log;

  /// [readUser] で投げる例外（セキュアストレージの障害）。
  Object? readUserError;

  /// 次の [writeUser] で 1 回だけ投げる例外（ログイン前の状態へ戻す書き込みは通す）。
  Object? writeUserError;

  @override
  Future<String?> readToken() async => token;

  /// 次の [writeToken] で 1 回だけ投げる例外。書いた後に投げる（セキュア
  /// ストレージが途中まで書いて失敗した状況。ログイン前の状態へ戻す書き込みは通す）。
  Object? writeTokenError;

  @override
  Future<void> writeToken(String token) async {
    this.token = token;
    if (writeTokenError case final error?) {
      writeTokenError = null;
      throw error;
    }
  }

  @override
  Future<User?> readUser() async {
    if (readUserError case final error?) throw error;
    return user;
  }

  @override
  Future<void> writeUser(User user) async {
    if (writeUserError case final error?) {
      writeUserError = null;
      throw error;
    }
    this.user = user;
  }

  @override
  Future<void> clear() async {
    log?.add('clear token');
    token = null;
    user = null;
    clearCount++;
  }
}

class FakeDeviceNameResolver implements DeviceNameResolver {
  FakeDeviceNameResolver([this.name = 'Test Device']);

  final String name;
  int calls = 0;

  @override
  Future<String> resolve() async {
    calls++;
    return name;
  }
}

class RecordingPurger implements SessionDataPurger {
  RecordingPurger({
    this.throwOnPurge = false,
    this.purgesRefetchableOnly = true,
    this.debugLabel = 'recording',
  });

  /// 投げるか（途中で直った状況を作れるよう書き換えられる）。
  bool throwOnPurge;
  int calls = 0;

  /// 取り直せるデータだけを消す破棄か（`safe_mode` の変更でも走る）。
  @override
  final bool purgesRefetchableOnly;

  @override
  final String debugLabel;

  @override
  Future<void> purgeSessionData() async {
    calls++;
    if (throwOnPurge) throw StateError('purge failed');
  }
}

class MockAuthApi extends Mock implements AuthApi {}

/// `fetchCurrentUser` が [testUser] を返すようにする。
extension MockAuthApiStubs on MockAuthApi {
  void stubCurrentUser([User user = testUser]) {
    when(fetchCurrentUser).thenAnswer((_) async => user);
  }
}

/// セキュアストレージが壊れている端末（Android の鍵再生成後など）を模す。
class ThrowingAuthStore implements AuthStore {
  ThrowingAuthStore({this.failOnClear = false, this.failOnRead = true});

  final bool failOnClear;
  final bool failOnRead;
  int clearCount = 0;

  @override
  Future<String?> readToken() async {
    if (failOnRead) throw const FakePlatformException('BAD_DECRYPT');
    return 'token';
  }

  @override
  Future<void> writeToken(String token) async {}

  @override
  Future<User?> readUser() async => null;

  @override
  Future<void> writeUser(User user) async {}

  @override
  Future<void> clear() async {
    clearCount++;
    if (failOnClear) throw const FakePlatformException('delete failed');
  }
}

/// プラットフォーム例外の代わり（型は問わず「ApiException ではない例外」であることが重要）。
class FakePlatformException implements Exception {
  const FakePlatformException(this.message);

  final String message;

  @override
  String toString() => 'FakePlatformException: $message';
}

/// drift を使わない [SessionPurgeJournal]（本物と同じく強い範囲を優先する）。
class FakeSessionPurgeJournal implements SessionPurgeJournal {
  FakeSessionPurgeJournal({this.pending, List<String>? log}) : log = log ?? [];

  SessionPurgeScope? pending;

  /// 呼び出し順の記録（トークンの削除との前後を確かめる）。
  final List<String> log;

  /// 印の読み書きで投げる例外（DB の障害）。
  Object? error;

  @override
  Future<SessionPurgeScope?> readPending() async {
    if (error case final error?) throw error;
    return pending;
  }

  @override
  Future<void> markPending(SessionPurgeScope scope) async {
    log.add('mark ${scope.name}');
    if (error case final error?) throw error;
    if (pending == SessionPurgeScope.session) return;
    pending = scope;
  }

  @override
  Future<void> complete(SessionPurgeScope scope) async {
    log.add('complete ${scope.name}');
    if (error case final error?) throw error;
    final current = pending;
    if (current != null && purgeScopeCovers(scope, current)) pending = null;
  }
}

/// drift を使わない [SafeModeRevalidationStore]。
class InMemorySafeModeRevalidationStore implements SafeModeRevalidationStore {
  InMemorySafeModeRevalidationStore({this.pending = false});

  bool pending;
  int scheduleCalls = 0;

  /// 予約の書き込みで投げる例外。
  Object? scheduleError;

  @override
  Future<bool> isPending() async => pending;

  @override
  Future<void> schedule() async {
    scheduleCalls++;
    if (scheduleError case final error?) throw error;
    pending = true;
  }

  @override
  Future<void> clear() async => pending = false;
}

/// drift を使わない [InstallMarker]（既定は「入れ直し直後ではない」）。
class FakeInstallMarker implements InstallMarker {
  FakeInstallMarker({this.fresh = false});

  /// 入れ直し直後の目印が残っているか。
  bool fresh;

  /// 目印の読み書きで投げる例外（DB の障害）。
  Object? error;

  int handledCount = 0;

  @override
  Future<bool> isFreshInstall() async {
    if (error case final error?) throw error;
    return fresh;
  }

  @override
  Future<void> markHandled() async {
    if (error case final error?) throw error;
    handledCount++;
    fresh = false;
  }
}
