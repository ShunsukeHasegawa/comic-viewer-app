/// ページ画像の先読み（Web 版 `useViewerPagePrefetch.ts` 相当）。
///
/// 現在ページの **前 1 / 後 3** ページを先読みし、範囲から外れたものは忘れる。
/// 自宅サーバー（HDD）に負荷をかけないよう、窓は小さく保つ。
class PagePrefetcher {
  PagePrefetcher({required this.precache, this.ahead = 3, this.behind = 1});

  /// 1 ページ分の先読み処理（画像のダウンロード + デコード）。
  final Future<void> Function(int page) precache;

  /// 進む方向に何ページ先まで読むか。
  final int ahead;

  /// 戻る方向に何ページ分残すか。
  final int behind;

  /// 先読み済み / 進行中のページ。
  final _requested = <int>{};

  Set<int> get requestedPages => Set.unmodifiable(_requested);

  /// 現在ページに合わせて先読みの窓を更新する。
  ///
  /// [pageCount] は実ページ数（巻末オーバーレイは含めない）。
  void update({required int currentPage, required int pageCount}) {
    if (pageCount <= 0) {
      _requested.clear();
      return;
    }

    final window = windowFor(currentPage: currentPage, pageCount: pageCount);

    // 窓の外は忘れる（再訪時に再度先読みする）。
    _requested.removeWhere((page) => !window.contains(page));

    for (final page in window) {
      if (_requested.add(page)) {
        // 失敗しても表示側が再取得するので、ここでは握る。
        precache(page).catchError((Object _) {});
      }
    }
  }

  /// すべて忘れる（巻を移動したときなど）。
  void reset() => _requested.clear();

  /// 先読み対象のページ（読む順に並べる: 現在 → 次 → … → 前）。
  List<int> windowFor({required int currentPage, required int pageCount}) {
    final pages = <int>[];

    void add(int page) {
      if (page >= 1 && page <= pageCount && !pages.contains(page)) {
        pages.add(page);
      }
    }

    // 巻末オーバーレイ（pageCount + 1）にいる場合は最終ページ基準で考える。
    final base = currentPage > pageCount ? pageCount : currentPage;

    add(base);
    for (var offset = 1; offset <= ahead; offset++) {
      add(base + offset);
    }
    for (var offset = 1; offset <= behind; offset++) {
      add(base - offset);
    }
    return pages;
  }
}
