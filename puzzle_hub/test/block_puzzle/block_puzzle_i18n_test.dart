import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/block_puzzle.dart';
import 'package:puzzle_hub/games/block_puzzle/block_puzzle_screen.dart';

import 'i18n_helpers.dart';

void main() {
  test('block_puzzle strings: 7 languages, same placeholders', () => checkTable('block_puzzle', blockPuzzleStrings));
  test('block_puzzle source keys exist', () => checkSourceKeys('lib/games/block_puzzle'));
  firstScreenInAllLanguages('Block Puzzle', () => const BlockPuzzleScreen(), size: const Size(400, 800), then: (t) async {
    await t.tap(find.text(tr('common.tier.easy')));
    await t.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('score')), findsOneWidget);
  });
}
