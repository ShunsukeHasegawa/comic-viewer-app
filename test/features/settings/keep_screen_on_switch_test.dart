import 'package:comic_laz/features/settings/application/keep_screen_on_setting.dart';
import 'package:comic_laz/features/settings/presentation/widgets/keep_screen_on_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/settings_fakes.dart';
import '../../support/test_scope.dart';

void main() {
  Future<ProviderContainer> pumpSwitch(
    WidgetTester tester,
    InMemoryKeepScreenOnStore store,
  ) async {
    final container = createContainer(keepScreenOnStore: store);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: KeepScreenOnSwitch())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  bool switchValue(WidgetTester tester) => tester
      .widget<SwitchListTile>(find.byKey(KeepScreenOnSwitch.switchKey))
      .value;

  testWidgets('保存済みの値で出る', (tester) async {
    await pumpSwitch(tester, InMemoryKeepScreenOnStore(false));

    expect(switchValue(tester), isFalse);
    // ほかの画面の消灯は変えないことが分かるように書いておく。
    expect(find.textContaining('ビューアで読んでいる間だけ'), findsOneWidget);
  });

  testWidgets('押すと保存してその場で切り替わる', (tester) async {
    final store = InMemoryKeepScreenOnStore();
    final container = await pumpSwitch(tester, store);
    expect(switchValue(tester), isTrue);

    await tester.tap(find.byKey(KeepScreenOnSwitch.switchKey));
    await tester.pumpAndSettle();

    expect(store.writes, [false]);
    expect(container.read(keepScreenOnSettingProvider).value, isFalse);
    expect(switchValue(tester), isFalse);
  });

  testWidgets('保存に失敗したら元の値のまま SnackBar で知らせる（黙って次の起動で戻さない）', (tester) async {
    final store = InMemoryKeepScreenOnStore()..writeError = StateError('disk');
    await pumpSwitch(tester, store);

    await tester.tap(find.byKey(KeepScreenOnSwitch.switchKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('画面の消灯の設定の保存に失敗しました'), findsOneWidget);
    expect(switchValue(tester), isTrue);
  });

  testWidgets('読み込めなかったときは ON（実際の挙動）を見せたうえで切り替えられる', (tester) async {
    final store = InMemoryKeepScreenOnStore(false)..readError = Exception('db');
    final container = await pumpSwitch(tester, store);

    expect(find.textContaining('設定を読み込めませんでした'), findsOneWidget);
    expect(switchValue(tester), isTrue);

    await tester.tap(find.byKey(KeepScreenOnSwitch.switchKey));
    await tester.pumpAndSettle();

    expect(store.writes, [false]);
    expect(container.read(keepScreenOnSettingProvider).value, isFalse);
    expect(find.textContaining('設定を読み込めませんでした'), findsNothing);
  });
}
