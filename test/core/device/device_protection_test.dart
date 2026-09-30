import 'dart:io';

import 'package:comic_laz/core/device/device_protection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 本物のネイティブには届かない（テスト用のメッセンジャーで受ける）。
  const channel = MethodChannel(MethodChannelDeviceProtection.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];
  void handleWith(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('iOS ではパスを渡して、除外に失敗したパスを返す', () async {
    handleWith((call) => ['/b']);
    final protection = MethodChannelDeviceProtection(isIOS: true);

    final failed = await protection.excludeFromBackup([
      Directory('/a'),
      Directory('/b'),
    ]);

    expect(failed, ['/b']);
    expect(calls.single.method, 'excludeFromBackup');
    expect(calls.single.arguments, {
      'paths': ['/a', '/b'],
    });
  });

  // 古いネイティブのビルド・デスクトップでチャネルが無くても、起動を止めない。
  test('チャネルが無ければ除外は何もせずに終わる', () async {
    final protection = MethodChannelDeviceProtection(isIOS: true);

    expect(await protection.excludeFromBackup([Directory('/a')]), isEmpty);
  });

  test('Android ではバックアップ除外のチャネルを呼ばない（マニフェストで外しているため）', () async {
    handleWith((call) => null);
    final protection = MethodChannelDeviceProtection(isIOS: false);

    await protection.excludeFromBackup([Directory('/a')]);

    expect(calls, isEmpty);
  });
}
