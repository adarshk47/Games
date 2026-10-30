import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ads/ads_service.dart';
import 'package:puzzle_hub/core/economy/continue_offer.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _fresh([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  await Storage.init();
  Storage.userPrefix = '';
  Rewards.reload();
}

void _expectInvariant() {
  expect(Rewards.balance, Rewards.earned - Rewards.spent);
  expect(Rewards.coins.value, Rewards.balance);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var now = DateTime(2026, 10, 4, 12);

  setUp(() async {
    AdsService.debugForceEnabled = true; // ads are off in release until enabled
    addTearDown(() => AdsService.debugForceEnabled = false);
    now = DateTime(2026, 10, 4, 12);
    AdsService.clock = () => now;
    AdsService.rewardedOverride = null;
    AdsService.debugReset(sessionStart: now);
    await _fresh();
  });

  group('ledger', () {
    test('add and spend keep balance == earned - spent', () async {
      await Rewards.addCoins(50);
      _expectInvariant();
      expect(await Rewards.spend(20), isTrue);
      expect(Rewards.balance, 30);
      expect(Rewards.earned, 50);
      expect(Rewards.spent, 20);
      expect(await Rewards.spend(31), isFalse);
      expect(Rewards.balance, 30);
      _expectInvariant();
    });

    test('missing earned is derived on reload', () async {
      await _fresh({'coins': 120});
      expect(Rewards.earned, 120);
      expect(Rewards.spent, 0);
      _expectInvariant();
    });

    test('old data with earned but no spent is repaired', () async {
      await _fresh({'coins': 40, 'coins.earned': 100});
      expect(Rewards.earned, 100);
      expect(Rewards.spent, 60);
      _expectInvariant();
    });

    test('merge takes max of each counter', () async {
      await Rewards.addCoins(100);
      await Rewards.spend(30);
      Rewards.mergeLedger(earned: 80, spent: 50);
      expect(Rewards.earned, 100);
      expect(Rewards.spent, 50);
      _expectInvariant();
    });
  });

  group('reward amounts', () {
    test('first completion = 3 + stars, replay = 1', () {
      expect(Rewards.onLevelComplete('g', 'l1', stars: 3), 6);
      expect(Rewards.onLevelComplete('g', 'l1', stars: 3), 1);
      expect(Rewards.onLevelComplete('g', 'l2'), 3);
      expect(Rewards.balance, 10);
      _expectInvariant();
    });

    test('runs pay 1 per 250 points (1..10) plus 2 for a win', () {
      expect(Rewards.runReward(score: 0), 0);
      expect(Rewards.runReward(score: 5), 1);
      expect(Rewards.runReward(score: 1000), 4);
      expect(Rewards.runReward(score: 99999), 10);
      expect(Rewards.runReward(score: 5, won: true), 3);
      Rewards.onGameEnd('g', score: 5, won: true);
      Rewards.onGameEnd('g', score: 5);
      expect(Rewards.balance, 4);
    });
  });

  group('ad-free pass', () {
    test('buy requires 3333 coins and expires after 24h', () async {
      expect(await AdsService.buyAdFree(), isFalse);
      expect(AdsService.adFree, isFalse);
      await Rewards.addCoins(3333);
      expect(await AdsService.buyAdFree(), isTrue);
      expect(Rewards.balance, 0);
      expect(AdsService.adFree, isTrue);
      expect(Storage.getInt('ads.adfree.until'), now.add(const Duration(hours: 24)).millisecondsSinceEpoch);
      now = now.add(const Duration(hours: 23, minutes: 59));
      expect(AdsService.adFree, isTrue);
      expect(AdsService.adFreeRemaining, const Duration(minutes: 1));
      now = now.add(const Duration(minutes: 2));
      expect(AdsService.adFree, isFalse);
      expect(AdsService.adFreeRemaining, Duration.zero);
    });

    test('coins earned while ad-free cannot buy another pass', () async {
      await Rewards.addCoins(3333);
      expect(await AdsService.buyAdFree(), isTrue);
      await Rewards.addCoins(4000); // earned during the ad-free time
      expect(Rewards.adFreeLocked, 4000);
      now = now.add(const Duration(hours: 25)); // pass over
      expect(AdsService.adFree, isFalse);
      expect(await AdsService.buyAdFree(), isFalse);
      expect(Rewards.balance, 4000);
      // Other purchases use the locked coins first.
      expect(await Rewards.spend(1000, reason: 'hint'), isTrue);
      expect(Rewards.adFreeLocked, 3000);
      await Rewards.addCoins(3333); // earned with ads on: usable
      expect(Rewards.spendableForAdFree, 3333);
      expect(await AdsService.buyAdFree(), isTrue);
      expect(Rewards.balance, 3000);
      _expectInvariant();
    });
  });

  group('rewarded ads', () {
    test('ads are a no-op on the test host', () async {
      await AdsService.init();
      expect(AdsService.available, isFalse);
      expect(await AdsService.showRewarded(reason: 'x'), isFalse);
    });
  });

  group('interstitial rules', () {
    test('after every game end (win or lose), not in first 30s, 30s gap', () {
      now = now.add(const Duration(seconds: 10));
      expect(AdsService.interstitialAllowed(), isFalse, reason: 'no game yet');
      AdsService.onLevelCompleted();
      expect(AdsService.interstitialAllowed(), isFalse); // session grace
      now = now.add(const Duration(seconds: 30));
      expect(AdsService.interstitialAllowed(), isTrue); // 1 game is enough
      AdsService.debugMarkInterstitialShown();
      now = now.add(const Duration(minutes: 5));
      expect(AdsService.interstitialAllowed(), isFalse, reason: 'no game since the last ad');
      AdsService.onLevelCompleted();
      expect(AdsService.interstitialAllowed(), isTrue);
      AdsService.debugMarkInterstitialShown();
      AdsService.onLevelCompleted();
      expect(AdsService.interstitialAllowed(), isFalse); // 30 s gap
      now = now.add(const Duration(seconds: 30));
      expect(AdsService.interstitialAllowed(), isTrue);
    });

    test('suppressed, Mom Memory and ad-free block interstitials', () async {
      now = now.add(const Duration(minutes: 10));
      for (var i = 0; i < 3; i++) {
        AdsService.onLevelCompleted();
      }
      expect(AdsService.interstitialAllowed(), isTrue);
      expect(AdsService.interstitialAllowed(gameId: 'mom_memory'), isFalse);
      AdsService.suppress();
      expect(AdsService.interstitialAllowed(), isFalse);
      AdsService.unsuppress();
      await Rewards.addCoins(3333);
      await AdsService.buyAdFree();
      expect(AdsService.interstitialAllowed(), isFalse);
    });

    test('mom memory levels do not count', () {
      Rewards.onLevelComplete('mom_memory', 'a');
      expect(AdsService.debugLevelsSinceInterstitial, 0);
      Rewards.onLevelComplete('sudoku', 'a');
      expect(AdsService.debugLevelsSinceInterstitial, 1);
    });
  });

  test('prices', () {
    expect(Prices.hint, 20);
    expect(Prices.undo, 10);
    expect(Prices.extraLife, 30);
    expect(Prices.unlockLevel, 150);
    expect(Prices.adFreePass, 3333);
    expect(Prices.of(OfferKind.extraLife), 30);
  });
}


