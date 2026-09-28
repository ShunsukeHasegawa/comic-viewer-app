import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:comic_laz/core/cache/comic_image_loader.dart';
import 'package:comic_laz/core/config/app_config.dart';
import 'package:comic_laz/core/media/media_urls.dart';
import 'package:comic_laz/core/network/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/cache_fakes.dart';

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
}
