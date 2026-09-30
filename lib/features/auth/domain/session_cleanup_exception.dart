/// 入れ直し直後の前のインストールの認証情報を片付けられず、新しいセッションを
/// 始められない（#15）。
///
/// iOS の Keychain はアプリを削除しても残る。入れ直しの目印（`InstallMarker`）を
/// 片付けないままログインを通すと、次の起動が目印を見て新しいトークンを消して
/// しまう（ログインが保たれない）。だからログインを止め、画面にエラーと再試行を出す。
///
/// 前のセッションのデータ（ダウンロード / 進捗など）を消し切れなかったときは
/// これを投げない。個人用アプリなのでログインは止めず、`SessionCleanupNotice`
/// で知らせるだけにする（`AuthController` の説明）。
///
/// `ApiException` の仲間にしないのは、通信の失敗ではなく端末側の失敗だから
/// （`isTransient` などの通信向けの判断に混ぜない）。
class SessionCleanupException implements Exception {
  const SessionCleanupException([
    this.message =
        '前回のログインのデータを端末から削除できませんでした。'
        'もう一度お試しください。続く場合はアプリを再起動してください。',
  ]);

  /// ユーザーに見せられる日本語メッセージ。
  final String message;

  @override
  String toString() => 'SessionCleanupException: $message';
}
