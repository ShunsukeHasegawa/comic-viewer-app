import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_cleanup_notice.g.dart';

/// ログイン時に前回のデータを消し切れなかったことを画面へ知らせる合図（#15）。
///
/// 個人用アプリなので、消し残しがあってもログインは止めない（`AuthController`
/// の説明）。その代わり黙って通さず、`ComicLazApp` が SnackBar で 1 回知らせる。
/// state は知らせるべき回数の通し番号（増えたときだけ表示する）。
@Riverpod(keepAlive: true)
class SessionCleanupNotice extends _$SessionCleanupNotice {
  /// 画面に出す文言。
  static const message = '前回のデータの一部を削除できませんでした';

  @override
  int build() => 0;

  /// 消し残しを 1 件知らせる。
  void report() => state++;
}
