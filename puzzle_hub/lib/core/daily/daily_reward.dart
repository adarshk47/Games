import 'package:flutter/foundation.dart';

import '../i18n/i18n.dart';
import '../rewards.dart';
import '../storage.dart';

/// Injectable clock so streak/date logic can be unit tested.
class DailyClock {
  DailyClock._();
  static DateTime Function() now = DateTime.now;

  static DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }
}

/// `2026-10-04` style calendar-day key.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDateKey(String? s) {
  if (s == null) return null;
  final p = s.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Whole calendar days from [a] to [b] (DST safe: compares UTC dates).
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Bumps on any daily/quest/achievement change so UIs can rebuild.
final ValueNotifier<int> dailyChanged = ValueNotifier<int>(0);
void notifyDailyChanged() => dailyChanged.value++;

/// Daily login reward with a 7 day cycle. Claim once per calendar day; missing
/// a day gently restarts the streak at day 1.
class DailyReward {
  DailyReward._();

  static const rewards = <int>[10, 15, 20, 25, 30, 40, 50];
  static const _kLast = 'daily.lastClaim';
  static const _kStreak = 'daily.streak';
  static const _kBest = 'daily.bestStreak';

  static DateTime? get lastClaim => parseDateKey(Storage.getString(_kLast));

  static bool get claimedToday {
    final l = lastClaim;
    return l != null && daysBetween(l, DailyClock.today()) == 0;
  }

  static bool get canClaim => !claimedToday;

  /// Consecutive days claimed that are still "alive" (claimed today or yesterday).
  static int get streak {
    final l = lastClaim;
    if (l == null) return 0;
    final gap = daysBetween(l, DailyClock.today());
    return (gap == 0 || gap == 1) ? Storage.getInt(_kStreak) : 0;
  }

  static int get bestStreak => Storage.getInt(_kBest);

  /// True when the user had a streak going but missed a day.
  static bool get streakBroken {
    final l = lastClaim;
    return l != null && daysBetween(l, DailyClock.today()) > 1 && Storage.getInt(_kStreak) > 1;
  }

  /// Streak value after today's claim (or current one if already claimed).
  static int get nextStreak => claimedToday ? Storage.getInt(_kStreak) : streak + 1;

  /// 1..7 position in the reward cycle for a given streak value.
  static int cycleDay(int streakValue) => streakValue <= 0 ? 1 : ((streakValue - 1) % 7) + 1;

  static int rewardFor(int streakValue) => rewards[cycleDay(streakValue) - 1];

  /// Cycle day shown on the card: today's (claimable or already claimed).
  static int get todayCycleDay => cycleDay(nextStreak);
  static int get todayReward => rewardFor(nextStreak);

  /// Claims today's reward. Returns the coins paid, or 0 if already claimed.
  static Future<int> claim() async {
    if (claimedToday) return 0;
    final s = nextStreak;
    final coins = rewardFor(s);
    await Storage.setString(_kLast, dateKey(DailyClock.today()));
    await Storage.setInt(_kStreak, s);
    if (s > bestStreak) await Storage.setInt(_kBest, s);
    await Rewards.addCoins(coins, label: tr('daily.day_reward_label', {'n': cycleDay(s)}));
    notifyDailyChanged();
    return coins;
  }
}
