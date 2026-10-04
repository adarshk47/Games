import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ads/ads_service.dart';
import 'package:puzzle_hub/core/economy/continue_offer.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/shop/shop_screen.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'coins': 25});
    await Storage.init();
    Storage.userPrefix = '';
    AdsService.rewardedOverride = null;
    AdsService.clock = DateTime.now;
    Rewards.reload();
  });

  testWidgets('shop renders body-only with balance and cards', (t) async {
    await t.pumpWidget(const MaterialApp(home: Material(color: Colors.black, child: ShopScreen())));
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Watch ad: +25 coins'), findsOneWidget);
    expect(find.text('24h Ad-free pass'), findsOneWidget);
    expect(find.byType(Scaffold), findsNothing);
    await t.scrollUntilVisible(find.text('Coin history'), 200);
    expect(find.text('Coin history'), findsOneWidget);
  });

  testWidgets('continue offer spends coins and returns true', (t) async {
    bool? result;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Center(
          child: TextButton(
            onPressed: () async => result = await showContinueOffer(ctx, OfferKind.hint),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Use 20 coins'));
    await t.pumpAndSettle();
    expect(result, isTrue);
    expect(Rewards.balance, 5);
  });

  testWidgets('continue offer watch ad grants for free', (t) async {
    AdsService.rewardedOverride = (_) async => true;
    bool? result;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Center(
          child: TextButton(
            onPressed: () async => result = await showContinueOffer(ctx, OfferKind.unlockLevel),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Watch ad'));
    await t.pumpAndSettle();
    expect(result, isTrue);
    expect(Rewards.balance, 25);
  });
}
