import 'package:comic_laz/core/utils/value_set.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('中身が同じなら並びに関わらず等しい', () {
    expect(ValueSet([1, 2, 3]), ValueSet([3, 2, 1]));
    expect(ValueSet([1, 2]).hashCode, ValueSet([2, 1]).hashCode);
    expect(ValueSet([1, 2]), isNot(ValueSet([1, 2, 3])));
    expect(ValueSet([1, 2]), isNot(ValueSet([1, 3])));
  });

  test('中身が変わらなければ watch している側に知らせない', () {
    // 進捗のたびに集合を作り直しても、画面を作り直させないための型。
    final source = NotifierProvider<_Ids, List<int>>(_Ids.new);
    final derived = Provider((ref) => ValueSet(ref.watch(source)));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var notified = 0;
    container.listen(derived, (_, _) => notified++);

    container.read(source.notifier).set([2, 1]);
    container.read(derived);
    expect(notified, 0);

    container.read(source.notifier).set([1, 2, 3]);
    container.read(derived);
    expect(notified, 1);
  });

  test('書き換えられない', () {
    expect(() => ValueSet([1]).add(2), throwsUnsupportedError);
  });
}

class _Ids extends Notifier<List<int>> {
  @override
  List<int> build() => [1, 2];

  void set(List<int> ids) => state = ids;
}
