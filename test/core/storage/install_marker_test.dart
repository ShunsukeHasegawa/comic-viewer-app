import 'dart:io';

import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/core/storage/install_marker.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  // iOS の Keychain はアプリの削除で消えない。DB を新しく作ったこと
  // （= 入れ直し）を目印に、前のインストールのトークンを片付ける（#15）。
  test('DB を新しく作ったときは入れ直し直後とみなす', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    expect(await DriftInstallMarker(database).isFreshInstall(), isTrue);
  });

  test('片付けた後は入れ直し直後とみなさない（起動のたびにログアウトさせないため）', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final marker = DriftInstallMarker(database);

    await marker.markHandled();

    expect(await marker.isFreshInstall(), isFalse);
  });

  test('既存の DB を開き直しても目印は戻らない（次の起動・アップデートでログアウトさせないため）', () async {
    final directory = Directory.systemTemp.createTempSync('install_marker');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File(p.join(directory.path, 'app.sqlite'));

    final first = AppDatabase(NativeDatabase(file));
    await DriftInstallMarker(first).markHandled();
    await first.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    expect(await DriftInstallMarker(reopened).isFreshInstall(), isFalse);
  });
}
