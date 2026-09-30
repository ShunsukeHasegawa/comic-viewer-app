// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auto_delete_runner.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ビューアの状態が生きている巻を「開いている」とみなす。
///
/// ビューアのコントローラは画面を離れると破棄されるので、存在していれば
/// 読んでいる最中（または閉じる途中）。その巻の ZIP を消すとページが
/// 真っ黒になる。

@ProviderFor(openVolumeCheck)
final openVolumeCheckProvider = OpenVolumeCheckProvider._();

/// ビューアの状態が生きている巻を「開いている」とみなす。
///
/// ビューアのコントローラは画面を離れると破棄されるので、存在していれば
/// 読んでいる最中（または閉じる途中）。その巻の ZIP を消すとページが
/// 真っ黒になる。

final class OpenVolumeCheckProvider
    extends
        $FunctionalProvider<OpenVolumeCheck, OpenVolumeCheck, OpenVolumeCheck>
    with $Provider<OpenVolumeCheck> {
  /// ビューアの状態が生きている巻を「開いている」とみなす。
  ///
  /// ビューアのコントローラは画面を離れると破棄されるので、存在していれば
  /// 読んでいる最中（または閉じる途中）。その巻の ZIP を消すとページが
  /// 真っ黒になる。
  OpenVolumeCheckProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openVolumeCheckProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openVolumeCheckHash();

  @$internal
  @override
  $ProviderElement<OpenVolumeCheck> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OpenVolumeCheck create(Ref ref) {
    return openVolumeCheck(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OpenVolumeCheck value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OpenVolumeCheck>(value),
    );
  }
}

String _$openVolumeCheckHash() => r'8b41fb382001e9fc6113c46d80816fec4c5bcf56';

@ProviderFor(autoDeleteClock)
final autoDeleteClockProvider = AutoDeleteClockProvider._();

final class AutoDeleteClockProvider
    extends
        $FunctionalProvider<AutoDeleteClock, AutoDeleteClock, AutoDeleteClock>
    with $Provider<AutoDeleteClock> {
  AutoDeleteClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoDeleteClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoDeleteClockHash();

  @$internal
  @override
  $ProviderElement<AutoDeleteClock> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AutoDeleteClock create(Ref ref) {
    return autoDeleteClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AutoDeleteClock value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AutoDeleteClock>(value),
    );
  }
}

String _$autoDeleteClockHash() => r'c30a8cb310fcdde054cd0f14147cd38acdf0e13c';

/// ダウンロード済みの巻の自動削除（#13）。**自動削除はここだけが行う**。
///
/// state は直近の実行で消した結果（何も消していなければ前の値のまま）。

@ProviderFor(AutoDeleteRunner)
final autoDeleteRunnerProvider = AutoDeleteRunnerProvider._();

/// ダウンロード済みの巻の自動削除（#13）。**自動削除はここだけが行う**。
///
/// state は直近の実行で消した結果（何も消していなければ前の値のまま）。
final class AutoDeleteRunnerProvider
    extends $NotifierProvider<AutoDeleteRunner, AutoDeleteResult?> {
  /// ダウンロード済みの巻の自動削除（#13）。**自動削除はここだけが行う**。
  ///
  /// state は直近の実行で消した結果（何も消していなければ前の値のまま）。
  AutoDeleteRunnerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoDeleteRunnerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoDeleteRunnerHash();

  @$internal
  @override
  AutoDeleteRunner create() => AutoDeleteRunner();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AutoDeleteResult? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AutoDeleteResult?>(value),
    );
  }
}

String _$autoDeleteRunnerHash() => r'8ed9a2444fd15248a11752f30c235dda9f2fa6c7';

/// ダウンロード済みの巻の自動削除（#13）。**自動削除はここだけが行う**。
///
/// state は直近の実行で消した結果（何も消していなければ前の値のまま）。

abstract class _$AutoDeleteRunner extends $Notifier<AutoDeleteResult?> {
  AutoDeleteResult? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AutoDeleteResult?, AutoDeleteResult?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AutoDeleteResult?, AutoDeleteResult?>,
              AutoDeleteResult?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 前回の自動削除（設定画面の表示用）。
///
/// このプロセスで消した結果があればそれを、無ければ保存してある記録を返す。

@ProviderFor(autoDeleteLastResult)
final autoDeleteLastResultProvider = AutoDeleteLastResultProvider._();

/// 前回の自動削除（設定画面の表示用）。
///
/// このプロセスで消した結果があればそれを、無ければ保存してある記録を返す。

final class AutoDeleteLastResultProvider
    extends
        $FunctionalProvider<
          AsyncValue<AutoDeleteResult?>,
          AutoDeleteResult?,
          FutureOr<AutoDeleteResult?>
        >
    with
        $FutureModifier<AutoDeleteResult?>,
        $FutureProvider<AutoDeleteResult?> {
  /// 前回の自動削除（設定画面の表示用）。
  ///
  /// このプロセスで消した結果があればそれを、無ければ保存してある記録を返す。
  AutoDeleteLastResultProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoDeleteLastResultProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoDeleteLastResultHash();

  @$internal
  @override
  $FutureProviderElement<AutoDeleteResult?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AutoDeleteResult?> create(Ref ref) {
    return autoDeleteLastResult(ref);
  }
}

String _$autoDeleteLastResultHash() =>
    r'333021a55b25bae6c2113696ad243f879b39c1a5';

@ProviderFor(clearAutoDeleteRecords)
final clearAutoDeleteRecordsProvider = ClearAutoDeleteRecordsProvider._();

final class ClearAutoDeleteRecordsProvider
    extends
        $FunctionalProvider<
          ClearAutoDeleteRecords,
          ClearAutoDeleteRecords,
          ClearAutoDeleteRecords
        >
    with $Provider<ClearAutoDeleteRecords> {
  ClearAutoDeleteRecordsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clearAutoDeleteRecordsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clearAutoDeleteRecordsHash();

  @$internal
  @override
  $ProviderElement<ClearAutoDeleteRecords> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ClearAutoDeleteRecords create(Ref ref) {
    return clearAutoDeleteRecords(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClearAutoDeleteRecords value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClearAutoDeleteRecords>(value),
    );
  }
}

String _$clearAutoDeleteRecordsHash() =>
    r'8aa2808ec1ef6959817dbce04424539f554493f9';
