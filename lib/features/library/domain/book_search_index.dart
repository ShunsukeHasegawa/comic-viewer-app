import '../../../domain/models/book.dart';

/// 日本語の部分一致検索（Web 版 `useBookSearch.ts` の MiniSearch bi-gram 相当）。
///
/// タイトル・かな・著者名を対象に、**2 文字単位（bi-gram）の転置インデックス**で
/// 候補を絞り、最後に部分一致で検証する。形態素解析なしでも
/// 「きょじん」「進撃」のような途中一致が引けるのがねらい。
///
/// 蔵書規模（数千冊）ならメモリ上で十分間に合う。
class BookSearchIndex {
  BookSearchIndex._(this._books, this._haystacks, this._bigrams);

  /// 一覧から索引を作る。
  factory BookSearchIndex.build(List<Book> books) {
    final haystacks = <String>[];
    final bigrams = <String, Set<int>>{};

    for (var index = 0; index < books.length; index++) {
      final book = books[index];
      final haystack = normalize(
        [book.title, book.kana ?? '', ...book.author].join(' '),
      );
      haystacks.add(haystack);

      for (final bigram in _bigramsOf(haystack)) {
        (bigrams[bigram] ??= <int>{}).add(index);
      }
    }

    return BookSearchIndex._(books, haystacks, bigrams);
  }

  final List<Book> _books;

  /// 書籍ごとの正規化済み検索対象文字列。
  final List<String> _haystacks;

  final Map<String, Set<int>> _bigrams;

  /// 検索する。空のクエリでは全件を返す。
  List<Book> search(String query) {
    final normalized = normalize(query);
    if (normalized.isEmpty) return _books;

    // 1 文字のクエリは bi-gram が作れないので総当たりする。
    if (normalized.length == 1) {
      return [
        for (var index = 0; index < _books.length; index++)
          if (_haystacks[index].contains(normalized)) _books[index],
      ];
    }

    final candidates = _candidateIndices(normalized);
    if (candidates == null) return const [];

    // bi-gram は順序を保証しないので、最後に部分一致で確認する。
    final matched = [
      for (final index in candidates)
        if (_haystacks[index].contains(normalized)) index,
    ]..sort();
    return [for (final index in matched) _books[index]];
  }

  /// すべての bi-gram を含む書籍の添字（1 つでも欠ければ該当なし）。
  Set<int>? _candidateIndices(String normalized) {
    Set<int>? candidates;
    for (final bigram in _bigramsOf(normalized)) {
      final hits = _bigrams[bigram];
      if (hits == null) return null;
      candidates = candidates == null
          ? Set<int>.of(hits)
          : (candidates..retainWhere(hits.contains));
      if (candidates.isEmpty) return null;
    }
    return candidates;
  }

  static Iterable<String> _bigramsOf(String value) sync* {
    for (var i = 0; i + 1 < value.length; i++) {
      yield value.substring(i, i + 2);
    }
  }

  /// 検索用の正規化。
  ///
  /// - 前後の空白を落とし、連続する空白を 1 つにする
  /// - 英数字は小文字・半角に揃える
  /// - **カタカナはひらがなに揃える**（「シンゲキ」でも「しんげき」で引けるように）
  /// - 濁点・半濁点を含む合成文字はそのまま扱う
  static String normalize(String value) {
    final buffer = StringBuffer();
    for (final rune in value.trim().toLowerCase().runes) {
      buffer.writeCharCode(_normalizeRune(rune));
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  static int _normalizeRune(int rune) {
    // 全角英数字・記号（！ - ～）を半角へ
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      final halfWidth = rune - 0xFEE0;
      // 半角にしてから小文字化する（Ａ → a）
      return halfWidth >= 0x41 && halfWidth <= 0x5A
          ? halfWidth + 0x20
          : halfWidth;
    }
    // 全角スペース
    if (rune == 0x3000) return 0x20;
    // カタカナ（ァ-ヶ）をひらがなへ
    if (rune >= 0x30A1 && rune <= 0x30F6) return rune - 0x60;
    return rune;
  }
}
