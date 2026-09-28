import 'package:comic_laz/core/config/app_config.dart';
import 'package:comic_laz/core/device/device_name_resolver.dart';
import 'package:comic_laz/core/session/session_data_purger.dart';
import 'package:comic_laz/core/widgets/thumbnail_image.dart';
import 'package:comic_laz/data/api/books_api.dart';
import 'package:comic_laz/data/api/taxonomy_api.dart';
import 'package:comic_laz/data/api/user_api.dart';
import 'package:comic_laz/features/auth/application/auth_controller.dart';
import 'package:comic_laz/features/auth/data/auth_api.dart';
import 'package:comic_laz/features/auth/data/auth_store.dart';
import 'package:comic_laz/features/auth/domain/auth_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_fakes.dart';
import 'auth_fakes.dart';

/// プラットフォームチャネルとネットワークを触らないようにした標準の override 群。
List<Override> testOverrides({
  AuthStore? authStore,
  AuthApi? authApi,
  DeviceNameResolver? deviceNameResolver,
  List<SessionDataPurger>? purgers,
  BooksApi? booksApi,
  UserApi? userApi,
  TaxonomyApi? taxonomyApi,
  ThumbnailBuilder? thumbnailBuilder,
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
    booksApiProvider.overrideWithValue(booksApi ?? FakeBooksApi()),
    userApiProvider.overrideWithValue(userApi ?? FakeUserApi()),
    taxonomyApiProvider.overrideWithValue(taxonomyApi ?? FakeTaxonomyApi()),
    // 画像はネットワークを触らせない（URL とヘッダだけ検証できるようにする）。
    thumbnailBuilderProvider.overrideWithValue(
      thumbnailBuilder ??
          (context, url, headers, fit) =>
              StubThumbnail(url: url, headers: headers),
    ),
  ];
}

/// テスト用のサムネイル代替ウィジェット。
class StubThumbnail extends StatelessWidget {
  const StubThumbnail({required this.url, required this.headers, super.key});

  final Uri url;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// テスト用の [ProviderContainer]。
ProviderContainer createContainer({
  AuthStore? authStore,
  AuthApi? authApi,
  DeviceNameResolver? deviceNameResolver,
  List<SessionDataPurger>? purgers,
  BooksApi? booksApi,
  UserApi? userApi,
  TaxonomyApi? taxonomyApi,
}) {
  return ProviderContainer(
    overrides: testOverrides(
      authStore: authStore,
      authApi: authApi,
      deviceNameResolver: deviceNameResolver,
      purgers: purgers,
      booksApi: booksApi,
      userApi: userApi,
      taxonomyApi: taxonomyApi,
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
