import 'dart:convert';

import 'package:comic_laz/features/auth/data/auth_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';

void main() {
  // プラットフォームチャネルを触らないメモリ上の実装に差し替える。
  SecureAuthStore storeWith(Map<String, String> values) {
    FlutterSecureStorage.setMockInitialValues(values);
    return SecureAuthStore();
  }

  test('ユーザーが保存されていなければ null（初回ログイン / ログアウト済み）', () async {
    final store = storeWith({});

    expect(await store.readUser(), isNull);
  });

  test('保存したユーザーを読み返せる', () async {
    final store = storeWith({});

    await store.writeUser(testUser);

    expect(await store.readUser(), testUser);
  });

  // 「無い」と同じ null を返すと、ログイン時に前のユーザーが居なかったことに
  // なり、前のユーザーのデータを破棄せずに次のユーザーへ見せてしまう（#15）。
  test('JSON として壊れていれば「無い」ではなく読めない例外を投げる', () async {
    final store = storeWith({'auth_user': '{broken'});

    await expectLater(
      store.readUser(),
      throwsA(isA<StoredUserUnreadableException>()),
    );
  });

  test('形式が変わって読み解けなければ（必須項目の欠け）読めない例外を投げる', () async {
    final json = testUser.toJson()..remove('id');
    final store = storeWith({'auth_user': jsonEncode(json)});

    await expectLater(
      store.readUser(),
      throwsA(isA<StoredUserUnreadableException>()),
    );
  });

  test('オブジェクトでない値も読めない例外にする', () async {
    final store = storeWith({'auth_user': '[1, 2]'});

    await expectLater(
      store.readUser(),
      throwsA(isA<StoredUserUnreadableException>()),
    );
  });
}
