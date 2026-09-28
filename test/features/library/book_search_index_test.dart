import 'package:comic_laz/features/library/domain/book_search_index.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/api_fakes.dart';

void main() {
  final books = [
    testBook(id: 1, title: '進撃の巨人', kana: 'しんげきのきょじん', author: ['諫山創']),
    testBook(id: 2, title: 'ONE PIECE', kana: 'わんぴーす', author: ['尾田栄一郎']),
    testBook(id: 3, title: '鬼滅の刃', kana: 'きめつのやいば', author: ['吾峠呼世晴']),
  ];
  final index = BookSearchIndex.build(books);

  List<int> idsFor(String query) =>
      index.search(query).map((b) => b.id).toList();

  test('空のクエリは全件', () {
    expect(index.search(''), books);
    expect(index.search('   '), books);
  });

  test('タイトルの途中一致で引ける（bi-gram）', () {
    expect(idsFor('巨人'), [1]);
    expect(idsFor('の刃'), [3]);
  });

  test('かなでも引ける', () {
    expect(idsFor('きょじん'), [1]);
    expect(idsFor('きめつ'), [3]);
  });

  test('カタカナとひらがなを区別しない', () {
    expect(idsFor('ワンピース'), [2]);
    expect(idsFor('わんぴーす'), [2]);
  });

  test('英数字は大文字小文字・全角半角を区別しない', () {
    expect(idsFor('one piece'), [2]);
    expect(idsFor('ＯＮＥ'), [2]);
  });

  test('著者名で引ける', () {
    expect(idsFor('諫山'), [1]);
    expect(idsFor('尾田栄一郎'), [2]);
  });

  test('1 文字のクエリも引ける（bi-gram が作れない）', () {
    expect(idsFor('刃'), [3]);
  });

  test('一致しなければ空', () {
    expect(idsFor('存在しない作品'), isEmpty);
    expect(idsFor('zzz'), isEmpty);
  });

  test('bi-gram が揃っていても順序が違えば除外する', () {
    final index = BookSearchIndex.build([testBook(id: 1, title: 'あいうえお')]);

    expect(index.search('あい'), hasLength(1));
    // 「うえ」「えあ」…の組み合わせでは一致しない
    expect(index.search('えあ'), isEmpty);
    expect(index.search('おあ'), isEmpty);
  });

  test('結果は元の並び順を保つ（並び替えは呼び出し側の責務）', () {
    final index = BookSearchIndex.build([
      testBook(id: 10, title: 'まんがA'),
      testBook(id: 11, title: 'まんがB'),
      testBook(id: 12, title: 'まんがC'),
    ]);

    expect(index.search('まんが').map((b) => b.id), [10, 11, 12]);
  });

  group('normalize', () {
    test('前後と連続する空白をまとめる', () {
      expect(BookSearchIndex.normalize('  a   b  '), 'a b');
      expect(BookSearchIndex.normalize('a　b'), 'a b', reason: '全角スペース');
    });

    test('カタカナをひらがなに、全角英数を半角小文字にする', () {
      expect(BookSearchIndex.normalize('アイウ'), 'あいう');
      expect(BookSearchIndex.normalize('ＡＢ１'), 'ab1');
    });

    test('長音・濁点はそのまま残す', () {
      expect(BookSearchIndex.normalize('ガーデン'), 'がーでん');
    });
  });
}
