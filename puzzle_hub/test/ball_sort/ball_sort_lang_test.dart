import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/ball_sort/ball_sort_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => I18n.lang.value = AppLang.en);

  Future<void> open(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(const MaterialApp(home: BallSortScreen()));
    await t.pump(const Duration(milliseconds: 800));
  }

  testWidgets('Ball Sort difficulty screen shows English texts', (t) async {
    await open(t);
    for (final s in ['Ball Sort', 'Choose difficulty', 'Easy', 'Extreme', '3-5 colors']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    await t.pumpWidget(const SizedBox());
  });

  for (final lang in AppLang.values) {
    testWidgets('Ball Sort renders in ${lang.code}', (t) async {
      I18n.lang.value = lang;
      await open(t);
      expect(t.takeException(), isNull);
      expect(find.text(tr('ball_sort.choose')), findsOneWidget);
      // Level grid too.
      await t.tap(find.text(tr('common.tier.easy')).first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));
      expect(t.takeException(), isNull);
      expect(find.text(tr('ball_sort.play_level', {'n': 1})), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  }
}
