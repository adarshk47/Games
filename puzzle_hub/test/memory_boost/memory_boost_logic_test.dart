import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/memory_boost/logic/card_deck.dart';
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
}
