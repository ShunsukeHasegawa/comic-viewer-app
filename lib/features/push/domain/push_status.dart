import 'package:freezed_annotation/freezed_annotation.dart';

import 'push_message.dart';

part 'push_status.freezed.dart';

/// プッシュ通知がこのビルド / 端末で使えるか。
enum PushAvailability {
  /// Firebase の初期化中。
  checking,

  available,

  /// Firebase の設定が無いビルド（`google-services.json` を置かずに作った版、
  /// 開発版を Firebase に登録していないなど）。
  unavailable,
}

/// 設定画面に出すプッシュ通知の状態（#14）。
@freezed
abstract class PushStatus with _$PushStatus {
  const factory PushStatus({
    @Default(PushAvailability.checking) PushAvailability availability,

    /// 「新刊通知」の設定。読み込むまでは `null`。
    bool? enabled,

    /// 通知の許可。まだ確かめていなければ `null`。
    PushPermission? permission,

    /// このセッションでサーバーへの登録を確かめたか（登録した / 控えと一致した）。
    @Default(false) bool registered,

    /// 直近の登録の失敗（画面に出す文言）。成功したら消える。
    String? failure,
  }) = _PushStatus;
}
