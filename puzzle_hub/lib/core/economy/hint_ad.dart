import 'package:flutter/material.dart';

import '../ads/ads_service.dart';
import '../i18n/i18n.dart';

/// "Show me a good next move": each hint plays one rewarded ad straight away.
/// Ad-free players get hints for free, and if no ad can be shown at all the
/// hint is given anyway. Closing the ad early gives nothing.
class HintAd {
  HintAd._();

  static bool _busy = false;

  static Future<bool> ask(BuildContext context) async {
    if (_busy) return false;
    if (AdsService.adFree) return true;
    _busy = true;
    try {
      final ok = await AdsService.showRewarded(reason: 'hint');
      if (ok || AdsService.lastRewardedUnavailable) return true;
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(tr('hint.watch_full')), duration: const Duration(seconds: 2)));
      }
      return false;
    } finally {
      _busy = false;
    }
  }
}
