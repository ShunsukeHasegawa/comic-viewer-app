import 'dart:collection';

/// 中身で等しさを比べる読み取り専用の Set。
///
/// Riverpod は `==` で変化を判断する。ふつうの `Set` は中身が同じでも別物
/// なので、元の状態が変わるたびに作り直す集合（ダウンロードの進捗ごとに
/// 作り直す「読める巻」など）を返すと、中身が変わっていなくても watch している
/// 画面を全部作り直させてしまう。
class ValueSet<E> extends UnmodifiableSetView<E> {
  ValueSet(Iterable<E> elements) : super(Set<E>.unmodifiable(elements));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValueSet<E> && length == other.length && containsAll(other);

  @override
  int get hashCode => Object.hashAllUnordered(this);
}
