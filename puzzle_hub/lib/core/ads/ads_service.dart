import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../rewards.dart';
import '../storage.dart';
import '../features.dart';
import 'coupon_service.dart';
import 'adfree_grant.dart';
import '../store/iap_service.dart';
import '../cloud/cloud_service.dart';

/// Unity Ads ids (game "Master G: Brain Puzzle Games").
///
/// Google AdMob was removed in 2.2 (the AdMob account was suspended for
/// invalid traffic, Oct 23 – Nov 22, 2026). All ads now come from Unity Ads.
class AdIds {
  AdIds._();
  static const gameId = '800409679';
  static const rewarded = 'BP_Rewarded_Android';
  static const interstitial = 'BP_Interstitial_Android';
  static const banner = 'BP_Banner_Android';

  /// Builds installed on our own / testers' phones must never show real ads
  /// (our own views and taps count as invalid traffic). Build them with
  ///   flutter build apk --release --dart-define=TEST_ADS=true
  /// Debug builds and TEST_ADS builds run Unity in test mode; only the Play
  /// Store AAB serves real ads.
  static const testAds = bool.fromEnvironment('TEST_ADS');
  static const testMode = !kReleaseMode || testAds;
}

/// Unity Ads wrapper. Every method is safe to call when ads are unavailable
/// (web, desktop, widget tests, no consent, plugin errors); it then simply
/// returns false / does nothing. Nothing here may ever throw or block startup.
class AdsService {
  /// Total rewarded ads fully watched by this account (shown in coin history).
  static const kAdsWatched = 'ads.watched';
  static int get adsWatched => Storage.getInt(kAdsWatched);

  AdsService._();

  // ---- Tunables --------------------------------------------------------------
  static const adFreePrice = 3333; // 24-hour pass (see AdFreePlan)
  static const adFreeDuration = Duration(hours: 24);
  static const levelsPerInterstitial = 2; // one after every 2 games (win or lose)
  static const minInterstitialGap = Duration(seconds: 45); // never back-to-back
  static const sessionGrace = Duration(seconds: 30);
  static const interstitialDelay = Duration(milliseconds: 1200);

  static const kAdFreeUntil = 'ads.adfree.until';

  /// Clock (overridable in tests).
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Test hook: when set, [showRewarded] uses it instead of Unity Ads.
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

  static bool _ready = false; // Unity Ads initialised and ads switched on
  static bool _rewardedReady = false;
  static bool _interstitialReady = false;
  static bool _loadingRewarded = false;
  static bool _loadingInterstitial = false;
  static bool _showing = false;
  static Completer<void>? _rewardedLoaded;

  /// Remote switch (Firestore `config/app.ads`): 'unity' (default) or 'off'.
  /// Lets the developer turn ads off for everyone without an app update.
  static const _kRemote = 'ads.remote';
  static String get remoteProvider => Storage.globalString(_kRemote) ?? 'unity';

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
  /// True when ad features may be shown (ads enabled, or a test override).
  /// Lets tests exercise ad rules while ads are switched off for release.
  @visibleForTesting
  static bool debugForceEnabled = false;

  static bool get featuresOn =>
      kAdsEnabled || debugForceEnabled || rewardedOverride != null;

  static Future<void> init() async {
    _sessionStart = clock();
    if (!kAdsEnabled || !_supportedPlatform) return;
    unawaited(
      _bootstrap().catchError((Object e) {
        debugPrint('ads init failed: $e');
      }),
    );
  }

  /// Reads the remote ads switch (cached for offline starts).
  static Future<void> _readRemote() async {
    if (!CloudService.available) return;
    try {
      final d = await FirebaseFirestore.instance.collection('config').doc('app').get().timeout(const Duration(seconds: 8));
      final v = d.data()?['ads'];
      if (v is String) await Storage.setGlobalString(_kRemote, v);
    } catch (e) {
      debugPrint('ads remote switch: $e');
    }
  }

  static Future<void> _bootstrap() async {
    await _readRemote();
    if (remoteProvider == 'off') return;
    final done = Completer<bool>();
    await UnityAds.init(
      gameId: AdIds.gameId,
      testMode: AdIds.testMode,
      onComplete: () => done.isCompleted ? null : done.complete(true),
      onFailed: (e, m) {
        debugPrint('unity init failed: $e $m');
        if (!done.isCompleted) done.complete(false);
      },
    );
    if (!await done.future.timeout(const Duration(seconds: 30), onTimeout: () => false)) return;
    _ready = true;
    _notify();
    _loadRewarded();
    _loadInterstitial();
  }

  // ---- Loading ---------------------------------------------------------------

  static void _loadRewarded() {
    if (!_ready || _rewardedReady || _loadingRewarded) return;
    _loadingRewarded = true;
    _rewardedLoaded ??= Completer<void>();
    try {
      UnityAds.load(
        placementId: AdIds.rewarded,
        onComplete: (_) {
          _loadingRewarded = false;
          _rewardedReady = true;
          _completeRewardedWait();
          _notify();
        },
        onFailed: (_, e, m) {
          _loadingRewarded = false;
          debugPrint('rewarded load failed: $e $m');
          _completeRewardedWait();
        },
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
    if (!_ready || adFree || _interstitialReady || _loadingInterstitial) {
      return;
    }
    _loadingInterstitial = true;
    try {
      UnityAds.load(
        placementId: AdIds.interstitial,
        onComplete: (_) {
          _loadingInterstitial = false;
          _interstitialReady = true;
        },
        onFailed: (_, e, m) {
          _loadingInterstitial = false;
          debugPrint('interstitial load failed: $e $m');
        },
      );
    } catch (_) {
      _loadingInterstitial = false;
    }
  }

  // ---- Rewarded --------------------------------------------------------------

  /// After [showRewarded] returned false: true when no ad could be shown at
  /// all (not loaded, no network), false when the player closed it early.
  static bool lastRewardedUnavailable = false;

  /// Shows a rewarded ad; returns true only if the user earned the reward.
  static Future<bool> showRewarded({String reason = ''}) async {
    lastRewardedUnavailable = false;
    final o = rewardedOverride;
    if (o != null) return o(reason);
    if (!kAdsEnabled || !_ready || _showing) {
      lastRewardedUnavailable = !_showing;
      return false;
    }
    try {
      if (!_rewardedReady) {
        _loadRewarded();
        final wait = _rewardedLoaded;
        if (wait != null) {
          await wait.future.timeout(
            const Duration(seconds: 8),
            onTimeout: () {},
          );
        }
      }
      if (!_rewardedReady) {
        lastRewardedUnavailable = true; // no fill / no network
        return false;
      }
      _rewardedReady = false;
      _showing = true;
      var earned = false;
      final closed = Completer<void>();
      await UnityAds.showVideoAd(
        placementId: AdIds.rewarded,
        onComplete: (_) {
          earned = true;
          if (!closed.isCompleted) closed.complete();
        },
        onSkipped: (_) {
          if (!closed.isCompleted) closed.complete();
        },
        onFailed: (_, e, m) {
          lastRewardedUnavailable = true;
          if (!closed.isCompleted) closed.complete();
        },
      );
      await closed.future.timeout(const Duration(minutes: 3), onTimeout: () {});
      _showing = false;
      _loadRewarded();
      _notify();
      if (earned) Storage.setInt(kAdsWatched, Storage.getInt(kAdsWatched) + 1);
      return earned;
    } catch (e) {
      debugPrint('rewarded show failed: $e');
      lastRewardedUnavailable = true;
      _showing = false;
      _loadRewarded();
      return false;
    }
  }

  // ---- Ad-free pass ----------------------------------------------------------

  static DateTime? get adFreeUntil {
    final ms = Storage.getInt(kAdFreeUntil);
    return ms <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// True while the 24h ad-free pass is active.
  static bool get adFree {
    try {
      if (CouponService.noAds.value || AdFreeGrant.active || IapService.active) return true;
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

  /// Buys (or extends) an ad-free pass. False if unaffordable.
  static Future<bool> buyAdFree([AdFreePlan plan = AdFreePlan.day]) async {
    if (!await Rewards.spend(plan.price, reason: 'adfree')) return false;
    final now = clock();
    final base = adFree ? adFreeUntil! : now;
    await Storage.setInt(
      kAdFreeUntil,
      base.add(plan.duration).millisecondsSinceEpoch,
    );
    _notify();
    return true;
  }

  // ---- Interstitial ----------------------------------------------------------

  /// Pure frequency rules (no platform checks), exposed for tests.
  @visibleForTesting
  static bool interstitialAllowed({String? gameId}) {
    if (adFree || suppressed > 0) return false;
    if (gameId != null && _neverInterstitial.contains(gameId)) return false;
    final now = clock();
    if (_levelsSinceInterstitial < levelsPerInterstitial) return false;
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
    if (!featuresOn) return;
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
      if (_showing || !interstitialAllowed(gameId: gameId) || !_routeIdle) {
        return;
      }
      if (!_interstitialReady) {
        _loadInterstitial();
        return;
      }
      _interstitialReady = false;
      _showing = true;
      debugMarkInterstitialShown();
      UnityAds.showVideoAd(
        placementId: AdIds.interstitial,
        onComplete: (_) {
          _showing = false;
          _loadInterstitial();
        },
        onSkipped: (_) {
          _showing = false;
          _loadInterstitial();
        },
        onFailed: (_, e, m) {
          _showing = false;
          _loadInterstitial();
        },
      ).catchError((Object _) {
        _showing = false;
      });
    } catch (e) {
      _showing = false;
      debugPrint('interstitial show failed: $e');
    }
  }
}

/// Ad-free passes sold for coins.
enum AdFreePlan {
  day(3333, Duration(hours: 24)),
  week(11111, Duration(days: 7)),
  month(55555, Duration(days: 30));

  const AdFreePlan(this.price, this.duration);
  final int price;
  final Duration duration;
}
