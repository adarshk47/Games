import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google AdMob, used when Firestore `config/app.ads` is 'admob' (the AdMob
/// account is suspended until 22 Nov 2026 – keep 'unity' until then).
///
/// Release builds use the real units; debug and TEST_ADS builds (our own and
/// testers' phones) use Google's test units so testing never creates invalid
/// traffic.
class AdmobIds {
  AdmobIds._();
  static const _realRewarded = 'ca-app-pub-4083049312549641/4244584412';
  static const _realInterstitial = 'ca-app-pub-4083049312549641/7853848901';
  static const _realBanner = 'ca-app-pub-4083049312549641/2287581470';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';

  static const _real = kReleaseMode && !bool.fromEnvironment('TEST_ADS');
  static const rewarded = _real ? _realRewarded : _testRewarded;
  static const interstitial = _real ? _realInterstitial : _testInterstitial;
  static const banner = _real ? _realBanner : _testBanner;
}

/// Thin AdMob layer for AdsService: consent, init, load and show. Every call
/// is safe when AdMob is unavailable; it then returns false / null.
class AdmobAds {
  AdmobAds._();

  static RewardedAd? _rewarded;
  static InterstitialAd? _interstitial;

  static bool get rewardedReady => _rewarded != null;
  static bool get interstitialReady => _interstitial != null;

  /// UMP consent (GDPR) then SDK init. True when ads may be requested.
  static Future<bool> init() async {
    final ok = await _gatherConsent().timeout(const Duration(seconds: 30), onTimeout: () => false);
    if (!ok) return false;
    await MobileAds.instance.initialize().timeout(const Duration(seconds: 20));
    return true;
  }

  static Future<bool> _gatherConsent() async {
    try {
      final done = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => done.isCompleted ? null : done.complete(),
        (FormError e) => done.isCompleted ? null : done.completeError(e.message),
      );
      try {
        await done.future;
        await ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) {
          if (e != null) debugPrint('consent form: ${e.message}');
        });
      } catch (e) {
        debugPrint('consent update failed: $e');
      }
      // Even if the update failed, an earlier consent may allow ads.
      return await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('consent error: $e');
      return false;
    }
  }

  static void loadRewarded({required VoidCallback onLoaded, required VoidCallback onFailed}) {
    RewardedAd.load(
      adUnitId: AdmobIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          onLoaded();
        },
        onAdFailedToLoad: (e) {
          debugPrint('admob rewarded load failed: ${e.message}');
          onFailed();
        },
      ),
    );
  }

  static void loadInterstitial({required VoidCallback onDone}) {
    InterstitialAd.load(
      adUnitId: AdmobIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          onDone();
        },
        onAdFailedToLoad: (e) {
          debugPrint('admob interstitial load failed: ${e.message}');
          onDone();
        },
      ),
    );
  }

  /// Shows the loaded rewarded ad. Returns (shown, earned).
  static Future<(bool, bool)> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) return (false, false);
    _rewarded = null;
    var earned = false;
    var failed = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!closed.isCompleted) closed.complete();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        failed = true;
        a.dispose();
        if (!closed.isCompleted) closed.complete();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    await closed.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    return (!failed, earned);
  }

  /// Shows the loaded interstitial; [onClosed] runs when it is gone.
  static bool showInterstitial(VoidCallback onClosed) {
    final ad = _interstitial;
    if (ad == null) return false;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        onClosed();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        onClosed();
      },
    );
    ad.show().catchError((Object _) => onClosed());
    return true;
  }
}
