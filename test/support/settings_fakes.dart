import 'dart:async';

import 'package:comic_laz/features/settings/application/keep_screen_on_setting.dart';
import 'package:comic_laz/features/settings/application/theme_mode_setting.dart';
import 'package:flutter/material.dart';

/// メモリ上に持つ [ThemeModeStore]（drift はプラットフォームチャネルを使うため）。
class InMemoryThemeModeStore implements ThemeModeStore {
  InMemoryThemeModeStore([this.mode = ThemeMode.system]);

  ThemeMode mode;

  /// 書き込みを失敗させる（保存できなかったときに表示を変えないことの確認用）。
  Object? writeError;

  /// 読み込みを失敗させる。
  Object? readError;

  /// 読み込みを止めておく（起動前の読み込みが時間切れになる場合の確認用）。
  Completer<void>? readGate;

  final writes = <ThemeMode>[];

  @override
  Future<ThemeMode> read() async {
    await readGate?.future;
    if (readError case final error?) throw error;
    return mode;
  }

  @override
  Future<void> write(ThemeMode mode) async {
    if (writeError case final error?) throw error;
    writes.add(mode);
    this.mode = mode;
  }
}

/// メモリ上に持つ [KeepScreenOnStore]（drift はプラットフォームチャネルを使うため）。
class InMemoryKeepScreenOnStore implements KeepScreenOnStore {
  InMemoryKeepScreenOnStore([this.keepScreenOn = true]);

  bool keepScreenOn;

  /// 書き込みを失敗させる（保存できなかったときに表示を変えないことの確認用）。
  Object? writeError;

  /// 読み込みを失敗させる。
  Object? readError;

  final writes = <bool>[];

  @override
  Future<bool> read() async {
    if (readError case final error?) throw error;
    return keepScreenOn;
  }

  @override
  Future<void> write(bool keepScreenOn) async {
    if (writeError case final error?) throw error;
    writes.add(keepScreenOn);
    this.keepScreenOn = keepScreenOn;
  }
}
