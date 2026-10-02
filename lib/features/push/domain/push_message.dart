import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/router/app_routes.dart';

/// 通知の許可。
enum PushPermission {
  granted,

  /// 断られた / OS の設定で切られている。
  denied,

  /// まだ聞いていない（iOS のみ。Android は許可されていなければ [denied]）。
  notDetermined,
}

/// 届いたプッシュ通知（FCM の `RemoteMessage` から必要なものだけ）。
@immutable
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;

  /// FCM の data ペイロード。値はすべて文字列（FCM の仕様）。
  final Map<String, String> data;

  /// 表示する中身があるか（data だけのメッセージは表示しない）。
  bool get hasNotification =>
      (title?.isNotEmpty ?? false) || (body?.isNotEmpty ?? false);
}

/// 通知を押したときの遷移先（#14）。
///
/// いまのサーバー（`PushNotificationService`）は notification だけを送り、
/// data を付けない。そのため既定はライブラリ。将来サーバーが data に
/// `book_id`（数値）か `book_ids`（カンマ区切り。1 件のときだけ）を載せたら、
/// そのタイトルの詳細を開く。複数タイトルの通知はどれを開くか決められないので
/// ライブラリにする（読めない値も同じ。通知を押して行き止まりにしない）。
String pushRouteFor(Map<String, String> data) {
  final single = _positiveInt(data['book_id']);
  if (single != null) return AppRoutes.bookDetail(single);
  final list = data['book_ids'];
  if (list != null) {
    final ids = [
      for (final part in list.split(','))
        if (part.trim().isNotEmpty) _positiveInt(part),
    ];
    if (ids.length == 1 && ids.single != null) {
      return AppRoutes.bookDetail(ids.single!);
    }
  }
  return AppRoutes.library;
}

int? _positiveInt(String? raw) {
  final value = raw == null ? null : int.tryParse(raw.trim());
  return value != null && value > 0 ? value : null;
}

/// フォアグラウンドで出した通知に持たせる payload（data の JSON）。
String encodePushPayload(Map<String, String> data) => jsonEncode(data);

/// [encodePushPayload] の逆。読めなければ空（= ライブラリへ）。
Map<String, String> decodePushPayload(String? payload) {
  if (payload == null || payload.isEmpty) return const {};
  try {
    final decoded = jsonDecode(payload);
    if (decoded is! Map) return const {};
    return {
      for (final MapEntry(:key, :value) in decoded.entries)
        if (value != null) '$key': '$value',
    };
  } on FormatException {
    return const {};
  }
}

/// FCM の data（値は dynamic として届く）を文字列の Map にそろえる。
Map<String, String> stringifyPushData(Map<String, dynamic> data) => {
  for (final MapEntry(:key, :value) in data.entries)
    if (value != null) key: '$value',
};
