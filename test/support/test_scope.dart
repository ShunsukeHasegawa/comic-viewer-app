import 'package:comic_laz/core/config/app_config.dart';
import 'package:comic_laz/core/device/device_name_resolver.dart';
import 'package:comic_laz/core/session/session_data_purger.dart';
import 'package:comic_laz/features/auth/application/auth_controller.dart';
import 'package:comic_laz/features/auth/data/auth_api.dart';
import 'package:comic_laz/features/auth/data/auth_store.dart';
import 'package:comic_laz/features/auth/domain/auth_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_fakes.dart';

/// プラットフォームチャネルを触らないようにした標準の override 群。
List<Override> testOverrides({
  AuthStore? authStore,
  AuthApi? authApi,
  DeviceNameResolver? deviceNameResolver,
  List<SessionDataPurger>? purgers,
  String apiBaseUrl = 'http://localhost:8000',
}) {
  return [
    appConfigProvider.overrideWithValue(
      AppConfig.from(apiBaseUrl: apiBaseUrl, flavor: 'development'),
    ),
    authStoreProvider.overrideWithValue(authStore ?? FakeAuthStore()),
    deviceNameResolverProvider.overrideWithValue(
      deviceNameResolver ?? FakeDeviceNameResolver(),
    ),
    sessionDataPurgersProvider.overrideWithValue(purgers ?? const []),
    if (authApi != null) authApiProvider.overrideWithValue(authApi),
  ];
}

/// テスト用の [ProviderContainer]。
ProviderContainer createContainer({
  AuthStore? authStore,
  AuthApi? authApi,
  DeviceNameResolver? deviceNameResolver,
  List<SessionDataPurger>? purgers,
}) {
  return ProviderContainer(
    overrides: testOverrides(
      authStore: authStore,
      authApi: authApi,
      deviceNameResolver: deviceNameResolver,
      purgers: purgers,
    ),
  );
}

/// ウィジェットを override 込みの [ProviderScope] で包む。
Widget wrapWithScope(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(overrides: overrides, child: child);

/// `authControllerProvider` を構築し、起動時のトークン検証が終わるまで待つ。
Future<AuthState> settleAuth(ProviderContainer container) async {
  // read しないと build されない = 復元処理が始まらない。
  container.read(authControllerProvider);
  await pumpEventQueue();
  return container.read(authControllerProvider);
}
