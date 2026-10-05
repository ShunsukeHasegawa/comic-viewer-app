import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/settings/application/keep_screen_on_setting.dart';
import 'screen_wake_lock.dart';

part 'reading_screen_mode.g.dart';

/// 読書中の画面設定（全画面表示 + スリープ抑止）。
///
/// 巻から巻へ遷移するとき、**新しい画面の初期化が先に走り、古い画面の破棄が
/// 後から走る**（go_router の pushReplacement は退場アニメーション後に破棄する）。
/// 各画面が無条件に解除すると次の巻が素の状態で始まってしまうため、
/// 参照カウントで管理する。
///
/// スリープ抑止は「読書中は画面を消さない」の設定（#19）に従う。全画面表示は
/// 読書のための表示なので設定に関わらず続ける。
class ReadingScreenMode {
  ReadingScreenMode(this._wakeLock, {Future<bool> Function()? keepScreenOn})
    : _readKeepScreenOn = keepScreenOn ?? _alwaysKeepScreenOn;

  static Future<bool> _alwaysKeepScreenOn() async => true;

  final ScreenWakeLock _wakeLock;
  final Future<bool> Function() _readKeepScreenOn;

  int _activeCount = 0;

  /// スリープ抑止を有効にしてあるか。
  ///
  /// 設定の切り替えと acquire / release が前後しても、二重に有効化したり
  /// 有効にしていないものを解除したりしないよう、実際の状態を控えておく。
  bool _wakeLockHeld = false;

  /// 現在の参照数（テスト用）。
  int get activeCount => _activeCount;

  Future<void> acquire() async {
    _activeCount++;
    if (_activeCount > 1) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final keepScreenOn = await _keepScreenOn();
    // 設定を読む間に閉じられていたら有効にしない（解除する側はもう走った後）。
    if (_activeCount == 0) return;
    await _applyWakeLock(keepScreenOn);
  }

  Future<void> release() async {
    if (_activeCount == 0) return;
    _activeCount--;
    if (_activeCount > 0) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await _applyWakeLock(false);
  }

  /// 設定が変わったときに呼ぶ。読書中ならその場で反映する。
  ///
  /// 読書中にマイページは開けないので普段は起きないが、次に開くまで古い設定の
  /// ままにしないため（読書中でなければ次の acquire が読み直す）。
  Future<void> applyKeepScreenOn(bool keepScreenOn) async {
    if (_activeCount == 0) return;
    await _applyWakeLock(keepScreenOn);
  }

  /// 設定を読めなければ ON とみなす（設定が入る前と同じ挙動。読めないことで
  /// 読書中に消灯し始めるほうが困る）。
  Future<bool> _keepScreenOn() async {
    try {
      return await _readKeepScreenOn();
    } on Object {
      return true;
    }
  }

  Future<void> _applyWakeLock(bool enabled) async {
    if (_wakeLockHeld == enabled) return;
    // await の前に控える（待つ間に別の呼び出しが来ても重ねないように）。
    _wakeLockHeld = enabled;
    if (enabled) {
      await _wakeLock.enable();
    } else {
      await _wakeLock.disable();
    }
  }
}

@Riverpod(keepAlive: true)
ReadingScreenMode readingScreenMode(Ref ref) {
  final mode = ReadingScreenMode(
    ref.watch(screenWakeLockProvider),
    keepScreenOn: () => ref.read(keepScreenOnSettingProvider.future),
  );
  ref.listen(keepScreenOnSettingProvider, (_, next) {
    if (next.isLoading) return;
    // 読めなかったときは ON とみなす（acquire と同じ扱い）。
    unawaited(mode.applyKeepScreenOn(next.value ?? true));
  });
  return mode;
}
