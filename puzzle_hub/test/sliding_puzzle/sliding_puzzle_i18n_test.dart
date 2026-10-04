import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/strings/sliding_puzzle.dart';
import 'package:puzzle_hub/games/sliding_puzzle/sliding_puzzle_screen.dart';

import '../block_puzzle/i18n_helpers.dart';

void main() {
  test('sliding_puzzle strings: 7 languages, same placeholders', () => checkTable('sliding_puzzle', slidingPuzzleStrings));
  test('sliding_puzzle source keys exist', () => checkSourceKeys('lib/games/sliding_puzzle'));
  firstScreenInAllLanguages('Sliding Puzzle', () => const SlidingPuzzleScreen(), then: (t) async {
    await t.tap(find.text('1').first);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('tile-8')), findsOneWidget);
  });
}
