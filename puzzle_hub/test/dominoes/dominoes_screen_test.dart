import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/dominoes/dominoes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
    DominoesPlayScreen.botDelay = const Duration(milliseconds: 10);
  });

  for (final size in const [Size(320, 560), Size(390, 844)]) {
    testWidgets('menu builds in every language at $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      for (final l in AppLang.values) {
        I18n.lang.value = l;
        await t.pumpWidget(MaterialApp(key: ValueKey(l), home: const DominoesScreen()));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull, reason: l.code);
        expect(find.text(tr('domino.intro')), findsOneWidget);
      }
      I18n.lang.value = AppLang.en;
    });
  }

  for (final players in const [2, 4]) {
    testWidgets('a $players-player table plays tiles without errors', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(MaterialApp(home: DominoesPlayScreen(players: players, level: 1, target: 50, random: math.Random(4))));
      await t.pump(const Duration(milliseconds: 100));
      // Play a few of our turns: tap the first fitting tile, choose an end
      // when asked, or draw / pass.
      for (var turn = 0; turn < 12; turn++) {
        await t.pump(const Duration(milliseconds: 200));
        if (find.byKey(const ValueKey('domino_draw')).evaluate().isNotEmpty) {
          await t.tap(find.byKey(const ValueKey('domino_draw')));
          continue;
        }
        for (var i = 0; i < 8; i++) {
          final f = find.byKey(ValueKey('domino_hand_$i'));
          if (f.evaluate().isEmpty) break;
          await t.tap(f);
          await t.pump();
          if (find.byKey(const ValueKey('domino_left')).evaluate().isNotEmpty) {
            await t.tap(find.byKey(const ValueKey('domino_left')));
            break;
          }
        }
        // Close a round dialog if one opened.
        await t.pump(const Duration(milliseconds: 800));
        final next = find.text('Next round');
        if (next.evaluate().isNotEmpty) await t.tap(next);
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  }
}
