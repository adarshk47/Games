import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/focus_color/logic/focus_common.dart';
import 'package:puzzle_hub/games/focus_color/logic/odd_logic.dart';
import 'package:puzzle_hub/games/focus_color/logic/rule_logic.dart';
import 'package:puzzle_hub/games/focus_color/logic/stroop_logic.dart';

void main() {
  test('stroop rounds are valid', () {
    final g = StroopGenerator(Random(1));
    for (var i = 0; i < 500; i++) {
      final r = g.next(i % 40);
      expect(r.word, isNot(r.ink));
      expect(r.options.contains(r.ink), isTrue);
      expect(r.options.toSet().length, r.options.length);
      expect(r.options.length, StroopGenerator.optionCount(i % 40));
      expect(r.options.where(r.isCorrect).length, 1);
    }
  });

  test('odd one out scales', () {
    expect(OddGenerator.gridSize(0), 2);
    expect(OddGenerator.gridSize(100), 7);
    expect(OddGenerator.difference(10), lessThan(OddGenerator.difference(0)));
    expect(OddGenerator.difference(1000), greaterThanOrEqualTo(0.035));
    final g = OddGenerator(Random(2));
    for (var s = 0; s < 100; s++) {
      final r = g.next(s);
      expect(r.oddIndex, inInclusiveRange(0, r.tiles - 1));
      expect(r.diff, greaterThan(0.01));
    }
  });

  test('rule rounds have consistent answers and mix yes/no and rules', () {
    final g = RuleGenerator(Random(3));
    var yes = 0, color = 0;
    const n = 600;
    for (var i = 0; i < n; i++) {
      final r = g.next(i % 30);
      final expected = r.rule == Rule.sameColor ? r.a.colorIndex == r.b.colorIndex : r.a.shape == r.b.shape;
      expect(r.answer, expected);
      if (r.answer) yes++;
      if (r.rule == Rule.sameColor) color++;
    }
    expect(yes, inInclusiveRange(n * 0.4, n * 0.6));
    expect(color, inInclusiveRange(n * 0.3, n * 0.7));
  });

  test('combo and stars', () {
    expect(comboMultiplier(0), 1);
    expect(comboMultiplier(5), 2);
    expect(comboMultiplier(99), 5);
    expect(pointsFor(10), 30);
    expect(starsFor(FocusMode.stroop, 0), 0);
    expect(starsFor(FocusMode.stroop, 400), 2);
    expect(starsFor(FocusMode.odd, 30), 3);
  });
}
