import 'dart:io';

import 'package:comic_laz/core/device/device_protection.dart';
import 'package:comic_laz/core/device/in_app_browser.dart';

/// プラットフォームチャネルに触らない [DeviceProtection]。
///
/// 呼ばれたパスを記録し、失敗を差し込める。
class FakeDeviceProtection implements DeviceProtection {
  /// [excludeFromBackup] に渡されたパス（呼び出しごと）。
  final excludeCalls = <List<String>>[];

  /// バックアップ除外に失敗したことにするパス。
  Set<String> failingPaths = {};

  /// [excludeFromBackup] で投げる例外（チャネルの障害）。
  Object? excludeError;

  @override
  Future<List<String>> excludeFromBackup(List<Directory> directories) async {
    final paths = [for (final directory in directories) directory.path];
    excludeCalls.add(paths);
    if (excludeError case final error?) throw error;
    return [
      for (final path in paths)
        if (failingPaths.contains(path)) path,
    ];
  }
}

/// プラットフォームチャネルに触らない [InAppBrowser]。
///
/// 開こうとした URL を記録し、開けなかったことにもできる。
class FakeInAppBrowser implements InAppBrowser {
  /// [open] に渡された URL（呼び出し順）。
  final opened = <Uri>[];

  /// `false` にすると「ブラウザが無い」などで開けなかったことにする。
  bool succeeds = true;

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return succeeds;
  }
}
