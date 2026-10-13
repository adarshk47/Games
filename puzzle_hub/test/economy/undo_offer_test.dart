import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ads/ads_service.dart';
import 'package:puzzle_hub/core/economy/undo_offer.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late int result;

  Future<void> open(WidgetTester t, int available) async {
    t.view.physicalSize = const Size(430, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    result = -1;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => result = await UndoOffer.ask(ctx, available: available),
              child: const Text('undo'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('undo'));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 100));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
    Rewards.reload();
    AdsService.debugForceEnabled = true;
  });
  tearDown(() {
    AdsService.debugForceEnabled = false;
    AdsService.rewardedOverride = null;
  });

  testWidgets('3 steps back = 3 ads; max 3 even with more history', (t) async {
    var ads = 0;
    AdsService.rewardedOverride = (_) async {
      ads++;
      return true;
    };
    await open(t, 10);
    expect(find.byKey(const ValueKey('undo_ads_3')), findsOneWidget);
    expect(find.byKey(const ValueKey('undo_ads_4')), findsNothing);
    await t.tap(find.byKey(const ValueKey('undo_ads_3')));
    await t.pump(const Duration(milliseconds: 600));
    expect(ads, 3);
    expect(result, 3);
  });

  testWidgets('an unfinished ad gives no steps', (t) async {
    var ads = 0;
    AdsService.rewardedOverride = (_) async => ++ads < 2; // 2nd ad fails
    await open(t, 2);
    await t.tap(find.byKey(const ValueKey('undo_ads_2')));
    await t.pump(const Duration(milliseconds: 600));
    expect(result, -1, reason: 'dialog stays open');
    await t.tap(find.text('Cancel'));
    await t.pump(const Duration(milliseconds: 600));
    expect(result, 0);
  });

  testWidgets('coins: 10 per step', (t) async {
    await Rewards.addCoins(25, playSound: false);
    await open(t, 3);
    await t.tap(find.byKey(const ValueKey('undo_coins_2')));
    await t.pump(const Duration(milliseconds: 600));
    expect(result, 2);
    expect(Rewards.balance, 5);
  });

  testWidgets('ad-free players go back for free', (t) async {
    await Storage.setInt(
      AdsService.kAdFreeUntil,
      DateTime.now().add(const Duration(hours: 5)).millisecondsSinceEpoch,
    );
    await open(t, 1);
    expect(result, 1);
  });
}
