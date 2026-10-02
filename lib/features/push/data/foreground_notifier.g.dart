// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foreground_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(foregroundNotifications)
final foregroundNotificationsProvider = ForegroundNotificationsProvider._();

final class ForegroundNotificationsProvider
    extends
        $FunctionalProvider<
          ForegroundNotifier,
          ForegroundNotifier,
          ForegroundNotifier
        >
    with $Provider<ForegroundNotifier> {
  ForegroundNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foregroundNotificationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foregroundNotificationsHash();

  @$internal
  @override
  $ProviderElement<ForegroundNotifier> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ForegroundNotifier create(Ref ref) {
    return foregroundNotifications(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ForegroundNotifier value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ForegroundNotifier>(value),
    );
  }
}

String _$foregroundNotificationsHash() =>
    r'b503a7933ddee085f0a59afc9584771e954da50a';
