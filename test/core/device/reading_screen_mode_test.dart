import 'package:comic_laz/core/device/reading_screen_mode.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
