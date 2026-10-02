import 'package:comic_laz/features/settings/application/theme_mode_setting.dart';
import 'package:comic_laz/features/settings/presentation/widgets/theme_mode_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/settings_fakes.dart';
import '../../support/test_scope.dart';

void main() {
  Future<ProviderContainer> pumpSelector(
    WidgetTester tester,
    InMemoryThemeModeStore store,
  ) async {
    final container = createContainer(themeModeStore: store);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ThemeModeSelector())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Set<ThemeMode> selected(WidgetTester tester) => tester
      .widget<SegmentedButton<ThemeMode>>(
        find.byKey(ThemeModeSelector.buttonKey),
      )
      .selected;

  testWidgets('保存済みのテーマが選ばれた状態で出る', (tester) async {
    await pumpSelector(tester, InMemoryThemeModeStore(ThemeMode.light));

    expect(selected(tester), {ThemeMode.light});
  });

  testWidgets('選ぶと保存してその場で切り替わる', (tester) async {
    final store = InMemoryThemeModeStore();
    final container = await pumpSelector(tester, store);
    expect(selected(tester), {ThemeMode.system});

    await tester.tap(find.text('ダーク'));
    await tester.pumpAndSettle();

    expect(store.writes, [ThemeMode.dark]);
    expect(container.read(themeModeSettingProvider).value, ThemeMode.dark);
    expect(selected(tester), {ThemeMode.dark});
  });

  testWidgets('保存に失敗したら選択を戻したまま SnackBar で知らせる（黙って次の起動で戻さない）', (tester) async {
    final store = InMemoryThemeModeStore()..writeError = StateError('disk');
    await pumpSelector(tester, store);

    await tester.tap(find.text('ダーク'));
    await tester.pumpAndSettle();

    expect(find.textContaining('テーマの設定の保存に失敗しました'), findsOneWidget);
    expect(selected(tester), {ThemeMode.system});
  });

  testWidgets('読み込めなかったときはそう出したうえで選び直せる（保存できればそれで直る）', (tester) async {
    final store = InMemoryThemeModeStore(ThemeMode.dark)
      ..readError = Exception('db');
    final container = await pumpSelector(tester, store);

    expect(find.textContaining('テーマの設定を読み込めませんでした'), findsOneWidget);
    // アプリが実際に使っている既定（システムに合わせる）を見せる。
    expect(selected(tester), {ThemeMode.system});

    await tester.tap(find.text('ライト'));
    await tester.pumpAndSettle();

    expect(store.writes, [ThemeMode.light]);
    expect(container.read(themeModeSettingProvider).value, ThemeMode.light);
    expect(find.textContaining('テーマの設定を読み込めませんでした'), findsNothing);
  });
}
