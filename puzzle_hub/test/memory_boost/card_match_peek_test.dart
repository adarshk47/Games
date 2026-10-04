import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ads/ads_service.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/memory_boost/card_match_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'coins': 100});
    await Storage.init();
    Storage.userPrefix = '';
    AdsService.rewardedOverride = null;
    Rewards.reload();
  });

  testWidgets('Card Match Peek: first free, then coin offer', (t) async {
    await t.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const MaterialApp(home: CardMatchScreen()));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Easy'));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('2x2 grid'));
    await t.pump(const Duration(seconds: 1));

    expect(find.text('Peek  (1 free)'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('peek-button')));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Peek  (20 coins)'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));

    await t.tap(find.byKey(const ValueKey('peek-button')));
    for (var i = 0; i < 15; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Use 20 coins'), findsOneWidget);
    await t.tap(find.text('Use 20 coins'));
    await t.pump(const Duration(milliseconds: 500));
    expect(Rewards.balance, 80);
    await t.pump(const Duration(seconds: 2));
    await t.pumpWidget(const SizedBox());
  });
}
