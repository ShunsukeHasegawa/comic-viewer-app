import 'dart:io';

import 'package:comic_laz/core/storage/app_directories.dart';
import 'package:comic_laz/core/storage/storage_protection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/device_fakes.dart';

void main() {
  late Directory root;
  late AppDirectories directories;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('comic_laz_protect');
    directories = AppDirectories(
      support: Directory(p.join(root.path, 'support')),
      cache: Directory(p.join(root.path, 'cache')),
      documents: Directory(p.join(root.path, 'documents')),
    );
    await directories.ensureCreated();
    directories.documents!.createSync();
    addTearDown(() {
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        // 一時ディレクトリなので OS に任せる。
      }
    });
  });

  File noMediaIn(Directory directory) =>
      File(p.join(directory.path, StorageProtector.noMediaFileName));

  group('Android', () {
    StorageProtector android(FakeDeviceProtection protection) =>
        StorageProtector(protection: protection, isAndroid: true, isIOS: false);

    test('support と cache の直下に .nomedia を置く（ギャラリーやメディアスキャンに出さないため）', () async {
      await android(FakeDeviceProtection()).protect(directories);

      expect(noMediaIn(directories.support).existsSync(), isTrue);
      expect(noMediaIn(directories.cache).existsSync(), isTrue);
    });

    test(
      '.nomedia は images/ と downloads/ には置かない（孤児の掃除とログアウトの全削除で消されるため）',
      () async {
        await android(FakeDeviceProtection()).protect(directories);

        expect(noMediaIn(directories.imageCache).existsSync(), isFalse);
        expect(noMediaIn(directories.downloads).existsSync(), isFalse);
      },
    );

    test('OS にキャッシュを消されても、次の起動で .nomedia を置き直す', () async {
      final protector = android(FakeDeviceProtection());
      await protector.protect(directories);
      noMediaIn(directories.cache).deleteSync();

      await protector.protect(directories);

      expect(noMediaIn(directories.cache).existsSync(), isTrue);
    });

    test('バックアップ除外のチャネルは呼ばない（マニフェストの除外ルールで外しているため）', () async {
      final protection = FakeDeviceProtection();

      await android(protection).protect(directories);

      expect(protection.excludeCalls, isEmpty);
    });
  });

  group('iOS', () {
    StorageProtector ios(FakeDeviceProtection protection) =>
        StorageProtector(protection: protection, isAndroid: false, isIOS: true);

    test(
      'ダウンロード・転送の記録・DB・画像キャッシュの置き場をバックアップから外す（数 GB とトークンを iCloud に載せないため）',
      () async {
        final protection = FakeDeviceProtection();

        await ios(protection).protect(directories);

        expect(protection.excludeCalls, hasLength(1));
        expect(
          protection.excludeCalls.single,
          containsAll([
            directories.support.path,
            directories.downloads.path,
            directories.documents!.path,
            directories.imageCache.path,
          ]),
        );
      },
    );

    test('.nomedia は置かない（Android のメディアスキャナ向けの印なので）', () async {
      await ios(FakeDeviceProtection()).protect(directories);

      expect(noMediaIn(directories.support).existsSync(), isFalse);
      expect(noMediaIn(directories.cache).existsSync(), isFalse);
    });

    test('除外に失敗しても起動は止めない（次の起動で掛け直す）', () async {
      final protection = FakeDeviceProtection()
        ..excludeError = StateError('channel broken');

      await expectLater(ios(protection).protect(directories), completes);
    });

    test('一部のパスだけ失敗しても例外にしない', () async {
      final protection = FakeDeviceProtection()
        ..failingPaths = {directories.support.path};

      await expectLater(ios(protection).protect(directories), completes);
    });
  });
}
