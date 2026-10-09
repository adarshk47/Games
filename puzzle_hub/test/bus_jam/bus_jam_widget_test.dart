import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/economy/level_gate.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/bus_jam/bus_jam_screen.dart';
import 'package:puzzle_hub/games/bus_jam/logic/bus_jam_logic.dart';
import 'package:puzzle_hub/games/bus_jam/progress.dart';
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

Future<void> _tapP(WidgetTester t, int id) async {
  await t.tap(find.byKey(ValueKey('bj_p_$id')));
  await t.pump(const Duration(milliseconds: 120));
}

/// Taps that fill the waiting area: prefer passengers the bus does not want.
List<int> _losingLine(BjGame g) {
  final out = <int>[];
  while (!g.over) {
    final open = g.removable;
    final bad = open.where((s) => g.colorOf(s) != g.busColor).toList();
    final pick = bad.isNotEmpty ? bad.first : open.first;
    g.tap(pick);
    out.add(pick);
  }
  return out;
}

void main() {
  testWidgets('tier select opens the level grid', (t) async {
    await _setup(t, const BusJamScreen());
    expect(find.text('Bus Jam'), findsOneWidget);
    expect(find.text('Choose difficulty'), findsOneWidget);
    for (final s in ['Easy', 'Medium', 'Hard']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    await t.tap(find.text('Hard'));
    await _settle(t, 3);
    expect(find.text('Bus Jam · Hard'), findsOneWidget);
    expect(find.text('Play level 1'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    await _finish(t);
  });

  testWidgets('playing the winning line wins and saves progress', (t) async {
    await _setup(t, const BusJamGame(tier: BjTier.easy, level: 1));
    final lv = bjGenerate(BjTier.easy, 1);
    expect(find.text('${lv.buses.length} buses left'), findsOneWidget);
    for (final id in lv.solution) {
      await _tapP(t, id);
    }
    await _settle(t, 10);
    expect(t.takeException(), isNull);
    expect(find.text('Level complete!'), findsOneWidget);
    expect(BjProgress.stars(BjTier.easy, 1), greaterThanOrEqualTo(2));
    expect(BjProgress.unlocked(BjTier.easy), 2);
    expect(Rewards.balance, greaterThan(0));
    await t.tap(find.text('Next level'));
    await _settle(t, 2);
    expect(find.text('Easy · Level 2'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('a boxed-in passenger is refused', (t) async {
    await _setup(t, const BusJamGame(tier: BjTier.medium, level: 5));
    final g = BjGame(bjGenerate(BjTier.medium, 5));
    final blocked = g.crowd.firstWhere((id) => !g.canTap(id));
    await _tapP(t, blocked);
    expect(find.text('No way out! Clear a path first.'), findsOneWidget);
    expect(find.byKey(ValueKey('bj_p_$blocked')), findsOneWidget);
    await _settle(t);
    await _finish(t);
  });

  testWidgets('full waiting area offers an extra spot, declining loses', (t) async {
    const tier = BjTier.extreme;
    await _setup(t, const BusJamGame(tier: tier, level: 1), coins: 100, size: const Size(400, 860));
    final g = BjGame(bjGenerate(tier, 1));
    final line = _losingLine(g);
    expect(g.lost, isTrue);
    for (final id in line) {
      await _tapP(t, id);
    }
    await _settle(t);
    expect(find.text('Keep going?'), findsOneWidget);
    await t.tap(find.text('Use 30 coins'));
    await _settle(t);
    expect(find.text('Waiting area full!'), findsNothing);
    expect(Rewards.balance, 70);
    expect(find.text('Waiting 5/6'), findsOneWidget);
    g.addSlot();
    final more = _losingLine(g);
    expect(g.lost, isTrue);
    for (final id in more) {
      await _tapP(t, id);
    }
    await _settle(t);
    expect(find.text('Keep going?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await _settle(t);
    expect(find.text('Waiting area full!'), findsOneWidget);
    await t.tap(find.text('Try again'));
    await _settle(t, 2);
    expect(find.text('Waiting 0/5'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('hints: two free, then a paid offer', (t) async {
    await _setup(t, const BusJamGame(tier: BjTier.easy, level: 3), coins: 0);
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
    await _setup(t, const BusJamLevels(tier: BjTier.medium), coins: 1000);
    await _settle(t, 2);
    const prefix = 'bus_jam.medium';
    expect(BjProgress.isFree(BjTier.medium, 1), isTrue);
    expect(BjProgress.isFree(BjTier.medium, 5), isFalse);
    await t.tap(find.byKey(const ValueKey('bj_level_5')));
    await _settle(t, 2);
    expect(find.text('Unlock level 5?'), findsOneWidget);
    await t.tap(find.text('Unlock for 400 coins'));
    await _settle(t, 3);
    expect(Rewards.balance, 600);
    expect(find.text('Medium · Level 5'), findsOneWidget);
    expect(LevelGate.playsLeft(prefix, 5), LevelGate.maxPlays - 1);
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
    await _setup(t, const BusJamLevels(tier: BjTier.easy), coins: 50);
    await _settle(t, 2);
    await t.tap(find.byKey(const ValueKey('bj_level_3')));
    await _settle(t, 2);
    expect(find.text('Unlock level 3?'), findsOneWidget);
    await t.tap(find.text('Unlock for 200 coins'));
    await _settle(t, 2);
    expect(find.text('Not enough coins'), findsOneWidget);
    expect(Rewards.balance, 50);
    expect(LevelGate.playsLeft('bus_jam.easy', 3), 0);
    expect(BjProgress.canPlay(BjTier.easy, 3), isFalse);
    expect(find.text('Easy · Level 3'), findsNothing);
    await _finish(t);
  });

  testWidgets('skip gate: last play used without clearing locks the level again', (t) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    await Storage.setInt('bus_jam.hard.skip.7', 1);
    await _setup(t, const BusJamGame(tier: BjTier.hard, level: 7), keep: true);
    expect(find.text('Hard · Level 7'), findsOneWidget);
    expect(LevelGate.playsLeft('bus_jam.hard', 7), 0);
    expect(BjProgress.canPlay(BjTier.hard, 7), isFalse);
    await t.tap(find.text('Restart'));
    await _settle(t, 2);
    expect(find.textContaining('locked again'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('skip gate: clearing a bought level keeps it and opens the next one', (t) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    await Storage.setInt('bus_jam.easy.skip.20', LevelGate.maxPlays);
    await _setup(t, const BusJamGame(tier: BjTier.easy, level: 20), keep: true);
    expect(find.text('Easy · Level 20'), findsOneWidget);
    for (final id in bjGenerate(BjTier.easy, 20).solution) {
      await _tapP(t, id);
    }
    await _settle(t, 10);
    expect(find.text('Level complete!'), findsOneWidget);
    expect(LevelGate.playsLeft('bus_jam.easy', 20), 0);
    expect(BjProgress.isDone(BjTier.easy, 20), isTrue);
    expect(BjProgress.canPlay(BjTier.easy, 20), isTrue);
    expect(BjProgress.isFree(BjTier.easy, 21), isTrue);
    expect(BjProgress.isFree(BjTier.easy, 19), isFalse);
    expect(BjProgress.unlocked(BjTier.easy), 1);
    await t.tap(find.text('Next level'));
    await _settle(t, 2);
    expect(find.text('Easy · Level 21'), findsOneWidget);
    await _finish(t);
  });

  test('progress: clearing in order runs through skipped levels already cleared', () async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    const t = BjTier.medium;
    await BjProgress.complete(t, 3, 2);
    expect(BjProgress.unlocked(t), 1);
    expect(BjProgress.freeUpTo(t, 10), 4);
    expect(LevelGate.skipPrice(BjProgress.freeUpTo(t, 10), 10), 600);
    await BjProgress.complete(t, 1, 3);
    expect(BjProgress.unlocked(t), 2);
    await BjProgress.complete(t, 2, 3);
    expect(BjProgress.unlocked(t), 4);
    expect(BjProgress.completed(t), 3);
  });
}
