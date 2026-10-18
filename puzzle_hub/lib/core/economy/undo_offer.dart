import 'package:flutter/material.dart';

import '../ads/ads_service.dart';
import '../i18n/i18n.dart';

/// "Go back one step" used by every game's Undo button: one rewarded ad (no
/// dialog, no coins) pays for [stepsPerAd] steps back on that game screen, so
/// only every third tap plays an ad. At most [maxSteps] steps in a row. Ad-free players go back for free; if no
/// ad can be shown at all (no network / no fill) the step is given anyway so
/// the button never feels broken. Closing the ad early gives nothing.
class UndoOffer {
  UndoOffer._();

  static const maxSteps = 3;

  /// Steps back that one watched ad pays for.
  static const stepsPerAd = 3;

  static bool _busy = false;
  static int _owner = 0;
  static int _chain = 0;
  static int _expectNext = -1;

  /// Paid steps left, valid only on the screen [_paidOwner].
  static int _paid = 0;
  static int _paidOwner = 0;

  @visibleForTesting
  static void debugReset() {
    _busy = false;
    _owner = 0;
    _chain = 0;
    _expectNext = -1;
    _paid = 0;
    _paidOwner = 0;
  }

  /// Returns the number of steps the game should undo now: 1, or 0.
  /// [available] is how many moves the game can still take back.
  static Future<int> ask(BuildContext context, {required int available}) async {
    if (available <= 0 || _busy) return 0;
    // Consecutive taps on the same screen (nothing played in between) count
    // towards the 3-step limit.
    final owner = identityHashCode(context);
    final continuing = owner == _owner && available == _expectNext;
    if (continuing && _chain >= maxSteps) {
      _snack(context, tr('undo.max'));
      return 0;
    }
    _busy = true;
    try {
      var ok = AdsService.adFree;
      if (!ok && _paidOwner == owner && _paid > 0) {
        _paid--;
        ok = true;
      }
      if (!ok) {
        ok = await AdsService.showRewarded(reason: 'undo');
        if (ok) {
          _paidOwner = owner;
          _paid = stepsPerAd - 1;
        } else if (AdsService.lastRewardedUnavailable) {
          ok = true;
        }
      }
      if (!ok) {
        if (context.mounted) _snack(context, tr('undo.watch_full'));
        return 0;
      }
      _owner = owner;
      _chain = continuing ? _chain + 1 : 1;
      _expectNext = available - 1;
      return 1;
    } finally {
      _busy = false;
    }
  }

  static void _snack(BuildContext context, String m) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }
}
