import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_name_resolver.g.dart';

/// トークン発行時にサーバーへ渡す端末名（Sanctum の `device_name`）。
abstract interface class DeviceNameResolver {
  Future<String> resolve();
}

class PlatformDeviceNameResolver implements DeviceNameResolver {
  PlatformDeviceNameResolver({DeviceInfoPlugin? deviceInfo})
    : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  /// `device_name` カラムに収まるよう切り詰める長さ。
  static const maxLength = 100;

  final DeviceInfoPlugin _deviceInfo;

  @override
  Future<String> resolve() async {
    final normalized = (await _readName()).trim();
    if (normalized.isEmpty) return Platform.operatingSystem;
    return normalized.length <= maxLength
        ? normalized
        : normalized.substring(0, maxLength);
  }

  Future<String> _readName() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return '${info.manufacturer} ${info.model}';
      }
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.name;
      }
      return Platform.operatingSystem;
    } on Object {
      // 端末情報が取れなくてもログインは続行させる。
      return Platform.operatingSystem;
    }
  }
}

@Riverpod(keepAlive: true)
DeviceNameResolver deviceNameResolver(Ref ref) => PlatformDeviceNameResolver();
