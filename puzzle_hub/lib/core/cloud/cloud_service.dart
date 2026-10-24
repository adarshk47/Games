import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../ads/adfree_grant.dart';
import '../ads/coupon_service.dart';
import '../store/iap_service.dart';
import '../i18n/i18n.dart';
import 'cloud_auth.dart';
import 'web_firebase_options.dart';
import 'leaderboard_service.dart';
import 'online_service.dart';
import 'referral_service.dart';
import 'sync_service.dart';

/// Firebase (auth + Firestore sync). Must work without google-services.json:
/// then [available] is false and the app stays fully local (cloud UI shows
/// "Cloud setup pending").
class CloudService {
  CloudService._();

  static bool available = false;

  /// Friendly text for UI when [available] is false.
  static const pendingMessage = 'Cloud setup pending. Your progress is saved on this phone.';

  /// [pendingMessage] in the current app language (prefer this in UI).
  static String get pendingText => tr('cloud.pending', const {}, pendingMessage);

  static Future<void> init() async {
    // The install referrer works without Firebase; read it once on first run
    // (in the background so it never delays app start).
    unawaited(ReferralService.I.captureInstallReferrer());
    if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      // Android: no options = the google-services.json resources (missing
      // file => throws => we stay offline). Web: the MasterG web app config.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: kIsWeb ? webFirebaseOptions : null);
      }
      available = true;
    } catch (e) {
      debugPrint('Firebase unavailable: $e');
      available = false;
      return;
    }
    try {
      CloudAuth.I.start();
      SyncService.I.start();
      LeaderboardService.I.start();
      ReferralService.I.start();
      OnlineService.I.start();
      // Ad-free grants and coupons are per account: re-check them as soon as
      // the signed-in user is known (at start the user arrives a moment after
      // init, so a revoked grant would otherwise stay cached until the Shop
      // is opened).
      String? lastUid;
      CloudAuth.I.user.addListener(() {
        final uid = CloudAuth.I.user.value?.uid;
        if (uid == lastUid) return;
        lastUid = uid;
        unawaited(AdFreeGrant.refresh());
        unawaited(CouponService.refresh());
        unawaited(IapService.I.checkRevoked());
      });
    } catch (e) {
      debugPrint('cloud start failed: $e');
    }
  }
}
