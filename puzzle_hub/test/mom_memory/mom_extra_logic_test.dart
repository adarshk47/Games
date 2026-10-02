import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/mom_memory/logic/mom_extra_logic.dart';

void main() {
  group('missing item', () {
    test('count grows 4..9', () {
      expect(missingCount(0), 4);
      expect(missingCount(5), 9);
      expect(missingCount(99), 9);
      expect(missingCount(-3), 4);
    });
    test('round is consistent', () {
      for (var l = 0; l <= missingMaxLevel; l++) {
        final r = buildMissingRound(l, Random(l));
        expect(r.items.length, missingCount(l));
        expect(r.items.toSet().length, r.items.length);
        expect(r.options.length, 4);
        expect(r.options.toSet().length, 4);
        expect(r.options.contains(r.answer), isTrue);
        // distractors were never on screen
        expect(r.options.where(r.items.contains).length, 1);
      }
    });
    test('tries to stars', () {
      expect(triesToStars(1), 3);
      expect(triesToStars(2), 2);
      expect(triesToStars(5), 1);
    });
  });

  group('word pairs', () {
    test('counts', () {
      expect(pairsCount(0), 3);
      expect(pairsCount(5), 6);
      for (var l = 0; l <= pairsMaxLevel; l++) {
        expect(pairsCount(l) >= 3 && pairsCount(l) <= 6, isTrue);
        expect(pairsOptionCount(l) >= 3 && pairsOptionCount(l) <= 4, isTrue);
      }
    });
    test('questions are valid', () {
      for (var l = 0; l <= pairsMaxLevel; l++) {
        final r = buildPairsRound(l, Random(7 + l));
        expect(r.shown.length, pairsCount(l));
        expect(r.questions.length, pairsQuestionCount(l));
        for (final q in r.questions) {
          expect(r.shown.contains(q.pairIndex), isTrue);
          expect(q.options.length, pairsOptionCount(l));
          expect(q.options.toSet().length, q.options.length);
          expect(q.options[q.answerOption], q.pairIndex);
        }
      }
    });
    test('stars', () {
      expect(pairsStars(3, 3), 3);
      expect(pairsStars(2, 3), 2);
      expect(pairsStars(0, 3), 1);
      expect(pairsStars(0, 0), 0);
    });
  });

  group('where was it', () {
    test('grid sizes and counts', () {
      expect(whereSize(0), 3);
      expect(whereSize(5), 4);
      for (var l = 0; l <= whereMaxLevel; l++) {
        final m = buildWhereRound(l, Random(l));
        expect(m.length, whereCount(l));
        expect(
          m.keys.every((c) => c >= 0 && c < whereSize(l) * whereSize(l)),
          isTrue,
        );
      }
    });
    test('scoring', () {
      final r = scoreWhere([1, 2, 5], [1, 2, 3]);
      expect(r.correct, 2);
      expect(r.wrong, 1);
      expect(whereStars(3, 0, 3), 3);
      expect(whereStars(2, 0, 3), 2);
      expect(whereStars(0, 4, 3), 1);
    });
  });

  group('story recall', () {
    test('at least 8 well-formed stories', () {
      expect(stories.length >= 8, isTrue);
      for (final s in stories) {
        expect(
          s.lines.length >= 3 && s.lines.length <= 4,
          isTrue,
          reason: s.title,
        );
        expect(s.questions.length, 3);
        for (final q in s.questions) {
          expect(q.options.length, 3);
          expect(q.answer >= 0 && q.answer < q.options.length, isTrue);
        }
      }
    });
    test('next story differs and stars clamp', () {
      final rng = Random(1);
      for (var i = 0; i < 50; i++) {
        expect(nextStoryIndex(3, rng) != 3, isTrue);
      }
      expect(storyStars(5), 3);
      expect(storyStars(2), 2);
    });
  });
}
