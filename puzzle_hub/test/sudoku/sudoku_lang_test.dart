import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/sudoku/sudoku_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => I18n.lang.value = AppLang.en);

  for (final lang in AppLang.values) {
    testWidgets('Sudoku menu renders in ${lang.code}', (t) async {
      SharedPreferences.setMockInitialValues({});
      await Storage.init();
      I18n.lang.value = lang;
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(const MaterialApp(home: SudokuScreen()));
      await t.pump(const Duration(milliseconds: 800));
      expect(t.takeException(), isNull);
      expect(find.text(tr('sudoku.daily_puzzle')), findsOneWidget);
      expect(find.text(tr('common.tier.extreme')), findsWidgets);
      await t.pumpWidget(const SizedBox());
    });
  }
}
