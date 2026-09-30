/// 端末内に残った前のセッションを片付けられず、新しいセッションを始められない（#15）。
///
/// 片付け（破棄の印のやり直し / ユーザー切り替えの破棄 / 入れ直し直後の
/// 認証情報の削除）に失敗したままログインを通すと、前のユーザーの未送信の
/// 進捗が新しいユーザーのトークンでサーバーへ送られ（取り消せない）、
/// ダウンロード済みの巻も新しいユーザーに見えてしまう。だからログインを止め、
/// 画面にエラーと再試行を出す。
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
