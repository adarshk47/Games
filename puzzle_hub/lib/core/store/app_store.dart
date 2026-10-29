import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/account_service.dart';
import '../app_info.dart';
import '../storage.dart';

/// Play Store helpers: in-app update check, the occasional "rate us" prompt
/// after a win, and the Profile "Rate us" / "Send feedback" actions.
class AppStore {
  AppStore._();

  static const feedbackEmail = 'aiforsmart@gmail.com';

  static const _kWins = 'review.wins';
  static const _kLastAsk = 'review.last_ask';

  /// Wins before the first prompt, chance per later win, and minimum gap.
  static const winsBeforeAsking = 3;
  static const askChance = 0.25;
  static const minGap = Duration(days: 7);

  @visibleForTesting
  static Random random = Random();

  /// Test hook: replaces the Play review dialog.
  @visibleForTesting
  static Future<void> Function()? reviewOverride;

  static bool get _onAndroid {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// True while a newer Play version exists and has not been installed:
  /// the app shows a blocking "Update required" screen (no playing).
  static final ValueNotifier<bool> updateRequired = ValueNotifier(false);

  /// On start: if Play has a newer version, updating is mandatory. Play's
  /// full-screen update runs first; if the player backs out of it, the app
  /// stays on the "Update required" screen.
  static Future<void> checkForUpdate() async {
    if (!_onAndroid) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable &&
          info.updateAvailability != UpdateAvailability.developerTriggeredUpdateInProgress) {
        updateRequired.value = false;
        return;
      }
      updateRequired.value = true;
      await updateNow();
    } catch (e) {
      debugPrint('update check failed: $e'); // e.g. not installed from Play
    }
  }

  /// Starts Play's full-screen update (or opens the Play Store page).
  static Future<void> updateNow() async {
    try {
      final r = await InAppUpdate.performImmediateUpdate();
      if (r == AppUpdateResult.success) updateRequired.value = false;
    } catch (e) {
      debugPrint('immediate update failed: $e');
      await launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=com.memorypuzzle.app'), mode: LaunchMode.externalApplication);
    }
  }

  /// Call after every win. Asks for a rating now and then: never before
  /// [winsBeforeAsking] wins, then with [askChance] per win, at most once per
  /// [minGap]. Play itself may also decide not to show the dialog.
  static Future<bool> onWin() async {
    final wins = Storage.getInt(_kWins) + 1;
    await Storage.setInt(_kWins, wins);
    if (wins < winsBeforeAsking) return false;
    final last = Storage.getInt(_kLastAsk);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last > 0 && now - last < minGap.inMilliseconds) return false;
    if (random.nextDouble() >= askChance) return false;
    await Storage.setInt(_kLastAsk, now);
    final o = reviewOverride;
    if (o != null) {
      await o();
      return true;
    }
    if (!_onAndroid) return false;
    // Let the win dialog appear first.
    await Future<void>.delayed(const Duration(seconds: 2));
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } catch (e) {
      debugPrint('review prompt failed: $e');
    }
    return true;
  }

  /// Profile "Rate us": opens the Play Store page.
  /// Always the real Play listing (test builds have other package names, so
  /// InAppReview.openStoreListing() would open a "not found" page there).
  static Future<void> openStorePage() async {
    const id = 'com.memorypuzzle.app';
    try {
      if (await launchUrl(Uri.parse('market://details?id=$id'), mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    await launchUrl(
      Uri.parse('https://play.google.com/store/apps/details?id=$id'),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Profile "Send feedback": an email to the developer.
  static Future<void> sendFeedback() async {
    final a = AccountService.I;
    final body = '''Hi,

My feedback about ${AppInfo.name}:


---
Name: ${a.name}
App version: ${AppInfo.version}''';
    final uri = Uri(
      scheme: 'mailto',
      path: feedbackEmail,
      query: 'subject=${Uri.encodeComponent('${AppInfo.name} feedback (v${AppInfo.version})')}'
          '&body=${Uri.encodeComponent(body)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('feedback mail failed: $e');
    }
  }
}
