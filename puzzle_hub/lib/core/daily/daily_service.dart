import 'dart:async';

import 'package:flutter/foundation.dart';

import '../achievements/achievements.dart';
import '../rewards.dart';
import 'daily_quests.dart';
import 'daily_reward.dart';

/// Wires [Rewards.events] into daily quests and achievements. Idempotent.
class DailyService {
  DailyService._();

  static StreamSubscription<RewardEvent>? _sub;
  static bool _evalPending = false;

  static void init() {
    if (_sub != null) return;
    _sub = Rewards.events.listen(_onEvent);
    dailyChanged.addListener(_scheduleEval);
  }

  static Future<void> _onEvent(RewardEvent e) async {
    try {
      await DailyQuests.onEvent(e);
      await Achievements.onEvent(e);
    } catch (err) {
      debugPrint('daily event failed: $err');
    }
  }

  /// Streak / quest changes may unlock badges (e.g. 7-day streak).
  static void _scheduleEval() {
    if (_evalPending) return;
    _evalPending = true;
    Future.microtask(() async {
      _evalPending = false;
      try {
        await Achievements.evaluate();
      } catch (err) {
        debugPrint('achievement eval failed: $err');
      }
    });
  }

  @visibleForTesting
  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    dailyChanged.removeListener(_scheduleEval);
  }
}
