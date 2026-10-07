import 'dart:async';

import 'package:comic_laz/core/cache/comic_image_loader.dart';
import 'package:comic_laz/core/media/media_urls.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/core/widgets/thumbnail_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_scope.dart';

/// 実際に組み立てられた取得指定（URL とキャッシュキー）。
final requests = <ComicImageRequest>[];

Future<void> pumpThumbnail(
  WidgetTester tester, {
  required String? apiUrl,
}) async {
  requests.clear();
  final container = ProviderContainer(
    overrides: testOverrides(
      apiBaseUrl: 'https://comic.lazgram.com',
      thumbnailBuilder: (context, request, fit, {backdrop = false, onShown}) {
        requests.add(request);
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
}

void main() {
  testWidgets('API が返した相対 URL を絶対 URL にして取りに行く', (tester) async {
    await pumpThumbnail(tester, apiUrl: '/books/thumbnail/340?m=1');

    expect(
      requests.single.url.toString(),
      'https://comic.lazgram.com/books/thumbnail/340?m=1',
    );
  });

  testWidgets('キャッシュキーは ?m= の世代を含む（差し替え後に古い表紙を出さない）', (tester) async {
    await pumpThumbnail(tester, apiUrl: '/books/thumbnail/340?m=17');

    // 末尾の配信元は「開発ビルドで本番の画像を出さない」ための仕切り。
    expect(
      requests.single.cacheKey,
      't/books/thumbnail/340/17@https://comic.lazgram.com',
    );
    expect(requests.single.kind, CachedImageKind.thumbnail);
  });

  testWidgets('別ホスト（CDN 等）でもそのまま取りに行く（トークン付与は取得層が判断する）', (tester) async {
    await pumpThumbnail(tester, apiUrl: 'https://cdn.example.com/t/1.jpg');

    expect(requests.single.url.host, 'cdn.example.com');
  });

  testWidgets('サムネイル無し（null）は画像を取得しない', (tester) async {
    await pumpThumbnail(tester, apiUrl: null);

    expect(requests, isEmpty);
    expect(find.byType(ThumbnailPlaceholder), findsOneWidget);
  });

  group('既定の描画（背景用）', () {
    /// 本物の描画（`testOverrides` はスタブに差し替えるので別の口から呼ぶ）。
    /// 取得層は準備中 / 失敗のままにして、ネットワークを触らせない。
    final realBuilder = Provider<ThumbnailBuilder>(thumbnailBuilder);

    Future<void> pumpBuilt(
      WidgetTester tester, {
      required bool backdrop,
      bool loaderFails = false,
    }) async {
      final container = ProviderContainer(
        overrides: [
          ...testOverrides(apiBaseUrl: 'https://comic.lazgram.com'),
          comicImageLoaderProvider.overrideWith(
            (ref) => loaderFails
                ? Future.error(StateError('準備に失敗'))
                : Completer<ComicImageLoader>().future,
          ),
        ],
      );
      addTearDown(container.dispose);
      final request = ComicImageRequest.thumbnail(
        container.read(mediaUrlsProvider),
        '/books/thumbnail/340?m=1',
      )!;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => ref.watch(realBuilder)(
                context,
                request,
                BoxFit.cover,
                backdrop: backdrop,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('一覧では読み込み中に本のアイコンを出す', (tester) async {
      await pumpBuilt(tester, backdrop: false);

      expect(find.byType(ThumbnailPlaceholder), findsOneWidget);
    });

    testWidgets('背景では読み込み中に何も描かない（黒い下地に板を浮かせない）', (tester) async {
      await pumpBuilt(tester, backdrop: true);

      expect(find.byType(ThumbnailPlaceholder), findsNothing);
    });

    testWidgets('背景では失敗しても何も描かない（下の層を見せる）', (tester) async {
      await pumpBuilt(tester, backdrop: true, loaderFails: true);

      expect(find.byType(ThumbnailPlaceholder), findsNothing);
    });
  });
}
