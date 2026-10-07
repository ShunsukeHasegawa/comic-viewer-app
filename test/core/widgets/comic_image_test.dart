import 'dart:async';
import 'dart:typed_data';

import 'package:comic_laz/core/cache/comic_image_loader.dart';
import 'package:comic_laz/core/media/media_urls.dart';
import 'package:comic_laz/core/widgets/comic_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/cache_fakes.dart';
import '../../support/test_scope.dart';

/// 取得が終わらないローダー（デコードの大きさの指定だけを見る。ネットワークは触らない）。
class _PendingLoader extends ComicImageLoader {
  _PendingLoader({required super.dio, required super.store});

  @override
  Future<Uint8List> load(ComicImageRequest request) =>
      Completer<Uint8List>().future;
}

void main() {
  group('decodeBoxFor', () {
    // 少しの大きさの違い（列数の切り替え・回転など）で別の画像として
    // 読み直さないよう、物理ピクセルを刻み幅に切り上げる。
    test('レイアウトの大きさ × devicePixelRatio を刻み幅に切り上げる', () {
      final box = ComicImage.decodeBoxFor(
        BoxConstraints.tight(const Size(100, 150)),
        3,
      );

      expect(box, (width: 384, height: 512));
    });

    test('大きさが決まらない（無限 / 0）ときは原寸のままにする', () {
      expect(ComicImage.decodeBoxFor(const BoxConstraints(), 3), isNull);
      expect(
        ComicImage.decodeBoxFor(BoxConstraints.tight(Size.zero), 3),
        isNull,
      );
    });
  });

  group('ComicImage', () {
    late ProviderContainer container;
    late ComicImageRequest request;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          ...testOverrides(apiBaseUrl: 'https://comic.lazgram.com'),
          comicImageLoaderProvider.overrideWith(
            (ref) async =>
                _PendingLoader(dio: Dio(), store: CacheHarness.create().store),
          ),
        ],
      );
      addTearDown(container.dispose);
      request = ComicImageRequest.thumbnail(
        container.read(mediaUrlsProvider),
        '/books/thumbnail/340?m=1',
      )!;
    });

    Future<void> pumpSized(
      WidgetTester tester,
      Size size, {
      required bool decodeToLayout,
    }) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Center(
            child: SizedBox.fromSize(
              size: size,
              child: ComicImage(
                request: request,
                decodeToLayout: decodeToLayout,
                loadingBuilder: (context) => const SizedBox.expand(),
                errorBuilder: (context, _) => const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    ({int width, int height})? decodeBox(WidgetTester tester) =>
        (tester.widget<Image>(find.byType(Image)).image as ComicImageProvider)
            .decodeBox;

    // 原寸のサムネイル / 背景を ImageCache に載せると、ビューアの先読みした
    // ページが押し出されて読み直しになる（#28）。
    testWidgets('一覧 / 背景用は表示する大きさでデコードする', (tester) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await pumpSized(tester, const Size(100, 150), decodeToLayout: true);

      expect(decodeBox(tester), (width: 384, height: 512));
    });

    // ビューアのページは拡大に耐える解像度が要る。
    testWidgets('指定しなければ原寸でデコードする（ビューアのページ）', (tester) async {
      await pumpSized(tester, const Size(100, 150), decodeToLayout: false);

      expect(decodeBox(tester), isNull);
    });

    // 枠が変わると別の画像として読み直し、読み込み中の表示に戻る。縮んだときに
    // 読み直してもちらつくだけで、メモリの節約もわずか。
    testWidgets('同じ画像の間はデコードの大きさを縮めない（読み直してちらつかせない）', (tester) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await pumpSized(tester, const Size(100, 150), decodeToLayout: true);
      await pumpSized(tester, const Size(40, 60), decodeToLayout: true);
      expect(decodeBox(tester), (width: 384, height: 512));

      // 大きくなったら細部が足りなくなるので読み直す。
      await pumpSized(tester, const Size(200, 150), decodeToLayout: true);
      expect(decodeBox(tester), (width: 640, height: 512));
    });
  });
}
