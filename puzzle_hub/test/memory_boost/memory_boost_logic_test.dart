import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/memory_boost/logic/card_deck.dart';
import 'package:puzzle_hub/games/memory_boost/logic/mb_tiers.dart';
import 'package:puzzle_hub/games/memory_boost/logic/number_logic.dart';
import 'package:puzzle_hub/games/memory_boost/logic/simon_logic.dart';

void main() {
  group('card deck', () {
    test('every level has even cells and enough emojis', () {
      for (final l in cardLevels) {
        expect((l.rows * l.cols) % 2, 0);
        expect(l.pairs <= cardEmojis.length, isTrue);
      }
      expect(cardLevels.first.label, '2x2');
      expect(cardLevels.last.label, '6x6');
    });
    test('deck has each id exactly twice', () {
      final d = generateDeck(18, Random(1));
      expect(d.length, 36);
      for (var i = 0; i < 18; i++) {
        expect(d.where((x) => x == i).length, 2);
      }
    });
    test('matching', () {
      final d = [0, 1, 0, 1];
      expect(isMatch(d, 0, 2), isTrue);
      expect(isMatch(d, 0, 1), isFalse);
      expect(isMatch(d, 0, 0), isFalse);
    });
    test('stars', () {
      expect(starsFor(2, 2), 3);
      expect(starsFor(4, 2), 2);
      expect(starsFor(20, 2), 1);
    });
  });

  group('simon', () {
    test('sequence checking', () {
      final s = SimonLogic(rng: Random(3));
      s.addStep();
      s.addStep();
      final seq = List<int>.from(s.sequence);
      expect(s.input(seq[0]), SequenceResult.correct);
      expect(s.input(seq[1]), SequenceResult.complete);
      s.addStep();
      expect(s.input((s.sequence[0] + 1) % 4), SequenceResult.wrong);
      expect(s.streak, 2);
    });
    test('speed increases', () {
      expect(SimonLogic.stepMillis(10) < SimonLogic.stepMillis(1), isTrue);
      expect(SimonLogic.stepMillis(100), 220);
    });
  });

  group('number memory', () {
    test('generation length and no leading zero', () {
      final r = Random(5);
      for (var d = 1; d < 12; d++) {
        for (var i = 0; i < 20; i++) {
          final n = generateNumber(d, r);
          expect(n.length, d);
          expect(n[0], isNot('0'));
        }
      }
    });
    test('duration grows with length', () {
      expect(displayDuration(5) > displayDuration(2), isTrue);
    });
    test('answer check', () {
      expect(isCorrectAnswer('123', '123'), isTrue);
      expect(isCorrectAnswer('123', '124'), isFalse);
    });
  });

  group('tiers', () {
    test('card tiers get harder', () {
      for (final t in Tier.values) {
        for (final l in cardTierParams[t]!.levels) {
          expect((l.rows * l.cols) % 2, 0);
          expect(l.pairs <= cardEmojis.length, isTrue);
        }
      }
      expect(cardTierParams[Tier.easy]!.levels.last.label, '4x4');
      expect(cardTierParams[Tier.extreme]!.levels.first.label, '5x6');
      expect(cardTierParams[Tier.extreme]!.levels.last.label, '6x6');
      final flips = [for (final t in Tier.values) cardTierParams[t]!.flipBackMs];
      for (var i = 1; i < flips.length; i++) {
        expect(flips[i] < flips[i - 1], isTrue);
      }
      expect(cardTierParams[Tier.extreme]!.peekMs > 0, isTrue);
      expect(cardTierParams[Tier.extreme]!.timeLimit(0), isNotNull);
      expect(cardTierParams[Tier.medium]!.timeLimit(0), isNull);
    });
    test('simon tiers get faster', () {
      final ms = [for (final t in Tier.values) simonTierParams[t]!.baseMs];
      for (var i = 1; i < ms.length; i++) {
        expect(ms[i] < ms[i - 1], isTrue);
      }
      expect(simonTierParams[Tier.easy]!.pads, 4);
      expect(simonTierParams[Tier.extreme]!.pads, 6);
      expect(simonTierParams[Tier.easy]!.chances, 2);
      final p = simonTierParams[Tier.hard]!;
      expect(SimonLogic.stepMillis(1, base: p.baseMs, min: p.minMs, decay: p.decayMs), p.baseMs);
      expect(SimonLogic.stepMillis(500, base: p.baseMs, min: p.minMs, decay: p.decayMs), p.minMs);
    });
    test('simon six pads and restart', () {
      final s = SimonLogic(rng: Random(2), pads: 6);
      for (var i = 0; i < 30; i++) {
        s.addStep();
      }
      expect(s.sequence.every((p) => p >= 0 && p < 6), isTrue);
      expect(s.input((s.sequence[0] + 1) % 6), SequenceResult.wrong);
      s.restartInput();
      expect(s.input(s.sequence[0]), SequenceResult.correct);
    });
    test('number tiers', () {
      final shows = [for (final t in Tier.values) numberTierParams[t]!.displayFor(5)];
      for (var i = 1; i < shows.length; i++) {
        expect(shows[i] < shows[i - 1], isTrue);
      }
      final starts = [for (final t in Tier.values) numberTierParams[t]!.startDigits];
      for (var i = 1; i < starts.length; i++) {
        expect(starts[i] > starts[i - 1], isTrue);
      }
      expect(numberTierParams[Tier.extreme]!.lives, 1);
      expect(numberTierParams[Tier.hard]!.digitsForRound(1), 4);
      expect(numberTierParams[Tier.hard]!.digitsForRound(3), 6);
      expect(digitsForLevel(3, 4), 6);
    });
    test('keys include tier', () {
      expect(cardRewardKey(Tier.hard, 2), 'cards-hard-L3');
      expect(simonRewardKey(Tier.easy, 5), 'simon-easy-5');
      expect(numberRewardKey(Tier.extreme, 7), 'number-extreme-7');
      expect(simonBestKeyFor(Tier.medium), 'memory.simon.medium.best');
      expect(numberBestKeyFor(Tier.hard), 'memory.number.hard.best');
      expect(cardStarsKey(Tier.easy, 0), 'memory.cards.easy.stars.0');
    });
  });
}
