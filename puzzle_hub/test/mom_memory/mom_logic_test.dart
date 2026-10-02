import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/mom_memory/logic/mom_logic.dart';

void main() {
  test('match levels have even cells and enough emoji', () {
    for (final l in matchLevels) {
      expect(l.rows * l.cols % 2, 0);
      expect(l.pairs <= babyEmojis.length, isTrue);
    }
  });
  test('match deck pairs', () {
    final d = generateMatchDeck(10, Random(2));
    expect(d.length, 20);
    for (final i in d.toSet()) {
      expect(d.where((x) => x == i).length, 2);
    }
  });
  test('match stars', () {
    expect(matchStars(6, 6), 3);
    expect(matchStars(12, 6), 2);
    expect(matchStars(40, 6), 1);
  });
  test('bag levels grow and rounds are valid', () {
    var prev = 0;
    for (var l = 0; l < 7; l++) {
      final lv = bagLevel(l);
      expect(lv.count >= prev, isTrue);
      prev = lv.count;
      final r = buildBagRound(lv, Random(l));
      expect(r.shown.toSet().length, lv.count);
      expect(r.options.toSet().length, r.options.length);
      expect(r.options.toSet().containsAll(r.shown), isTrue);
      expect(lv.options <= bagItems.length, isTrue);
    }
    expect(bagLevel(0).count, 4);
    expect(bagLevel(99).count, 10);
  });
  test('bag scoring', () {
    final s = scoreBag([1, 2, 9], [1, 2, 3]);
    expect(s.correct, 2);
    expect(s.wrong, 1);
    expect(bagStars(4, 4), 3);
    expect(bagStars(0, 4), 1);
  });
  test('lullaby', () {
    final rng = Random(3);
    var s = <int>[];
    for (var i = 0; i < 20; i++) {
      s = extendPattern(s, rng);
    }
    expect(s.length, 20);
    for (var i = 1; i < s.length; i++) {
      expect(s[i], isNot(s[i - 1]));
    }
    expect(checkTap([1, 2], 0, 1), TapResult.right);
    expect(checkTap([1, 2], 1, 2), TapResult.complete);
    expect(checkTap([1, 2], 1, 3), TapResult.wrong);
  });
  test('breathing phases', () {
    expect(breathAt(0).phase, BreathPhase.inhale);
    expect(breathAt(5).phase, BreathPhase.hold);
    expect(breathAt(9).phase, BreathPhase.exhale);
    expect(breathAt(14).phase, BreathPhase.inhale);
    expect(breathScale(4), 1);
    expect(breathScale(2), closeTo(0.5, 1e-9));
    expect(breathScale(11), closeTo(0.5, 1e-9));
  });
  test('color options', () {
    final o = colorOptions(2, Random(1));
    expect(o.length, 3);
    expect(o.toSet().length, 3);
    expect(o.contains(2), isTrue);
  });
  test('streak', () {
    final d = DateTime(2026, 3, 1);
    expect(nextStreak(null, 0, d), 1);
    expect(nextStreak('2026-03-01', 4, d), 4);
    expect(nextStreak('2026-02-28', 4, d), 5);
    expect(nextStreak('2026-02-20', 4, d), 1);
    expect(dayKey(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
