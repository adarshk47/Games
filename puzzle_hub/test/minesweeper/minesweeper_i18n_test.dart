import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/minesweeper.dart';
import 'package:puzzle_hub/games/minesweeper/minesweeper_screen.dart';

import '../block_puzzle/i18n_helpers.dart';

void main() {
  test('minesweeper strings: 9 languages, same placeholders', () => checkTable('minesweeper', minesweeperStrings));
  test('minesweeper source keys exist', () => checkSourceKeys('lib/games/minesweeper'));
  firstScreenInAllLanguages('Minesweeper', () => const MinesweeperScreen(), then: (t) async {
    await t.tap(find.text(tr('common.tier.easy')).first);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text(tr('minesweeper.reveal')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('modeToggle')));
    await t.pump();
    expect(find.text(tr('minesweeper.flag')), findsOneWidget);
  });
}
