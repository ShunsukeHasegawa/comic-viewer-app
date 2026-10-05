import 'dart:async';

import 'package:comic_laz/core/device/reading_screen_mode.dart';
import 'package:comic_laz/core/device/screen_wake_lock.dart';
import 'package:comic_laz/features/settings/application/keep_screen_on_setting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/settings_fakes.dart';
import '../../support/test_scope.dart';
import '../../support/viewer_fakes.dart';

void main() {
  // SystemChrome を呼ぶのでバインディングを用意する。
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeScreenWakeLock wakeLock;
  late ReadingScreenMode mode;

  setUp(() {
    wakeLock = FakeScreenWakeLock();
    mode = ReadingScreenMode(wakeLock);
  });

  test('最初の acquire でスリープ抑止を有効にする', () async {
    await mode.acquire();

    expect(mode.activeCount, 1);
    expect(wakeLock.enableCount, 1);
  });

  test('巻をまたぐ遷移（新画面 → 旧画面の破棄）で解除されない', () async {
    // 新しい巻の画面が acquire したあとに古い画面が release する順序
    await mode.acquire();
    await mode.acquire();
    await mode.release();

    expect(mode.activeCount, 1);
    expect(wakeLock.enabled, isTrue, reason: '次の巻が素の状態で始まってはいけない');
    expect(wakeLock.enableCount, 1, reason: '二重に有効化しない');
  });

  test('最後の release で解除する', () async {
    await mode.acquire();
    await mode.acquire();
    await mode.release();
    await mode.release();

    expect(mode.activeCount, 0);
    expect(wakeLock.enabled, isFalse);
    expect(wakeLock.disableCount, 1);
  });

  test('余分な release は無視する', () async {
    await mode.release();

    expect(mode.activeCount, 0);
    expect(wakeLock.disableCount, 0);
  });

  group('「読書中は画面を消さない」（#19）', () {
    /// 全画面表示の切り替えを記録する（テストのバインディングが持つ
    /// 疑似のメッセンジャーに差し込むだけで、本物のチャネルには届かない）。
    late List<String> uiModes;

    setUp(() {
      uiModes = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
              uiModes.add(call.arguments as String);
            }
            return null;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    test('OFF ならスリープ抑止だけ使わず、全画面表示は続ける', () async {
      final mode = ReadingScreenMode(wakeLock, keepScreenOn: () async => false);

      await mode.acquire();
      expect(wakeLock.enableCount, 0);
      expect(uiModes, ['SystemUiMode.immersiveSticky']);

      await mode.release();
      // 有効にしていないものは解除しない。
      expect(wakeLock.disableCount, 0);
      expect(uiModes.last, 'SystemUiMode.edgeToEdge');
    });

    test('設定を読めなければ ON とみなす（読めないことで読書中に消灯させない）', () async {
      final mode = ReadingScreenMode(
        wakeLock,
        keepScreenOn: () async => throw StateError('db'),
      );

      await mode.acquire();

      expect(wakeLock.enabled, isTrue);
    });

    test('設定を読む間に閉じられたら有効にしない（閉じた後に点きっぱなしにしない）', () async {
      final gate = Completer<bool>();
      final mode = ReadingScreenMode(wakeLock, keepScreenOn: () => gate.future);

      final acquiring = mode.acquire();
      await mode.release();
      gate.complete(true);
      await acquiring;

      expect(wakeLock.enableCount, 0);
    });

    test('読書中に設定が変わればその場で反映する', () async {
      final mode = ReadingScreenMode(wakeLock);
      await mode.acquire();

      await mode.applyKeepScreenOn(false);
      expect(wakeLock.enabled, isFalse);

      await mode.applyKeepScreenOn(true);
      expect(wakeLock.enabled, isTrue);
      expect(wakeLock.enableCount, 2);
    });

    test('読書中でなければ設定が変わっても触らない（次に開くときに読み直す）', () async {
      final mode = ReadingScreenMode(wakeLock);

      await mode.applyKeepScreenOn(true);

      expect(wakeLock.enableCount, 0);
    });

    test('プロバイダは保存済みの設定に従い、マイページでの切り替えも読書中に反映する', () async {
      final store = InMemoryKeepScreenOnStore(false);
      final container = createContainer(
        keepScreenOnStore: store,
        overrides: [screenWakeLockProvider.overrideWithValue(wakeLock)],
      );
      addTearDown(container.dispose);
      final mode = container.read(readingScreenModeProvider);

      await mode.acquire();
      expect(wakeLock.enabled, isFalse);

      await container.read(keepScreenOnSettingProvider.notifier).set(true);
      await pumpEventQueue();
      expect(wakeLock.enabled, isTrue);
    });
  });
}
