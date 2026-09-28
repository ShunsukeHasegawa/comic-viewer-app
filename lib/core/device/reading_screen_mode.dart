import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'screen_wake_lock.dart';

part 'reading_screen_mode.g.dart';

/// 読書中の画面設定（全画面表示 + スリープ抑止）。
///
/// 巻から巻へ遷移するとき、**新しい画面の初期化が先に走り、古い画面の破棄が
/// 後から走る**（go_router の pushReplacement は退場アニメーション後に破棄する）。
/// 各画面が無条件に解除すると次の巻が素の状態で始まってしまうため、
/// 参照カウントで管理する。
class ReadingScreenMode {
  ReadingScreenMode(this._wakeLock);

  final ScreenWakeLock _wakeLock;

  int _activeCount = 0;

  /// 現在の参照数（テスト用）。
  int get activeCount => _activeCount;

  Future<void> acquire() async {
    _activeCount++;
    if (_activeCount > 1) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await _wakeLock.enable();
  }

  Future<void> release() async {
    if (_activeCount == 0) return;
    _activeCount--;
    if (_activeCount > 0) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await _wakeLock.disable();
  }
}

@Riverpod(keepAlive: true)
ReadingScreenMode readingScreenMode(Ref ref) =>
    ReadingScreenMode(ref.watch(screenWakeLockProvider));
