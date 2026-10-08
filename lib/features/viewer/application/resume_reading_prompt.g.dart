// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resume_reading_prompt.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 起動直後のホームで「続きを読むか」尋ねる巻。尋ねなくてよければ `null`。
///
/// 控え（[OpenVolumeStore]）はビューアを閉じると消えるので、起動時に残って
/// いれば前回は読んでいる途中で終了させられている。尋ねるのはプロセスごとに
/// 1 回だけ（[dismiss] 後は `null` のまま）。

@ProviderFor(ResumeReadingPrompt)
final resumeReadingPromptProvider = ResumeReadingPromptProvider._();

/// 起動直後のホームで「続きを読むか」尋ねる巻。尋ねなくてよければ `null`。
///
/// 控え（[OpenVolumeStore]）はビューアを閉じると消えるので、起動時に残って
/// いれば前回は読んでいる途中で終了させられている。尋ねるのはプロセスごとに
/// 1 回だけ（[dismiss] 後は `null` のまま）。
final class ResumeReadingPromptProvider
    extends $AsyncNotifierProvider<ResumeReadingPrompt, OpenVolume?> {
  /// 起動直後のホームで「続きを読むか」尋ねる巻。尋ねなくてよければ `null`。
  ///
  /// 控え（[OpenVolumeStore]）はビューアを閉じると消えるので、起動時に残って
  /// いれば前回は読んでいる途中で終了させられている。尋ねるのはプロセスごとに
  /// 1 回だけ（[dismiss] 後は `null` のまま）。
  ResumeReadingPromptProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resumeReadingPromptProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resumeReadingPromptHash();

  @$internal
  @override
  ResumeReadingPrompt create() => ResumeReadingPrompt();
}

String _$resumeReadingPromptHash() =>
    r'84c58ecefc4d5f7af7da62a8160e80f922154d9a';

/// 起動直後のホームで「続きを読むか」尋ねる巻。尋ねなくてよければ `null`。
///
/// 控え（[OpenVolumeStore]）はビューアを閉じると消えるので、起動時に残って
/// いれば前回は読んでいる途中で終了させられている。尋ねるのはプロセスごとに
/// 1 回だけ（[dismiss] 後は `null` のまま）。

abstract class _$ResumeReadingPrompt extends $AsyncNotifier<OpenVolume?> {
  FutureOr<OpenVolume?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<OpenVolume?>, OpenVolume?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<OpenVolume?>, OpenVolume?>,
              AsyncValue<OpenVolume?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
