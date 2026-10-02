import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/focus_color/logic/focus_common.dart';
import 'package:puzzle_hub/games/focus_color/logic/focus_difficulty.dart';
import 'package:puzzle_hub/games/focus_color/logic/odd_logic.dart';
import 'package:puzzle_hub/games/focus_color/logic/rule_logic.dart';
import 'package:puzzle_hub/games/focus_color/logic/stroop_logic.dart';

void main() {
  test('stroop rounds are valid for every tier', () {
    for (final tier in FocusTier.values) {
      final p = focusParams(FocusMode.stroop, tier);
      final g = StroopGenerator(Random(1), p);
      for (var i = 0; i < 300; i++) {
        final solved = i % 60;
        final r = g.next(solved);
        expect(r.word, isNot(r.ink));
        expect(r.options.contains(r.ink), isTrue);
        expect(r.options.toSet().length, r.options.length);
        expect(r.options.length, g.optionCount(solved));
        expect(r.options.length, lessThanOrEqualTo(p.stroopPool));
        expect(r.options.where(r.isCorrect).length, 1);
      }
    }
  });

  test('stroop tiers scale', () {
    int maxOpts(FocusTier t) => StroopGenerator.optionCountFor(focusParams(FocusMode.stroop, t), 999);
    expect(maxOpts(FocusTier.easy), lessThan(maxOpts(FocusTier.medium)));
    expect(maxOpts(FocusTier.medium), 6);
    expect(maxOpts(FocusTier.extreme), 8);
    expect(focusParams(FocusMode.stroop, FocusTier.extreme).stroopPool, 8);
    expect(focusParams(FocusMode.stroop, FocusTier.extreme).lives, 1);
    expect(focusParams(FocusMode.stroop, FocusTier.easy).seconds, greaterThan(focusParams(FocusMode.stroop, FocusTier.extreme).seconds));
  });

  test('odd one out scales', () {
    final m = focusParams(FocusMode.odd, FocusTier.medium);
    expect(OddGenerator.gridSizeFor(m, 0), 2);
    expect(OddGenerator.gridSizeFor(m, 100), 7);
    expect(OddGenerator.differenceFor(m, 10), lessThan(OddGenerator.differenceFor(m, 0)));
    expect(OddGenerator.differenceFor(m, 1000), greaterThanOrEqualTo(0.035));
    // Harder tiers: smaller shade difference, bigger grids, tighter time.
    double d(FocusTier t) => OddGenerator.differenceFor(focusParams(FocusMode.odd, t), 0);
    expect(d(FocusTier.easy), greaterThan(d(FocusTier.medium)));
    expect(d(FocusTier.medium), greaterThan(d(FocusTier.hard)));
    expect(d(FocusTier.hard), greaterThan(d(FocusTier.extreme)));
    expect(OddGenerator.gridSizeFor(focusParams(FocusMode.odd, FocusTier.extreme), 0), greaterThan(2));
    for (final tier in FocusTier.values) {
      final p = focusParams(FocusMode.odd, tier);
      final g = OddGenerator(Random(2), p);
      for (var s = 0; s < 100; s++) {
        final r = g.next(s);
        expect(r.oddIndex, inInclusiveRange(0, r.tiles - 1));
        expect(r.diff, greaterThan(0.01));
        expect(r.size, lessThanOrEqualTo(p.oddMaxGrid));
      }
    }
  });

  test('rule rounds are consistent and mix yes/no and rules in every tier', () {
    for (final tier in FocusTier.values) {
      final p = focusParams(FocusMode.rule, tier);
      final g = RuleGenerator(Random(3), p);
      var yes = 0, color = 0;
      const n = 600;
      for (var i = 0; i < n; i++) {
        final r = g.next(i % 30);
        final expected = r.rule == Rule.sameColor ? r.a.colorIndex == r.b.colorIndex : r.a.shape == r.b.shape;
        expect(r.answer, expected);
        expect(r.a.colorIndex, lessThan(p.ruleColors));
        expect(r.b.shape.index, lessThan(p.ruleShapes));
        if (r.answer) yes++;
        if (r.rule == Rule.sameColor) color++;
      }
      expect(yes, inInclusiveRange(n * 0.4, n * 0.6), reason: '$tier');
      expect(color, inInclusiveRange(n * 0.3, n * 0.7), reason: '$tier');
    }
  });

  test('rule flips more often on harder tiers', () {
    double f(FocusTier t) => RuleGenerator.flipChanceFor(focusParams(FocusMode.rule, t), 0);
    expect(f(FocusTier.easy), lessThan(f(FocusTier.medium)));
    expect(f(FocusTier.medium), lessThan(f(FocusTier.hard)));
    expect(f(FocusTier.hard), lessThan(f(FocusTier.extreme)));
  });

  test('combo, stars and keys', () {
    expect(comboMultiplier(0), 1);
    expect(comboMultiplier(5), 2);
    expect(comboMultiplier(99), 5);
    expect(pointsFor(10), 30);
    expect(starsFor(FocusMode.stroop, 0), 0);
    expect(starsFor(FocusMode.stroop, 400), 2);
    expect(starsFor(FocusMode.odd, 30), 3);
    expect(focusStars(FocusMode.stroop, FocusTier.medium, 400), 2);
    expect(focusStars(FocusMode.stroop, FocusTier.easy, 600), 3);
    expect(focusStars(FocusMode.stroop, FocusTier.extreme, 400), 1);
    expect(focusBestKey(FocusMode.odd, FocusTier.hard), 'focus.odd.hard.best');
    expect(FocusTier.fromName('extreme'), FocusTier.extreme);
    expect(FocusTier.fromName(null), FocusTier.medium);
  });
}
