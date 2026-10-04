import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/flow_pairs.dart';
import 'package:puzzle_hub/games/flow_pairs/flow_pairs_screen.dart';

import '../block_puzzle/i18n_helpers.dart';

void main() {
  test('flow_pairs strings: 7 languages, same placeholders', () => checkTable('flow_pairs', flowPairsStrings));
  test('flow_pairs source keys exist', () => checkSourceKeys('lib/games/flow_pairs'));
  firstScreenInAllLanguages('Flow', () => const FlowPairsScreen(), then: (t) async {
    await t.tap(find.text(tr('common.tier.easy')));
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const ValueKey('flow_level_1')));
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('flow_board_easy_1')), findsOneWidget);
  });
}
