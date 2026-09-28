import 'package:comic_laz/core/config/app_config.dart';
import 'package:comic_laz/core/widgets/thumbnail_image.dart';
import 'package:comic_laz/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/auth_fakes.dart';
import '../../support/test_scope.dart';

/// 実際に組み立てられた URL とヘッダを記録する。
final requests = <({Uri url, Map<String, String> headers})>[];

Future<ProviderContainer> pumpThumbnail(
  WidgetTester tester, {
  required String? apiUrl,
  FakeAuthStore? store,
  bool stubDeleteToken = false,
}) async {
  requests.clear();
  final api = MockAuthApi()..stubCurrentUser();
  if (stubDeleteToken) {
    when(api.deleteToken).thenAnswer((_) async {});
  }
  final container = ProviderContainer(
    overrides: testOverrides(
      authStore: store ?? FakeAuthStore(token: 'stored-token'),
      authApi: api,
      apiBaseUrl: 'https://comic.lazgram.com',
      thumbnailBuilder: (context, url, headers, fit) {
        requests.add((url: url, headers: headers));
        return const SizedBox.expand();
      },
    ),
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: ThumbnailImage(apiUrl: apiUrl)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('API 配信元の画像には Bearer を付ける', (tester) async {
    await pumpThumbnail(tester, apiUrl: '/books/thumbnail/340?m=1');

    expect(
      requests.single.url.toString(),
      'https://comic.lazgram.com/books/thumbnail/340?m=1',
    );
    expect(requests.single.headers['Authorization'], 'Bearer stored-token');
  });

  testWidgets('別ホスト（CDN 等）の画像にはトークンを付けない', (tester) async {
    await pumpThumbnail(tester, apiUrl: 'https://cdn.example.com/t/1.jpg');

    expect(requests.single.url.host, 'cdn.example.com');
    expect(
      requests.single.headers.containsKey('Authorization'),
      isFalse,
      reason: 'セッショントークンを第三者に渡してはいけない',
    );
  });

  testWidgets('サムネイル無し（null）は画像を取得しない', (tester) async {
    await pumpThumbnail(tester, apiUrl: null);

    expect(requests, isEmpty);
    expect(find.byType(ThumbnailPlaceholder), findsOneWidget);
  });

  testWidgets('ログインし直すと新しいトークンを使う', (tester) async {
    final store = FakeAuthStore(token: 'old-token');
    final container = await pumpThumbnail(
      tester,
      apiUrl: '/books/thumbnail/340?m=1',
      store: store,
      stubDeleteToken: true,
    );
    expect(requests.last.headers['Authorization'], 'Bearer old-token');

    // ログアウト → 別のトークンでログイン
    await container.read(authControllerProvider.notifier).logout();
    store.token = 'new-token';
    await container.read(authControllerProvider.notifier).restoreSession();
    await tester.pumpAndSettle();

    expect(
      requests.last.headers['Authorization'],
      'Bearer new-token',
      reason: '失効したトークンを使い続けると全サムネイルが 401 のままになる',
    );
  });

  test('isApiOrigin はスキーム / ホスト / ポートで判定する', () {
    final config = AppConfig.from(
      apiBaseUrl: 'https://comic.lazgram.com',
      flavor: 'production',
    );

    expect(
      config.isApiOrigin(Uri.parse('https://comic.lazgram.com/books/1')),
      isTrue,
    );
    expect(
      config.isApiOrigin(Uri.parse('http://comic.lazgram.com/books/1')),
      isFalse,
    );
    expect(
      config.isApiOrigin(Uri.parse('https://cdn.example.com/1.jpg')),
      isFalse,
    );
    expect(
      config.isApiOrigin(Uri.parse('https://comic.lazgram.com:8443/1')),
      isFalse,
    );
  });
}
