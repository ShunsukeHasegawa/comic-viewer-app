// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_screen_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(readingScreenMode)
final readingScreenModeProvider = ReadingScreenModeProvider._();

final class ReadingScreenModeProvider
    extends
        $FunctionalProvider<
          ReadingScreenMode,
          ReadingScreenMode,
          ReadingScreenMode
        >
    with $Provider<ReadingScreenMode> {
  ReadingScreenModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readingScreenModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readingScreenModeHash();

  @$internal
  @override
  $ProviderElement<ReadingScreenMode> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReadingScreenMode create(Ref ref) {
    return readingScreenMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReadingScreenMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReadingScreenMode>(value),
    );
  }
}

String _$readingScreenModeHash() => r'712a9b54a38682556aacf3727617601e094f6614';
