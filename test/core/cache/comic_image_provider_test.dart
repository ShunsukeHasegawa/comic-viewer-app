import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:comic_laz/core/cache/comic_image_loader.dart';
import 'package:comic_laz/core/config/app_config.dart';
import 'package:comic_laz/core/media/media_urls.dart';
import 'package:comic_laz/core/network/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/cache_fakes.dart';
import '../../support/fake_http_adapter.dart';

/// 1x1 の PNG（デコードできる最小の画像）。
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// [load] の結果を外から決められるローダー（ネットワークは触らない）。
class _ScriptedLoader extends ComicImageLoader {
  _ScriptedLoader({
    required super.dio,
    required super.store,
    required this.onLoad,
  });

  final Future<Uint8List> Function() onLoad;

  @override
  Future<Uint8List> load(ComicImageRequest request) => onLoad();
}

/// 解決できた画像の幅を返す（[ui.Image] は listener の外で触らない）。
Future<int> resolveWidth(ComicImageProvider provider) {
  final completer = Completer<int>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info.image.width);
      stream.removeListener(listener);
    },
    onError: (error, _) {
      if (!completer.isCompleted) completer.completeError(error);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

/// 縦長（漫画のページ相当）の PNG を作る。
Future<Uint8List> _portraitPng({int width = 400, int height = 600}) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF336699),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final urls = MediaUrls(
    AppConfig.from(apiBaseUrl: 'http://localhost:8000', flavor: 'development'),
  );

  ComicImageRequest request() =>
      ComicImageRequest.page(urls, volumeId: 340, page: 1, filesVersion: 1);

  ComicImageLoader scripted(Future<Uint8List> Function() onLoad) =>
      _ScriptedLoader(
        dio: Dio(),
        store: CacheHarness.create().store,
        onLoad: onLoad,
      );

  setUp(() {
    // `ImageCache` はグローバルなのでテスト間で持ち越さない。
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  // 失敗した completer は `ImageCache` に pending のまま残る。追い出さないと、
  // ビューアの「再読み込み」も画面の開き直しも二度とネットワークを叩かず、
  // アプリを再起動するまで同じエラーが再生され続ける。
  test('一度失敗した画像は取り直せる（失敗を ImageCache に残さない）', () async {
    var attempts = 0;
    final loader = scripted(() async {
      attempts++;
      if (attempts == 1) throw const NetworkException();
      return _png;
    });

    await expectLater(
      resolveWidth(ComicImageProvider(loader: loader, request: request())),
      throwsA(isA<NetworkException>()),
    );

    // 「再読み込み」は同じキャッシュキーの provider を作り直すだけ。
    final width = await resolveWidth(
      ComicImageProvider(loader: loader, request: request()),
    );

    expect(attempts, 2, reason: '失敗が残っていると 2 回目の取得が起きない');
    expect(width, 1);
  });

  test('成功した画像はメモリに残す（同じキーで二度取りに行かない）', () async {
    var attempts = 0;
    final loader = scripted(() async {
      attempts++;
      return _png;
    });

    await resolveWidth(ComicImageProvider(loader: loader, request: request()));
    await resolveWidth(ComicImageProvider(loader: loader, request: request()));

    expect(attempts, 1, reason: '自宅サーバー（HDD）に同じ画像を取りに行かない');
  });

  // ログアウト（`ImageCachePurger`）はディスクとメモリの `ImageCache` を両方
  // 捨てる。その前に始まった取得の結果をデコードすると、捨てたばかりの
  // `ImageCache` に前のユーザー向けの画像が入り直し、次のユーザーに見える。
  test('取得中にログアウト（全削除）が入ったら、前の世代の画像を ImageCache に入れ直さない', () async {
    final gate = Completer<void>();
    final harness = CacheHarness.create();
    final loader = ComicImageLoader(
      dio: Dio()
        ..httpClientAdapter = FakeHttpAdapter((options) async {
          await gate.future;
          return ResponseBody.fromBytes(_png, 200);
        }),
      store: harness.store,
    );
    final provider = ComicImageProvider(loader: loader, request: request());

    final pending = resolveWidth(provider);
    await pumpEventQueue();
    await harness.store.clear();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    gate.complete();

    await expectLater(pending, throwsA(isA<RequestCancelledException>()));
    expect(PaintingBinding.instance.imageCache.containsKey(provider), isFalse);
  });

  group('表示する大きさでのデコード（#28）', () {
    late Uint8List portrait;

    setUpAll(() async => portrait = await _portraitPng());

    // BoxFit.cover で隙間が出ない最小の大きさ（縦横比は保つ）。
    test('枠を覆える最小の大きさまで縮める', () async {
      final loader = scripted(() async => portrait);

      final width = await resolveWidth(
        ComicImageProvider(
          loader: loader,
          request: request(),
          decodeBox: (width: 100, height: 100),
        ),
      );

      // 幅に合わせると高さ 150 で枠を覆える（高さに合わせた 67 では足りない）。
      expect(width, 100);
    });

    // 引き伸ばしても細部は増えず、メモリだけを食う。
    test('原寸より大きい枠では縮めも広げもしない', () async {
      final loader = scripted(() async => portrait);

      final width = await resolveWidth(
        ComicImageProvider(
          loader: loader,
          request: request(),
          decodeBox: (width: 1024, height: 1024),
        ),
      );

      expect(width, 400);
    });

    // 縮めた絵をビューアの原寸の代わりに出さない。
    test('大きさ違いは ImageCache の別の項目にする', () async {
      var attempts = 0;
      final loader = scripted(() async {
        attempts++;
        return portrait;
      });

      final small = await resolveWidth(
        ComicImageProvider(
          loader: loader,
          request: request(),
          decodeBox: (width: 100, height: 100),
        ),
      );
      final full = await resolveWidth(
        ComicImageProvider(loader: loader, request: request()),
      );

      expect((small, full), (100, 400));
      expect(attempts, 2);
    });

    // 失敗時の追い出しが大きさ違いの項目に向くと、その大きさの画像だけ
    // 二度と取り直せなくなる。
    test('大きさを指定した画像も、一度失敗したら取り直せる', () async {
      var attempts = 0;
      final loader = scripted(() async {
        attempts++;
        if (attempts == 1) throw const NetworkException();
        return portrait;
      });
      ComicImageProvider provider() => ComicImageProvider(
        loader: loader,
        request: request(),
        decodeBox: (width: 100, height: 100),
      );

      await expectLater(
        resolveWidth(provider()),
        throwsA(isA<NetworkException>()),
      );
      final width = await resolveWidth(provider());

      expect(attempts, 2);
      expect(width, 100);
    });

    test('coverTargetSize は片方の辺だけ決めて縦横比をエンジンに保たせる', () {
      final size = ComicImageProvider.coverTargetSize(
        intrinsicWidth: 1200,
        intrinsicHeight: 1800,
        box: (width: 384, height: 512),
      );

      // 幅 384 なら高さ 576 で枠を覆える。高さ 512 に合わせると幅 342 で足りない。
      expect((size.width, size.height), (384, null));
    });
  });
}
