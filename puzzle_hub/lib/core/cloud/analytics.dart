import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../storage.dart';
import 'cloud_service.dart';

/// Firebase Analytics events, so ad campaigns can optimise for players who
/// actually play (not just installs). Never throws; does nothing offline or
/// when Firebase is not set up (tests).
class Analytics {
  Analytics._();

  static const _kFirstPlay = 'analytics.first_play';

  static void _log(String name, [Map<String, Object>? params]) {
    if (!CloudService.available) return;
    unawaited(
      FirebaseAnalytics.instance.logEvent(name: name, parameters: params).catchError(
            (Object e) => debugPrint('analytics $name: $e'),
          ),
    );
  }

  /// A game screen was opened. The first one ever also logs
  /// `first_game_played` (import it as a conversion in Google Ads).
  static void gameOpened(String gameId) {
    _log('game_open', {'game': gameId});
    if (!Storage.globalBool(_kFirstPlay)) {
      unawaited(Storage.setGlobalBool(_kFirstPlay, true));
      _log('first_game_played', {'game': gameId});
    }
  }

  static void levelComplete(String gameId, int stars) =>
      _log('level_complete', {'game': gameId, 'stars': stars});

  static void gameEnd(String gameId, {required bool won}) =>
      _log('game_end', {'game': gameId, 'won': won ? 1 : 0});
}
