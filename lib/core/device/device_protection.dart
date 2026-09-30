import 'dart:io';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_protection.g.dart';

/// OS の保護機能（#15）。テストでは `FakeDeviceProtection` に差し替える。
///
/// プラグインは使わず、アプリ内の小さなチャネル 1 本で済ませる（除外フラグ
/// 1 行のために、無関係な権限・機能を持ち込まない）。ネイティブ側は
/// `ios/Runner/AppDelegate.swift` だけ。Android はバックアップ除外をマニフェストの
/// `data_extraction_rules.xml` で行うので、チャネルを持たない（ここからも呼ばない）。
abstract interface class DeviceProtection {
  /// [directories] を iCloud / PC のバックアップから外す（iOS のみ）。
  ///
  /// 除外に失敗したパスを返す（iOS 以外・チャネルが無い環境では常に空）。
  /// 存在しないパスは飛ばす（次の起動で作られていれば掛かる）。
  Future<List<String>> excludeFromBackup(List<Directory> directories);
}

/// ネイティブのチャネルを呼ぶ実装。
///
/// チャネルが無い環境（デスクトップ・テスト・古いネイティブのビルド）でも
/// 落とさない。保護は「掛けられるなら掛ける」もので、掛けられないことを
/// 理由に起動や設定画面を止めない。
class MethodChannelDeviceProtection implements DeviceProtection {
  MethodChannelDeviceProtection({MethodChannel? channel, bool? isIOS})
    : _channel = channel ?? const MethodChannel(channelName),
      _isIOS = isIOS ?? Platform.isIOS;

  static const channelName = 'com.lazgram.comic_laz/device_protection';

  final MethodChannel _channel;
  final bool _isIOS;

  @override
  Future<List<String>> excludeFromBackup(List<Directory> directories) async {
    // Android は端末の設定ファイル（data_extraction_rules.xml）で除外している。
    if (!_isIOS || directories.isEmpty) return const [];
    try {
      final failed = await _channel.invokeListMethod<String>(
        'excludeFromBackup',
        {
          'paths': [for (final directory in directories) directory.path],
        },
      );
      return failed ?? const [];
    } on MissingPluginException {
      return const [];
    }
  }
}

@Riverpod(keepAlive: true)
DeviceProtection deviceProtection(Ref ref) => MethodChannelDeviceProtection();
