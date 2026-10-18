import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ads/ads_service.dart';
import 'package:puzzle_hub/core/economy/undo_offer.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late int result;
  late BuildContext ctx;

  Future<void> host(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    ));
  }

  Future<void> tapUndo(WidgetTester t, int available) async {
    result = -1;
    await t.runAsync(() async => result = await UndoOffer.ask(ctx, available: available));
    await t.pump(const Duration(milliseconds: 100));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
    UndoOffer.debugReset();
    AdsService.debugForceEnabled = true;
  });
  tearDown(() {
    AdsService.debugForceEnabled = false;
    AdsService.rewardedOverride = null;
  });

  testWidgets('one ad pays for 3 steps back; max 3 in a row', (t) async {
    var ads = 0;
    AdsService.rewardedOverride = (_) async {
      ads++;
      return true;
    };
    await host(t);
    await tapUndo(t, 10);
    expect(result, 1);
    expect(ads, 1);
    await tapUndo(t, 9);
    await tapUndo(t, 8);
    expect(result, 1);
    expect(ads, 1, reason: '2nd and 3rd step are already paid');
    await tapUndo(t, 7);
    expect(result, 0, reason: '4th step in a row is refused');
    expect(ads, 1);
    // A new move in between starts a fresh chain, and a new ad.
    await tapUndo(t, 8);
    expect(result, 1);
    expect(ads, 2);
  });

  testWidgets('closing the ad early gives nothing', (t) async {
    AdsService.rewardedOverride = (_) async => false;
    await host(t);
    await tapUndo(t, 2);
    expect(result, 0);
  });

  testWidgets('nothing to undo: no ad', (t) async {
    var ads = 0;
    AdsService.rewardedOverride = (_) async => ++ads > 0;
    await host(t);
    await tapUndo(t, 0);
    expect(result, 0);
    expect(ads, 0);
  });

  testWidgets('ad-free players go back for free', (t) async {
    var ads = 0;
    AdsService.rewardedOverride = (_) async => ++ads > 0;
    await Storage.setInt(
      AdsService.kAdFreeUntil,
      DateTime.now().add(const Duration(hours: 5)).millisecondsSinceEpoch,
    );
    await host(t);
    await tapUndo(t, 1);
    expect(result, 1);
    expect(ads, 0);
  });
}
