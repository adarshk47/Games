import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ads/ads_service.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/parking_jam/logic/parking_logic.dart';
import 'package:puzzle_hub/games/parking_jam/parking_jam_game.dart';
import 'package:puzzle_hub/games/parking_jam/parking_jam_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _init(WidgetTester t, {Map<String, Object> prefs = const {}, Size size = const Size(360, 640)}) async {
  SharedPreferences.setMockInitialValues(prefs);
  await Storage.init();
  Storage.userPrefix = '';
  AdsService.rewardedOverride = null;
  Rewards.reload();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
}

Future<void> _settle(WidgetTester t, [int ms = 900]) async {
  await t.pump();
  await t.pump(Duration(milliseconds: ms));
}

/// Two cars: tapping car 0 drives it one cell into car 1 (a counted move).
PjLevel _jamLevel({int? limit}) => PjLevel(
      tier: PjTier.hard,
      level: 1,
      state: ParkingState(size: 6, vehicles: [
        Vehicle(id: 0, row: 0, col: 0, length: 2, horizontal: true, facing: 1, color: 0),
        Vehicle(id: 1, row: 0, col: 3, length: 2, horizontal: false, facing: 1, color: 1),
      ]),
      solution: const [1, 0],
      moveLimit: limit,
    );

void main() {
  tearDown(() => I18n.lang.value = AppLang.en);

  testWidgets('tier select shows tiers, opens level grid with locks', (t) async {
    await _init(t);
    await t.pumpWidget(const MaterialApp(home: ParkingJamScreen()));
    await _settle(t);
    expect(find.text('Parking Jam'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Not started'), findsWidgets);
    await t.drag(find.byType(ListView), const Offset(0, -600));
    await _settle(t);
    expect(find.text('Extreme'), findsOneWidget);
    await t.drag(find.byType(ListView), const Offset(0, 600));
    await _settle(t);
    await t.tap(find.text('Easy'));
    await _settle(t);
    expect(find.text('Play level 1'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('play easy level 1 to win, stars + unlock persisted, next level', (t) async {
    await _init(t);
    await t.pumpWidget(const MaterialApp(home: ParkingJamScreen()));
    await _settle(t);
    await t.tap(find.text('Easy'));
    await _settle(t);
    await t.tap(find.text('Play level 1'));
    await _settle(t);
    expect(find.byKey(const ValueKey('pj_board_easy_1')), findsOneWidget);

    // A free hint highlights a car that can leave.
    await t.tap(find.text('Hint (2)'));
    await _settle(t, 300);
    expect(find.text('Hint (1)'), findsOneWidget);

    final lv = generateLevel(PjTier.easy, 1);
    for (final id in lv.solution) {
      final car = find.byKey(ValueKey('pj_car_1_$id'));
      expect(car, findsOneWidget, reason: 'car $id');
      await t.tap(car, warnIfMissed: false);
      await _settle(t, 700);
    }
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Lot cleared!'), findsOneWidget);
    expect(Storage.getInt('parking_jam.easy.unlocked'), 2);
    expect(Storage.getInt('parking_jam.easy.stars.1'), 3);
    expect(Rewards.balance, greaterThan(0));

    await t.tap(find.text('Next level'));
    await _settle(t);
    await _settle(t);
    expect(find.byKey(const ValueKey('pj_board_easy_2')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('undo restores a move; bump does not count', (t) async {
    await _init(t);
    await t.pumpWidget(MaterialApp(home: ParkingJamGame(tier: PjTier.hard, level: 1, custom: _jamLevel())));
    await _settle(t);
    await t.tap(find.byKey(const ValueKey('pj_car_1_0')));
    await _settle(t);
    expect(find.text('Moves 1'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('pj_car_1_0')));
    await _settle(t);
    expect(find.text('Moves 1'), findsOneWidget);
    await t.tap(find.text('Undo'));
    await _settle(t);
    expect(find.text('Moves 0'), findsOneWidget);
  });

  testWidgets('out of moves: coins buy +5 moves', (t) async {
    await _init(t, prefs: {'coins': 100, 'coins.earned': 100, 'parking_jam.hard.unlocked': 1});
    await t.pumpWidget(MaterialApp(home: ParkingJamGame(tier: PjTier.hard, level: 1, custom: _jamLevel(limit: 1))));
    await _settle(t);
    expect(find.text('Moves 0/1'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('pj_car_1_0')));
    await _settle(t, 1200);
    await _settle(t, 600);
    final use = find.text(tr('offer.use_coins', {'coins': 30}));
    expect(use, findsOneWidget);
    await t.tap(use);
    await _settle(t);
    await _settle(t);
    expect(find.text('Moves 1/6'), findsOneWidget);
    expect(Rewards.balance, 70);
    // Now the jam can be cleared.
    await t.tap(find.byKey(const ValueKey('pj_car_1_1')));
    await _settle(t, 700);
    await t.tap(find.byKey(const ValueKey('pj_car_1_0')));
    await _settle(t, 700);
    await t.pump(const Duration(seconds: 2));
    expect(find.text('Lot cleared!'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('out of moves: declining shows the out-of-moves dialog', (t) async {
    await _init(t);
    await t.pumpWidget(MaterialApp(home: ParkingJamGame(tier: PjTier.hard, level: 1, custom: _jamLevel(limit: 1))));
    await _settle(t);
    await t.tap(find.byKey(const ValueKey('pj_car_1_0')));
    await _settle(t, 1200);
    await _settle(t, 600);
    await t.tap(find.text('Cancel'));
    await _settle(t);
    await _settle(t);
    expect(find.text('Out of moves'), findsOneWidget);
    await t.tap(find.text('Restart').last);
    await _settle(t);
    expect(find.text('Moves 0/1'), findsOneWidget);
  });

  testWidgets('third hint asks for coins via the hint offer', (t) async {
    await _init(t);
    await t.pumpWidget(MaterialApp(home: ParkingJamGame(tier: PjTier.hard, level: 1, custom: _jamLevel())));
    await _settle(t);
    await t.tap(find.text('Hint (2)'));
    await _settle(t, 300);
    await t.tap(find.text('Hint (1)'));
    await _settle(t, 300);
    await t.tap(find.text('Hint'));
    await _settle(t);
    expect(find.text(tr('offer.hint.title')), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await _settle(t);
  });

  testWidgets('next locked level can be bought from the grid', (t) async {
    await _init(t, prefs: {'coins': 200, 'coins.earned': 200});
    await t.pumpWidget(const MaterialApp(home: PjLevelGridScreen(tier: PjTier.medium)));
    await _settle(t);
    await t.tap(find.byKey(const ValueKey('pj_level_2')));
    await _settle(t);
    await t.tap(find.text(tr('offer.use_coins', {'coins': 150})));
    await _settle(t);
    await _settle(t);
    expect(Storage.getInt('parking_jam.medium.unlocked'), 2);
    expect(find.byKey(const ValueKey('pj_board_medium_2')), findsOneWidget);
  });

  for (final lang in AppLang.values) {
    testWidgets('renders in ${lang.code} at 360x640 without overflow', (t) async {
      I18n.lang.value = lang;
      await _init(t, prefs: {'parking_jam.extreme.unlocked': 31, 'parking_jam.extreme.level': 30});
      await t.pumpWidget(const MaterialApp(home: ParkingJamScreen()));
      await _settle(t);
      expect(t.takeException(), isNull);
      expect(find.text(tr('parking_jam.choose')), findsOneWidget);
      await t.drag(find.byType(ListView), const Offset(0, -600));
      await _settle(t);
      expect(t.takeException(), isNull);
      await t.tap(find.text(tr('common.tier.extreme')).first);
      await _settle(t);
      expect(t.takeException(), isNull);
      await t.tap(find.text(tr('parking_jam.play_level', {'n': 30})));
      await _settle(t);
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('pj_board_extreme_30')), findsOneWidget);
      // Hint banner / highlight, a drive and undo.
      await t.tap(find.textContaining(tr('common.hint')).first);
      await _settle(t, 400);
      final lv = generateLevel(PjTier.extreme, 30);
      await t.tap(find.byKey(ValueKey('pj_car_30_${lv.solution.first}')), warnIfMissed: false);
      await _settle(t, 800);
      expect(t.takeException(), isNull);
      await t.tap(find.text(tr('common.undo')));
      await _settle(t);
      expect(t.takeException(), isNull);
      // Out-of-moves dialog in this language.
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
      await t.pumpWidget(MaterialApp(home: ParkingJamGame(tier: PjTier.hard, level: 1, custom: _jamLevel(limit: 1))));
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('pj_car_1_0')));
      await _settle(t, 1200);
    await _settle(t, 600);
      expect(t.takeException(), isNull);
      await t.tap(find.text(tr('common.cancel')));
      await _settle(t);
      await _settle(t);
      expect(find.text(tr('parking_jam.out_title')), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });
  }
}
