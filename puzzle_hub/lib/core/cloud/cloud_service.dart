import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../i18n/i18n.dart';
import 'cloud_auth.dart';
import 'leaderboard_service.dart';
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
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      // No options: uses the google-services.json resources. Missing file =>
      // throws => we stay offline.
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
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
    } catch (e) {
      debugPrint('cloud start failed: $e');
    }
  }
}
