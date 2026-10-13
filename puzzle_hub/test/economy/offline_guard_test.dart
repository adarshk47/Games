import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ads/ads_service.dart';
import 'package:puzzle_hub/core/ads/offline_guard.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var now = DateTime(2026, 10, 13, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
    Rewards.reload();
    now = DateTime(2026, 10, 13, 12);
    OfflineGuard.clock = () => now;
    AdsService.clock = () => now;
    OfflineGuard.debugReset();
  });

  void secs(int n) {
    for (var i = 0; i < n; i++) {
      now = now.add(const Duration(seconds: 1));
      OfflineGuard.tick();
    }
  }

  test('blocks after 5 offline minutes; coming online unblocks', () {
    OfflineGuard.online = false;
    secs(299);
    expect(OfflineGuard.blocked.value, isFalse);
    secs(1);
    expect(OfflineGuard.blocked.value, isTrue);
    OfflineGuard.online = true;
    secs(1);
    expect(OfflineGuard.blocked.value, isFalse);
  });

  test('switching internet off right away blocks again (no reset)', () {
    OfflineGuard.online = false;
    secs(300);
    OfflineGuard.online = true;
    secs(10);
    OfflineGuard.online = false;
    secs(1);
    expect(OfflineGuard.blocked.value, isTrue);
  });

  test('2 minutes online resets the count', () {
    OfflineGuard.online = false;
    secs(300);
    OfflineGuard.online = true;
    secs(120);
    OfflineGuard.online = false;
    secs(5);
    expect(OfflineGuard.blocked.value, isFalse);
  });

  test('100 coins buy 5 more offline minutes', () async {
    await Rewards.addCoins(150, playSound: false);
    OfflineGuard.online = false;
    secs(300);
    expect(await OfflineGuard.buyWithCoins(), isTrue);
    expect(Rewards.balance, 50);
    secs(299);
    expect(OfflineGuard.blocked.value, isFalse);
    secs(2);
    expect(OfflineGuard.blocked.value, isTrue);
  });

  test('2 ads buy 5 more offline minutes; ad-free players are never blocked', () async {
    AdsService.rewardedOverride = (_) async => true;
    addTearDown(() => AdsService.rewardedOverride = null);
    OfflineGuard.online = false;
    secs(300);
    expect(await OfflineGuard.buyWithAds(), isTrue);
    expect(OfflineGuard.blocked.value, isFalse);

    await Storage.setInt(AdsService.kAdFreeUntil, now.add(const Duration(hours: 24)).millisecondsSinceEpoch);
    secs(1000);
    expect(OfflineGuard.blocked.value, isFalse);
  });
}
