import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/screw_jam/logic/screw_jam_logic.dart';
import 'package:puzzle_hub/games/screw_jam/progress.dart';
import 'package:puzzle_hub/games/screw_jam/screw_jam_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setup(WidgetTester t, Widget home, {int coins = 0, Size size = const Size(400, 800)}) async {
  SharedPreferences.setMockInitialValues({});
  await Storage.init();
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
    expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
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
    expect(find.text('Tray 0/4'), findsOneWidget);
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

  testWidgets('next locked level can be bought from the grid', (t) async {
    await _setup(t, const ScrewJamLevels(tier: SjTier.medium), coins: 150);
    await _settle(t, 2);
    await t.tap(find.byIcon(Icons.lock_open_rounded));
    await _settle(t, 2);
    expect(find.text('Unlock level?'), findsOneWidget);
    await t.tap(find.text('Use 150 coins'));
    await _settle(t, 3);
    expect(find.text('Medium · Level 2'), findsOneWidget);
    expect(SjProgress.unlocked(SjTier.medium), 2);
    expect(Rewards.balance, 0);
    await _finish(t);
  });
}
