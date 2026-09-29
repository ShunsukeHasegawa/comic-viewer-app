import 'package:comic_laz/core/device/device_name_resolver.dart';
import 'package:comic_laz/core/session/session_data_purger.dart';
import 'package:comic_laz/domain/models/user.dart';
import 'package:comic_laz/features/auth/data/auth_api.dart';
import 'package:comic_laz/features/auth/data/auth_store.dart';
import 'package:mocktail/mocktail.dart';

/// テスト用ユーザー。
const testUser = User(id: 1, name: 'テスト太郎', email: 'test@example.com');

class FakeAuthStore implements AuthStore {
  FakeAuthStore({this.token, this.user});

  String? token;
  User? user;
  int clearCount = 0;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String token) async => this.token = token;

  @override
  Future<User?> readUser() async => user;

  @override
  Future<void> writeUser(User user) async => this.user = user;

  @override
  Future<void> clear() async {
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

  final bool throwOnPurge;
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
