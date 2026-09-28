import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_config.dart';

part 'dio_provider.g.dart';

/// Web 版 `utils/api.ts` と同じタイムアウト（8 秒）。
const apiTimeout = Duration(seconds: 8);

/// JSON API を叩くリクエストに付けるヘッダ。
///
/// 画像 / アーカイブ取得も同じ [Dio] を通す（#3 の Bearer 付与を共有するため）ので、
/// `Accept: application/json` は [BaseOptions] ではなくリクエスト単位で付ける。
/// 画像リクエストに JSON だけを advertise すると、コンテントネゴシエーションする
/// サーバーから 406 が返りうる。
const jsonAcceptHeaders = <String, String>{
  Headers.acceptHeader: Headers.jsonContentType,
};

/// アプリ共通の [Dio]。
///
/// 認証ヘッダの付与（#3）・ETag 条件付き GET やリトライ（#4）は
/// それぞれの Issue でインターセプタとして足す。
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      // dio は `baseUrl + path` の単純連結（スキーム以降の `//` だけ畳む）なので、
      // 末尾スラッシュを付けておくと path の先頭スラッシュの有無に依らず正しい URL になる。
      baseUrl: '${config.apiBaseUrlString}/',
      connectTimeout: apiTimeout,
      receiveTimeout: apiTimeout,
      sendTimeout: apiTimeout,
    ),
  );
  ref.onDispose(() => dio.close());
  return dio;
}
