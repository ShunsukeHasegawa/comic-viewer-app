import 'dart:io';

import 'package:comic_laz/core/storage/app_directories.dart';
import 'package:comic_laz/features/downloads/data/free_space_probe.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _mib = 1024 * 1024;

DiskSpaceReader reader({
  Future<double?> Function(String path)? free,
  Future<double?> Function()? total,
}) => (
  freeMebibytesAt: free ?? (_) async => 100,
  totalMebibytes: total ?? () async => 1000,
);

void main() {
  test('MiB の値をバイトに直し、測る場所にはダウンロードの置き場を渡す', () async {
    final paths = <String>[];
    final storage = await probeDeviceStorage(
      path: '/support',
      reader: reader(
        free: (path) async {
          paths.add(path);
          return 1.5;
        },
        total: () async => 2048,
      ),
    );

    expect(
      storage,
      DeviceStorage(freeBytes: (1.5 * _mib).floor(), totalBytes: 2048 * _mib),
    );
    expect(paths, ['/support']);
  });

  // iOS は取得に失敗すると 0 を返す。0 のまま使うとキューが「空きが無い」と
  // 判定し、すべてのダウンロードが容量不足で止まる。
  for (final value in [0.0, -1.0, double.nan, double.infinity, null]) {
    test('空き容量が $value なら「分からない」にする（容量不足と誤判定しない）', () async {
      final storage = await probeDeviceStorage(
        path: '/support',
        reader: reader(free: (_) async => value),
      );
      expect(storage, isNull);
    });
  }

  // 取得できない端末（未登録のプラグイン / パスが無い）でダウンロードを塞がない。
  for (final error in [
    PlatformException(code: 'DISK_SPACE_ERROR'),
    MissingPluginException(),
    Exception('Specified path does not exist'),
  ]) {
    test('プラグインの例外（${error.runtimeType}）は投げずに「分からない」にする', () async {
      final storage = await probeDeviceStorage(
        path: '/support',
        reader: reader(free: (_) async => throw error),
      );
      expect(storage, isNull);
    });
  }

  test('全体の容量が取れなくても空き容量は返す（全体は表示にしか使わない）', () async {
    final failing = await probeDeviceStorage(
      path: '/support',
      reader: reader(total: () async => throw PlatformException(code: 'x')),
    );
    final zero = await probeDeviceStorage(
      path: '/support',
      reader: reader(total: () async => 0),
    );

    expect(failing, const DeviceStorage(freeBytes: 100 * _mib));
    expect(zero, const DeviceStorage(freeBytes: 100 * _mib));
  });

  test('キューの空き容量は設定画面と同じ測り方の値をそのまま使う', () async {
    final container = ProviderContainer(
      overrides: [
        deviceStorageProbeProvider.overrideWithValue(
          () async => const DeviceStorage(freeBytes: 42, totalBytes: 100),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(freeSpaceProbeProvider)(), 42);
  });

  test('ストレージが分からなければキューの空き容量も「分からない」', () async {
    final container = ProviderContainer(
      overrides: [
        deviceStorageProbeProvider.overrideWithValue(unknownDeviceStorage),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(freeSpaceProbeProvider)(), isNull);
  });

  test('ダウンロードの置き場が解決できなくても投げずに「分からない」にする', () async {
    final container = ProviderContainer(
      // 既定の自動再試行を止める（失敗が確定するまで待たされないように）。
      retry: (_, _) => null,
      overrides: [
        appDirectoriesProvider.overrideWith(
          (ref) async => throw const FileSystemException('置き場を作れません'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(deviceStorageProbeProvider)(), isNull);
  });

  test(
    'iOS の空き容量 API（required reason API）の利用理由をアプリのプライバシーマニフェストで宣言し、Runner に同梱する',
    () {
      // disk_space_2 は PrivacyInfo.xcprivacy を持たないので、宣言が無いと
      // App Store Connect へのアップロードが ITMS-91053 で弾かれる。
      final manifest = File('ios/Runner/PrivacyInfo.xcprivacy')
          .readAsStringSync();
      expect(manifest, contains('NSPrivacyAccessedAPICategoryDiskSpace'));
      expect(manifest, contains('<string>E174.1</string>'));

      // ファイルがあってもターゲットのリソースに入っていなければ同梱されない。
      final project = File('ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync();
      expect(project, contains('PrivacyInfo.xcprivacy in Resources */,'));
    },
  );
}
