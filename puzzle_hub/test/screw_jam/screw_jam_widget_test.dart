import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/economy/level_gate.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/screw_jam/logic/screw_jam_logic.dart';
import 'package:puzzle_hub/games/screw_jam/progress.dart';
import 'package:puzzle_hub/games/screw_jam/screw_jam_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setup(WidgetTester t, Widget home,
    {int coins = 0, Size size = const Size(400, 800), bool keep = false}) async {
  if (!keep) {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
  }
  await Storage.setInt('coins', coins);
  Rewards.reload();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(MaterialApp(home: home));
  await t.pump(const Duration(seconds: 1));
}

Future<void> _settle(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 3));
}

Future<void> _tapScrew(WidgetTester t, int id) async {
  await t.tap(find.byKey(ValueKey('sj_screw_$id')));
  await t.pump(const Duration(milliseconds: 120));
}

/// Taps that fill the tray: prefer screws no box wants.
List<int> _losingLine(SjGame g) {
  final out = <int>[];
  while (!g.over) {
    final open = g.removable.toList();
    final bad = open.where((s) => g.slotFor(s) == null).toList();
    final pick = bad.isNotEmpty ? bad.first : open.first;
    g.tap(pick);
    out.add(pick);
  }
  return out;
}

void main() {
  testWidgets('tier select opens the level grid', (t) async {
    await _setup(t, const ScrewJamScreen());
    expect(find.text('Screw Jam'), findsOneWidget);
    expect(find.text('Choose difficulty'), findsOneWidget);
    for (final s in ['Easy', 'Medium', 'Hard']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    await t.tap(find.text('Hard'));
    await _settle(t, 3);
    expect(find.text('Screw Jam · Hard'), findsOneWidget);
    expect(find.text('Play level 1'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    await _finish(t);
  });

  testWidgets('playing the solution wins and saves progress', (t) async {
    await _setup(t, const ScrewJamGame(tier: SjTier.easy, level: 1));
    final lv = sjGenerate(SjTier.easy, 1);
    for (final s in lv.solution) {
      await _tapScrew(t, s);
    }
    await _settle(t);
    expect(t.takeException(), isNull);
    expect(find.text('Level complete!'), findsOneWidget);
    expect(SjProgress.stars(SjTier.easy, 1), 3);
    expect(SjProgress.unlocked(SjTier.easy), 2);
    expect(Rewards.balance, greaterThan(0));
    await t.tap(find.text('Next level'));
    await _settle(t, 2);
    expect(find.text('Easy · Level 2'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('a covered screw is refused', (t) async {
    await _setup(t, const ScrewJamGame(tier: SjTier.medium, level: 5));
    final g = SjGame(sjGenerate(SjTier.medium, 5));
    final blocked = g.level.screws.firstWhere((s) => g.isBlocked(s.id)).id;
    await _tapScrew(t, blocked);
    expect(find.text('Covered! Clear the plate above first.'), findsOneWidget);
    expect(find.byKey(ValueKey('sj_screw_$blocked')), findsOneWidget);
    await _settle(t);
    await _finish(t);
  });

  testWidgets('full tray offers an extra slot, declining loses', (t) async {
    const tier = SjTier.extreme;
    await _setup(t, const ScrewJamGame(tier: tier, level: 1), coins: 100, size: const Size(400, 860));
    final g = SjGame(sjGenerate(tier, 1));
    final line = _losingLine(g);
    expect(g.lost, isTrue);
    for (final s in line) {
      await _tapScrew(t, s);
    }
    await _settle(t);
    expect(find.text('Keep going?'), findsOneWidget);
    await t.tap(find.text('Use 30 coins'));
    await _settle(t);
    expect(find.text('Tray full!'), findsNothing);
    expect(Rewards.balance, 70);
    // Keep filling the bigger tray, then decline.
    g.addTraySlot();
    final more = _losingLine(g);
    expect(g.lost, isTrue);
    for (final s in more) {
      await _tapScrew(t, s);
    }
    await _settle(t);
    expect(find.text('Keep going?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await _settle(t);
    expect(find.text('Tray full!'), findsOneWidget);
    await t.tap(find.text('Try again'));
    await _settle(t, 2);
    expect(find.text('Tray 0/${sjSpec(tier).tray}'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('hints: two free, then a paid offer', (t) async {
    await _setup(t, const ScrewJamGame(tier: SjTier.easy, level: 3), coins: 0);
    await t.tap(find.textContaining('2 free'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.textContaining('1 free'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('free'), findsNothing);
    await t.tap(find.text('Hint'));
    await _settle(t, 2);
    expect(find.text('Need a hint?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await _settle(t, 2);
    await _finish(t);
  });

  testWidgets('skip gate: far-ahead level bought gets 10 plays, plays shown in the grid', (t) async {
    await _setup(t, const ScrewJamLevels(tier: SjTier.medium), coins: 1000);
    await _settle(t, 2);
    const prefix = 'screw_jam.medium';
    expect(SjProgress.isFree(SjTier.medium, 1), isTrue);
    expect(SjProgress.isFree(SjTier.medium, 5), isFalse);
    await t.tap(find.byKey(const ValueKey('sj_level_5')));
    await _settle(t, 2);
    expect(find.text('Unlock level 5?'), findsOneWidget);
    await t.tap(find.text('Unlock for 400 coins'));
    await _settle(t, 3);
    // Bought: 10 plays, opening it used one.
    expect(Rewards.balance, 600);
    expect(find.text('Medium · Level 5'), findsOneWidget);
    expect(LevelGate.playsLeft(prefix, 5), LevelGate.maxPlays - 1);
    // Restart uses another play.
    await t.tap(find.text('Restart'));
    await _settle(t, 2);
    expect(LevelGate.playsLeft(prefix, 5), LevelGate.maxPlays - 2);
    t.state<NavigatorState>(find.byType(Navigator)).pop();
    await _settle(t, 2);
    expect(find.text('8 plays left'), findsOneWidget);
    expect(find.text('Bought'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('skip gate: not enough coins is refused', (t) async {
    await _setup(t, const ScrewJamLevels(tier: SjTier.easy), coins: 50);
    await _settle(t, 2);
    await t.tap(find.byKey(const ValueKey('sj_level_3')));
    await _settle(t, 2);
    expect(find.text('Unlock level 3?'), findsOneWidget);
    await t.tap(find.text('Unlock for 200 coins'));
    await _settle(t, 2);
    expect(find.text('Not enough coins'), findsOneWidget);
    expect(Rewards.balance, 50);
    expect(LevelGate.playsLeft('screw_jam.easy', 3), 0);
    expect(SjProgress.canPlay(SjTier.easy, 3), isFalse);
    expect(find.text('Easy · Level 3'), findsNothing);
    await _finish(t);
  });

  testWidgets('skip gate: last play used without clearing locks the level again', (t) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    await Storage.setInt('screw_jam.hard.skip.7', 1);
    await _setup(t, const ScrewJamGame(tier: SjTier.hard, level: 7), keep: true);
    expect(find.text('Hard · Level 7'), findsOneWidget);
    expect(LevelGate.playsLeft('screw_jam.hard', 7), 0);
    expect(SjProgress.canPlay(SjTier.hard, 7), isFalse);
    await t.tap(find.text('Restart'));
    await _settle(t, 2);
    expect(find.textContaining('locked again'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('skip gate: clearing a bought level keeps it and opens the next one', (t) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    await Storage.setInt('screw_jam.easy.skip.20', LevelGate.maxPlays);
    await _setup(t, const ScrewJamGame(tier: SjTier.easy, level: 20), keep: true);
    expect(find.text('Easy · Level 20'), findsOneWidget);
    for (final s in sjGenerate(SjTier.easy, 20).solution) {
      await _tapScrew(t, s);
    }
    await _settle(t);
    expect(find.text('Level complete!'), findsOneWidget);
    expect(LevelGate.playsLeft('screw_jam.easy', 20), 0);
    expect(SjProgress.isDone(SjTier.easy, 20), isTrue);
    expect(SjProgress.canPlay(SjTier.easy, 20), isTrue);
    expect(SjProgress.isFree(SjTier.easy, 21), isTrue);
    expect(SjProgress.isFree(SjTier.easy, 19), isFalse);
    expect(SjProgress.unlocked(SjTier.easy), 1);
    await t.tap(find.text('Next level'));
    await _settle(t, 2);
    expect(find.text('Easy · Level 21'), findsOneWidget);
    await _finish(t);
  });

  test('progress: clearing in order runs through skipped levels already cleared', () async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    const t = SjTier.medium;
    await SjProgress.complete(t, 3, 2); // bought + cleared out of order
    expect(SjProgress.unlocked(t), 1);
    expect(SjProgress.freeUpTo(t, 10), 4);
    expect(LevelGate.skipPrice(SjProgress.freeUpTo(t, 10), 10), 600);
    await SjProgress.complete(t, 1, 3);
    expect(SjProgress.unlocked(t), 2);
    await SjProgress.complete(t, 2, 3);
    expect(SjProgress.unlocked(t), 4);
    expect(SjProgress.completed(t), 3);
  });
}
