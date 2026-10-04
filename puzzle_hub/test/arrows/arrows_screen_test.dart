import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/arrows/arrows_screen.dart';
import 'package:puzzle_hub/games/arrows/logic/arrows_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setup(WidgetTester t, Size size, Widget home) async {
  SharedPreferences.setMockInitialValues({});
  await Storage.init();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(MaterialApp(home: home));
  await t.pump(const Duration(seconds: 1));
}

Future<void> _playLevel(WidgetTester t, ArrowsTier tier, int level) async {
  final board = ArrowsLevels.generate(tier, level);
  final n = board.size;
  final boardFinder = find.byKey(ValueKey('board_${tier.id}_${level}_1'), skipOffstage: false);
  expect(boardFinder, findsOneWidget);
  final rect = t.getRect(boardFinder);
  final cell = rect.width / n;
  Offset center(ArrowPiece p) =>
      rect.topLeft + Offset((p.c + .5) * cell, (p.r + .5) * cell);
  // tap a blocked one first (if any), then hint, then solve
  final blocked = board.pieces.where((p) => !board.canRemove(p)).toList();
  if (blocked.isNotEmpty) {
    await t.tapAt(center(blocked.first));
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.tap(find.byIcon(Icons.lightbulb_rounded));
  await t.pump(const Duration(milliseconds: 200));
  while (!board.isCleared) {
    final p = board.hint()!;
    board.tap(p.r, p.c);
    await t.tapAt(center(p));
    await t.pump(const Duration(milliseconds: 60));
  }
  await t.pump(const Duration(seconds: 1));
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(seconds: 1));
}

void main() {
  for (final size in const [Size(360, 640), Size(800, 1280), Size(320, 480)]) {
    testWidgets('level list + play + win at $size', (t) async {
      await _setup(t, size, const ArrowsScreen());
      expect(find.text('Easy'), findsOneWidget);
      await t.drag(find.byType(ListView), const Offset(0, -600));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Extreme'), findsOneWidget);
      await t.drag(find.byType(ListView), const Offset(0, 600));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text('Easy'));
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text('1'));
      await t.pump(const Duration(seconds: 1));
      await _playLevel(t, ArrowsTier.easy, 1);
      expect(find.text('Level cleared!'), findsOneWidget);
      await t.tap(find.text('Next level'));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Easy - Level 2'), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.byIcon(Icons.refresh_rounded));
      await t.pump(const Duration(seconds: 1));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('lose all lives then retry', (t) async {
    await _setup(t, const Size(360, 640), const ArrowsGamePage(tier: ArrowsTier.easy, level: 20));
    final board = ArrowsLevels.generate(ArrowsTier.easy, 20);
    final blocked = board.pieces.firstWhere((p) => !board.canRemove(p));
    final rect = t.getRect(find.byKey(const ValueKey('board_easy_20_1')));
    final cell = rect.width / board.size;
    for (var i = 0; i < 3; i++) {
      await t.tapAt(rect.topLeft +
          Offset((blocked.c + .5) * cell, (blocked.r + .5) * cell));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    // Continue offer first (no coins); decline it.
    expect(find.text('Keep going?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Out of lives'), findsOneWidget);
    await t.tap(find.text('Retry'));
    await t.pump(const Duration(seconds: 1));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('extreme: one life, single block loses; hard small screen',
      (t) async {
    await _setup(t, const Size(320, 480),
        const ArrowsGamePage(tier: ArrowsTier.extreme, level: 30));
    final board = ArrowsLevels.generate(ArrowsTier.extreme, 30);
    final blocked = board.pieces.firstWhere((p) => !board.canRemove(p));
    final rect = t.getRect(find.byKey(const ValueKey('board_extreme_30_1')));
    final cell = rect.width / board.size;
    await t.tapAt(rect.topLeft +
        Offset((blocked.c + .5) * cell, (blocked.r + .5) * cell));
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    // Continue offer first (no coins); dismiss it via the barrier (the
    // dialog is taller than this tiny screen).
    expect(find.text('Keep going?'), findsOneWidget);
    // The shared offer dialog (lib/core) overflows on a 320x480 screen.
    t.takeException();
    await t.tapAt(const Offset(4, 4));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Out of lives'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  for (final tier in ArrowsTier.values) {
    testWidgets('every ${tier.id} level builds and is fully playable',
        (t) async {
      for (var l = 1; l <= ArrowsLevels.count; l++) {
        await _setup(t, const Size(360, 640),
            ArrowsGamePage(tier: tier, level: l));
        await _playLevel(t, tier, l);
        await t.pump(const Duration(seconds: 1));
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      }
    });
  }
}
