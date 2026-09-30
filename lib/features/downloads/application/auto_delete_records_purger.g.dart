// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auto_delete_records_purger.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(autoDeleteRecordsPurger)
final autoDeleteRecordsPurgerProvider = AutoDeleteRecordsPurgerProvider._();

final class AutoDeleteRecordsPurgerProvider
    extends
        $FunctionalProvider<
          SessionDataPurger,
          SessionDataPurger,
          SessionDataPurger
        >
    with $Provider<SessionDataPurger> {
  AutoDeleteRecordsPurgerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoDeleteRecordsPurgerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoDeleteRecordsPurgerHash();

  @$internal
  @override
  $ProviderElement<SessionDataPurger> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionDataPurger create(Ref ref) {
    return autoDeleteRecordsPurger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionDataPurger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionDataPurger>(value),
    );
  }
}

String _$autoDeleteRecordsPurgerHash() =>
    r'beaca736d61934926c45c1931dc20dff5af524b3';
