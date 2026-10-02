/// ページ画像の先読み（Web 版 `useViewerPagePrefetch.ts` 相当）。
///
/// 現在ページの **前 1 / 後 3** ページを先読みし、範囲から外れたものは忘れる。
/// 自宅サーバー（HDD）に負荷をかけないよう、窓は小さく保つ。
///
/// **表示中のページを取り切ってから周辺へ広げる**（#18）。窓の 5 枚を同時に
/// 投げると、スライダーで遠くへ飛んだ直後に飛び先のページが周辺ページと HDD の
/// シークを奪い合い、表示が遅れる（Web 版は周辺を `fetchPriority = 'low'` で
/// 投げて同じことをしている）。周辺を待たせている間に窓が動いたら、古い窓の
/// 残りは投げない（新しい窓が自分の分を投げる）。
class PagePrefetcher {
  PagePrefetcher({required this.precache, this.ahead = 3, this.behind = 1});

  /// 1 ページ分の先読み処理（画像のダウンロード + デコード）。
  final Future<void> Function(int page) precache;

  /// 進む方向に何ページ先まで読むか。
  final int ahead;

  /// 戻る方向に何ページ分残すか。
  final int behind;

  /// 表示中のページを待つ上限（これを過ぎたら周辺の先読みを始める）。
  static const visibleWait = Duration(seconds: 2);

  /// 先読み済み / 進行中のページと、その完了（失敗も完了として扱う）。
  final _requested = <int, Future<void>>{};

  /// 窓の世代。窓が動くたびに上がり、古い窓の「後で投げる分」を捨てる目印。
  int _generation = 0;

  /// 前回の窓の条件（同じ条件での呼び直しで世代を上げないため）。
  ///
  /// 画面は再描画のたびに [update] を呼ぶ。そのたびに世代を上げると、
  /// メニューの開閉だけで「表示中のページの完了待ち」が捨てられ、周辺の先読みが
  /// 投げられないままになる。
  ({int currentPage, int pageCount})? _last;

  Set<int> get requestedPages => Set.unmodifiable(_requested.keys);

  /// 現在ページに合わせて先読みの窓を更新する。
  ///
  /// [pageCount] は実ページ数（巻末オーバーレイは含めない）。
  void update({required int currentPage, required int pageCount}) {
    if (pageCount <= 0) {
      reset();
      return;
    }

    final key = (currentPage: currentPage, pageCount: pageCount);
    if (key == _last) return;
    _last = key;
    final generation = ++_generation;

    final window = windowFor(currentPage: currentPage, pageCount: pageCount);

    // 窓の外は忘れる（再訪時に再度先読みする）。
    _requested.removeWhere((page, _) => !window.contains(page));

    final first = window.first;
    final visible = _requested[first] ?? _request(first);
    final rest = window.skip(1).toList();
    if (rest.isEmpty) return;

    // 表示中のページが遅い（混んだ回線 / 60 秒の時間切れ待ち）ときに周辺の
    // 先読みまで止めない。一定時間で見切って周辺を投げ始める。
    visible.timeout(visibleWait, onTimeout: () {}).then((_) {
      // 待っている間に窓が動いた。古い窓の周辺を今さら投げると、新しい
      // 飛び先の読み込みと競合する。
      if (generation != _generation) return;
      for (final page in rest) {
        if (!_requested.containsKey(page)) _request(page);
      }
    });
  }

  Future<void> _request(int page) {
    // 失敗しても表示側が再取得するので、ここでは握る（周辺の先読みは続ける）。
    final task = Future.sync(() => precache(page)).catchError((Object _) {});
    _requested[page] = task;
    return task;
  }

  /// すべて忘れる（巻を移動したときなど）。待たせている周辺の先読みも捨てる。
  void reset() {
    _requested.clear();
    _last = null;
    _generation++;
  }

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
