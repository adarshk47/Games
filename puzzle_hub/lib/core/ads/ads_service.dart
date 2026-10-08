import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../i18n/i18n.dart';
import '../rewards.dart';
import '../storage.dart';

/// Ad unit ids.
///
/// !!! REPLACE BEFORE RELEASE !!!
/// These are Google's official TEST ad unit ids. Swap them (and the AdMob app
/// id in AndroidManifest.xml) for the real ids from the AdMob console.
class AdIds {
  AdIds._();
  // TODO(release): replace with the real rewarded ad unit id.
  static const rewarded = 'ca-app-pub-3940256099942544/5224354917';
  // TODO(release): replace with the real interstitial ad unit id.
  static const interstitial = 'ca-app-pub-3940256099942544/1033173712';
}

/// AdMob wrapper. Every method is safe to call when ads are unavailable
/// (web, desktop, widget tests, no consent, plugin errors); it then simply
/// returns false / does nothing. Nothing here may ever throw or block startup.
class AdsService {
  /// Total rewarded ads fully watched by this account (shown in coin history).
  static const kAdsWatched = 'ads.watched';
  static int get adsWatched => Storage.getInt(kAdsWatched);

  AdsService._();

  // ---- Tunables --------------------------------------------------------------
  static const rewardedCoins = 25;
  static const dailyRewardedCap = 10;
  static const adFreePrice = 3000;
  static const adFreeDuration = Duration(hours: 24);
  static const levelsPerInterstitial = 3;
  static const minInterstitialGap = Duration(minutes: 3);
  static const sessionGrace = Duration(minutes: 2);
  static const interstitialDelay = Duration(milliseconds: 1200);

  static const kAdFreeUntil = 'ads.adfree.until';
  static const _kRewardDay = 'ads.rewarded.day';
  static const _kRewardCount = 'ads.rewarded.count';

  /// Clock (overridable in tests).
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Test hook: when set, [showRewarded] uses it instead of AdMob.
  @visibleForTesting
  static Future<bool> Function(String reason)? rewardedOverride;

  /// Screens that must never be interrupted (e.g. Mom Memory) increment this
  /// in initState and decrement in dispose. While > 0 no interstitial shows.
  static int suppressed = 0;
  static void suppress() => suppressed++;
  static void unsuppress() => suppressed = suppressed > 0 ? suppressed - 1 : 0;

  /// Games that never get interstitials.
  static const _neverInterstitial = {'mom_memory'};

  static DateTime _sessionStart = DateTime.now();
  static DateTime? _lastInterstitial;
  static int _levelsSinceInterstitial = 0;

  static bool _ready = false; // MobileAds initialised and consent allows ads
  static RewardedAd? _rewarded;
  static InterstitialAd? _interstitial;
  static bool _loadingRewarded = false;
  static bool _loadingInterstitial = false;
  static bool _showing = false;
  static Completer<void>? _rewardedLoaded;

  /// Fires when ad availability / ad-free / daily counts change (for UI).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _notify() => changes.value++;

  /// True when ads can actually be shown on this device.
  static bool get available => _ready;

  static bool get _supportedPlatform {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Starts consent + SDK init in the background. Returns immediately.
  static Future<void> init() async {
    _sessionStart = clock();
    if (!_supportedPlatform) return;
    unawaited(_bootstrap().catchError((Object e) {
      debugPrint('ads init failed: $e');
      _ready = false;
    }));
  }

  static Future<void> _bootstrap() async {
    final consentOk = await _gatherConsent().timeout(const Duration(seconds: 30), onTimeout: () => false);
    if (!consentOk) return;
    await MobileAds.instance.initialize().timeout(const Duration(seconds: 20));
    _ready = true;
    _notify();
    _loadRewarded();
    _loadInterstitial();
  }

  /// UMP consent. Returns whether ads may be requested.
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
      // Even if the update failed, a previous session's consent may allow ads.
      return await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('consent error: $e');
      return false;
    }
  }

  // ---- Loading ---------------------------------------------------------------

  static void _loadRewarded() {
    if (!_ready || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    _rewardedLoaded ??= Completer<void>();
    try {
      RewardedAd.load(
        adUnitId: AdIds.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _loadingRewarded = false;
            _rewarded = ad;
            _completeRewardedWait();
            _notify();
          },
          onAdFailedToLoad: (e) {
            _loadingRewarded = false;
            debugPrint('rewarded load failed: ${e.message}');
            _completeRewardedWait();
          },
        ),
      );
    } catch (e) {
      _loadingRewarded = false;
      _completeRewardedWait();
    }
  }

  static void _completeRewardedWait() {
    final c = _rewardedLoaded;
    _rewardedLoaded = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  static void _loadInterstitial() {
    if (!_ready || adFree || _interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    try {
      InterstitialAd.load(
        adUnitId: AdIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _loadingInterstitial = false;
            _interstitial = ad;
          },
          onAdFailedToLoad: (e) {
            _loadingInterstitial = false;
            debugPrint('interstitial load failed: ${e.message}');
          },
        ),
      );
    } catch (_) {
      _loadingInterstitial = false;
    }
  }

  // ---- Rewarded --------------------------------------------------------------

  /// Shows a rewarded ad; returns true only if the user earned the reward.
  static Future<bool> showRewarded({String reason = ''}) async {
    final o = rewardedOverride;
    if (o != null) return o(reason);
    if (!_ready || _showing) return false;
    try {
      if (_rewarded == null) {
        _loadRewarded();
        final wait = _rewardedLoaded;
        if (wait != null) await wait.future.timeout(const Duration(seconds: 8), onTimeout: () {});
      }
      final ad = _rewarded;
      if (ad == null) return false;
      _rewarded = null;
      _showing = true;
      var earned = false;
      final closed = Completer<void>();
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          if (!closed.isCompleted) closed.complete();
        },
        onAdFailedToShowFullScreenContent: (a, e) {
          a.dispose();
          if (!closed.isCompleted) closed.complete();
        },
      );
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
      await closed.future.timeout(const Duration(minutes: 3), onTimeout: () {});
      _showing = false;
      _loadRewarded();
      _notify();
      if (earned) Storage.setInt(kAdsWatched, Storage.getInt(kAdsWatched) + 1);
      return earned;
    } catch (e) {
      debugPrint('rewarded show failed: $e');
      _showing = false;
      _loadRewarded();
      return false;
    }
  }

  static String _today() {
    final d = clock();
    return '${d.year}-${d.month}-${d.day}';
  }

  /// Coin-reward ads watched today.
  static int get rewardedToday => Storage.getString(_kRewardDay) == _today() ? Storage.getInt(_kRewardCount) : 0;

  /// Coin-reward ads still allowed today.
  static int get rewardedRemainingToday => (dailyRewardedCap - rewardedToday).clamp(0, dailyRewardedCap);

  /// The shop's "Watch ad: +25 coins" action. Returns coins granted (0 if the
  /// daily cap is reached or the ad was not completed).
  static Future<int> watchAdForCoins() async {
    if (rewardedRemainingToday <= 0) return 0;
    final ok = await showRewarded(reason: 'coins');
    if (!ok) return 0;
    final today = _today();
    final count = rewardedToday + 1;
    await Storage.setString(_kRewardDay, today);
    await Storage.setInt(_kRewardCount, count);
    await Rewards.addCoins(rewardedCoins, label: tr('ads.reward_label'), source: 'ad');
    _notify();
    return rewardedCoins;
  }

  // ---- Ad-free pass ----------------------------------------------------------

  static DateTime? get adFreeUntil {
    final ms = Storage.getInt(kAdFreeUntil);
    return ms <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// True while the 24h ad-free pass is active.
  static bool get adFree {
    try {
      final u = adFreeUntil;
      return u != null && u.isAfter(clock());
    } catch (_) {
      return false; // Storage not initialised
    }
  }

  /// Time left on the pass (zero when inactive).
  static Duration get adFreeRemaining {
    final u = adFreeUntil;
    if (u == null) return Duration.zero;
    final d = u.difference(clock());
    return d.isNegative ? Duration.zero : d;
  }

  /// Buys (or extends) the pass for [adFreePrice] coins. False if unaffordable.
  static Future<bool> buyAdFree() async {
    if (!await Rewards.spend(adFreePrice, reason: 'adfree')) return false;
    final now = clock();
    final base = adFree ? adFreeUntil! : now;
    await Storage.setInt(kAdFreeUntil, base.add(adFreeDuration).millisecondsSinceEpoch);
    try {
      _interstitial?.dispose();
    } catch (_) {}
    _interstitial = null;
    _notify();
    return true;
  }

  // ---- Interstitial ----------------------------------------------------------

  /// Pure frequency rules (no platform checks), exposed for tests.
  @visibleForTesting
  static bool interstitialAllowed({String? gameId}) {
    if (adFree || suppressed > 0) return false;
    if (gameId != null && _neverInterstitial.contains(gameId)) return false;
    if (_levelsSinceInterstitial < levelsPerInterstitial) return false;
    final now = clock();
    if (now.difference(_sessionStart) < sessionGrace) return false;
    final last = _lastInterstitial;
    if (last != null && now.difference(last) < minInterstitialGap) return false;
    return true;
  }

  @visibleForTesting
  static void debugReset({DateTime? sessionStart}) {
    _sessionStart = sessionStart ?? clock();
    _lastInterstitial = null;
    _levelsSinceInterstitial = 0;
    suppressed = 0;
  }

  @visibleForTesting
  static int get debugLevelsSinceInterstitial => _levelsSinceInterstitial;

  /// Marks an interstitial as shown (resets the counters).
  @visibleForTesting
  static void debugMarkInterstitialShown() {
    _lastInterstitial = clock();
    _levelsSinceInterstitial = 0;
  }

  static bool get _routeIdle {
    try {
      final nav = Rewards.navKey.currentState;
      if (nav != null && nav.userGestureInProgress) return false;
      final s = WidgetsBinding.instance.lifecycleState;
      return s == null || s == AppLifecycleState.resumed;
    } catch (_) {
      return false;
    }
  }

  /// Call after a level completes; shows an interstitial when the frequency
  /// rules allow, ~1.2s later so the win dialog appears first.
  static void onLevelCompleted({String? gameId}) {
    try {
      if (gameId != null && _neverInterstitial.contains(gameId)) return;
      _levelsSinceInterstitial++;
      if (!_ready || !interstitialAllowed(gameId: gameId)) {
        _loadInterstitial();
        return;
      }
      Timer(interstitialDelay, () => _showInterstitial(gameId));
    } catch (e) {
      debugPrint('interstitial check failed: $e');
    }
  }

  static void _showInterstitial(String? gameId) {
    try {
      if (_showing || !interstitialAllowed(gameId: gameId) || !_routeIdle) return;
      final ad = _interstitial;
      if (ad == null) {
        _loadInterstitial();
        return;
      }
      _interstitial = null;
      _showing = true;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          _showing = false;
          _loadInterstitial();
        },
        onAdFailedToShowFullScreenContent: (a, e) {
          a.dispose();
          _showing = false;
          _loadInterstitial();
        },
      );
      debugMarkInterstitialShown();
      ad.show().catchError((Object _) {
        _showing = false;
      });
    } catch (e) {
      _showing = false;
      debugPrint('interstitial show failed: $e');
    }
  }
}
