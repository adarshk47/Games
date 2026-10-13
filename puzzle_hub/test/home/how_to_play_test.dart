import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/core/ui/game_scaffold.dart';
import 'package:puzzle_hub/core/ui/how_to_play.dart';
import 'package:puzzle_hub/games/registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every game has rules in all 9 languages', () {
    for (final g in games) {
      for (final lang in AppLang.values) {
        I18n.lang.value = lang;
        final s = tr('howto.${g.id}');
        expect(s, isNot('howto.${g.id}'), reason: '${g.id} ${lang.code}');
        expect(s.split('\n').length, greaterThanOrEqualTo(3), reason: '${g.id} ${lang.code}');
      }
    }
    I18n.lang.value = AppLang.en;
  });

  testWidgets('a game screen shows the ? button and opens the rules', (t) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    final g = games.firstWhere((x) => x.id == 'sudoku');
    HowToPlay.current = g;
    addTearDown(() => HowToPlay.current = null);
    await t.pumpWidget(const MaterialApp(home: GameScaffold(title: 'Sudoku', body: SizedBox())));
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.byKey(const ValueKey('howto_btn')));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('How to play Sudoku'), findsOneWidget);
    expect(find.textContaining('3×3'), findsOneWidget);
    await t.tap(find.text('Got it!'));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('How to play Sudoku'), findsNothing);
  });

  testWidgets('no ? button outside a game', (t) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    await t.pumpWidget(const MaterialApp(home: GameScaffold(title: 'Daily', body: SizedBox())));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('howto_btn')), findsNothing);
  });
}
