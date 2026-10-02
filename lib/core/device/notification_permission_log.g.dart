// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_permission_log.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationPermissionLog)
final notificationPermissionLogProvider = NotificationPermissionLogProvider._();

final class NotificationPermissionLogProvider
    extends
        $FunctionalProvider<
          NotificationPermissionLog,
          NotificationPermissionLog,
          NotificationPermissionLog
        >
    with $Provider<NotificationPermissionLog> {
  NotificationPermissionLogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationPermissionLogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationPermissionLogHash();

  @$internal
  @override
  $ProviderElement<NotificationPermissionLog> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationPermissionLog create(Ref ref) {
    return notificationPermissionLog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationPermissionLog value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationPermissionLog>(value),
    );
  }
}

String _$notificationPermissionLogHash() =>
    r'fbbe333deef6b721f2c3c9b65fca8b84e3e6c166';
