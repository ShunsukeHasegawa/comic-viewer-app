import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'api_client.dart';

part 'device_token_api.g.dart';

/// プッシュ通知のデバイストークン（#14）。
///
/// サーバーは `device_tokens` に 1 端末 1 行で持つ（同じトークンを別のユーザーで
/// 登録し直すと持ち主が移る）。Bearer は `ApiClient` の Dio に載っている
/// インターセプタが API と同じオリジンにだけ付ける。
class DeviceTokenApi {
  const DeviceTokenApi(this._client);

  static const path = 'api/user/device-token';
  static const testPath = 'api/user/push-notification-test';

  /// サーバーが受け付ける `platform`（`DeviceToken::PLATFORMS`）。
  static const platformAndroid = 'android';
  static const platformIos = 'ios';

  /// サーバーの検証（`device_name` は 100 文字まで）。
  static const maxDeviceNameLength = 100;

  final ApiClient _client;

  /// 登録（`POST /api/user/device-token`）。同じトークンの再登録は上書き。
  ///
  /// 応答は JSON の文字列（`"Device token registered"`）で、中身は使わない。
  Future<void> register({
    required String token,
    required String platform,
    String? deviceName,
  }) async {
    final name = deviceName?.trim();
    await _client.send(
      path,
      method: 'POST',
      data: {
        'token': token,
        'platform': platform,
        if (name != null && name.isNotEmpty)
          'device_name': name.length <= maxDeviceNameLength
              ? name
              : name.substring(0, maxDeviceNameLength),
      },
      responseType: ResponseType.plain,
    );
  }

  /// 解除（`DELETE /api/user/device-token?token=`）。
  ///
  /// DELETE の本文を落とすクライアント / プロキシがあるので、サーバーが受ける
  /// クエリで渡す。サーバーはログイン中のユーザーの行だけを消す。
  Future<void> unregister(String token) async {
    await _client.send(
      path,
      method: 'DELETE',
      queryParameters: {'token': token},
      responseType: ResponseType.plain,
    );
  }

  /// テスト通知（`GET /api/user/push-notification-test`）。
  ///
  /// サーバーはこのユーザーの**全端末**へ送る。登録が無ければ何も送らずに 200。
  Future<void> sendTest() async {
    await _client.send(testPath, responseType: ResponseType.plain);
  }
}

@Riverpod(keepAlive: true)
DeviceTokenApi deviceTokenApi(Ref ref) =>
    DeviceTokenApi(ref.watch(apiClientProvider));
