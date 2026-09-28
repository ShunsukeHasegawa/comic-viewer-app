import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'screen_wake_lock.g.dart';

/// 画面のスリープ抑止。
///
/// 読書中はページ送り以外の操作が無く、既定のスリープ時間では消灯してしまうため、
/// ビューア表示中だけ有効にする。
abstract interface class ScreenWakeLock {
  Future<void> enable();

  Future<void> disable();
}

class PlatformScreenWakeLock implements ScreenWakeLock {
  const PlatformScreenWakeLock();

  @override
  Future<void> enable() => _guard(() => WakelockPlus.enable());

  @override
  Future<void> disable() => _guard(() => WakelockPlus.disable());

  /// 端末が対応していない場合でも読書を止めない。
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // 失敗しても致命的ではない（消灯するだけ）。
    }
  }
}

@Riverpod(keepAlive: true)
ScreenWakeLock screenWakeLock(Ref ref) => const PlatformScreenWakeLock();
