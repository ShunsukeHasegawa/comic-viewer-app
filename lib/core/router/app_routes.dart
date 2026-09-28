/// アプリ内のルート定義（Web 版の URL 体系に合わせる）。
abstract final class AppRoutes {
  /// ライブラリ（ホーム）。
  static const library = '/';

  /// ログイン。
  static const login = '/login';

  /// 読書履歴。
  static const history = '/history';

  /// マイページ。
  static const myPage = '/mypage';

  /// タイトル詳細のパスパターン。
  static const bookDetailPattern = '/book/:bookId';

  /// ビューアのパスパターン。`bookDetailPattern` より先に評価させる。
  static const viewerPattern = '/book/view/:volumeId';

  /// パスパラメータ名。
  static const bookIdParam = 'bookId';
  static const volumeIdParam = 'volumeId';

  /// タイトル詳細の URL。
  static String bookDetail(int bookId) => '/book/$bookId';

  /// ビューアの URL。
  static String viewer(int volumeId) => '/book/view/$volumeId';
}
