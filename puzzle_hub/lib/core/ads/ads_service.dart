/// AdMob wrapper (filled in by the economy work). Every method is safe to call
/// when ads are unavailable; it then simply returns false / does nothing.
class AdsService {
  AdsService._();

  static Future<void> init() async {}

  /// Shows a rewarded ad; returns true only if the user earned the reward.
  static Future<bool> showRewarded({String reason = ''}) async => false;

  /// Call after a level completes; shows an interstitial when the frequency rules allow.
  static void onLevelCompleted() {}

  /// True while the 24h ad-free pass is active.
  static bool get adFree => false;
}
