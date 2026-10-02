// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_messaging.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pushMessaging)
final pushMessagingProvider = PushMessagingProvider._();

final class PushMessagingProvider
    extends $FunctionalProvider<PushMessaging, PushMessaging, PushMessaging>
    with $Provider<PushMessaging> {
  PushMessagingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushMessagingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushMessagingHash();

  @$internal
  @override
  $ProviderElement<PushMessaging> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushMessaging create(Ref ref) {
    return pushMessaging(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushMessaging value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushMessaging>(value),
    );
  }
}

String _$pushMessagingHash() => r'8bfcc45c03a4672268006f1bba22d92282d07a49';
