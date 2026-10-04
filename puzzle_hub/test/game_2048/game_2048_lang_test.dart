import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/game_2048/game_2048_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => I18n.lang.value = AppLang.en);

  testWidgets('2048 shows English texts', (t) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(const MaterialApp(home: Game2048Screen()));
    await t.pump(const Duration(milliseconds: 800));
    for (final s in ['SCORE', 'BEST', 'Classic 2048', 'Easy', 'Medium', 'Hard', 'Extreme']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(find.text('Swipe to merge tiles. Reach 2048!'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  for (final lang in AppLang.values) {
    testWidgets('2048 renders in ${lang.code}', (t) async {
      SharedPreferences.setMockInitialValues({});
      await Storage.init();
      I18n.lang.value = lang;
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(const MaterialApp(home: Game2048Screen()));
      await t.pump(const Duration(milliseconds: 800));
      expect(t.takeException(), isNull);
      expect(find.text(tr('game_2048.classic')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  }
}
