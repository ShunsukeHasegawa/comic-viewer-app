import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/open_volume_store.dart';

part 'resume_reading_prompt.g.dart';

/// 起動直後のホームで「続きを読むか」尋ねる巻。尋ねなくてよければ `null`。
///
/// 控え（[OpenVolumeStore]）はビューアを閉じると消えるので、起動時に残って
/// いれば前回は読んでいる途中で終了させられている。尋ねるのはプロセスごとに
/// 1 回だけ（[dismiss] 後は `null` のまま）。
@Riverpod(keepAlive: true)
class ResumeReadingPrompt extends _$ResumeReadingPrompt {
  /// 読み込みの途中で [dismiss] されたか（読み終えた値で上書きしない）。
  bool _dismissed = false;

  @override
  Future<OpenVolume?> build() async {
    OpenVolume? stored;
    try {
      stored = await ref.read(openVolumeStoreProvider).read();
    } on Object {
      // 読めなければ尋ねないだけ（起動もホームの表示も止めない）。
      return null;
    }
    return _dismissed ? null : stored;
  }

  /// 尋ねた / 別の巻を開いた。このプロセスではもう尋ねない。
  void dismiss() {
    _dismissed = true;
    if (!ref.mounted) return;
    state = const AsyncData(null);
  }
}
