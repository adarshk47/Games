import 'package:flutter/material.dart';

import '../daily/daily_quests.dart';
import '../daily/daily_reward.dart';
import '../daily/daily_toast.dart';
import '../rewards.dart';
import '../storage.dart';
import '../ui/palette.dart';

/// Snapshot of everything badges are evaluated from.
class AchStats {
  AchStats({
    required this.gameIds,
    required this.levels,
    required this.wins,
    required this.plays,
    required this.best,
    required this.tiers,
    required this.hardClears,
    required this.extremeClears,
    required this.stars3,
    required this.bestStreak,
    required this.challengeBest,
    required this.questsClaimed,
    required this.coinsEarned,
  });

  final List<String> gameIds;
  final Map<String, int> levels, wins, plays, best;
  final Set<String> tiers;
  final int hardClears, extremeClears, stars3, bestStreak, challengeBest, questsClaimed, coinsEarned;

  int _sum(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);
  int get totalLevels => _sum(levels);
  int get totalWins => _sum(wins);
  int get totalPlays => _sum(plays);
  int get gamesPlayed => gameIds.where((g) => (plays[g] ?? 0) > 0).length;

  static AchStats load() {
    final ids = DailyQuests.gameTitles().keys.toList();
    return AchStats(
      gameIds: ids,
      levels: {for (final g in ids) g: Rewards.levels(g)},
      wins: {for (final g in ids) g: Rewards.wins(g)},
      plays: {for (final g in ids) g: Rewards.plays(g)},
      best: {for (final g in ids) g: Rewards.best(g)},
      tiers: (Storage.getString(Achievements.kTiers) ?? '').split(',').where((s) => s.isNotEmpty).toSet(),
      hardClears: Storage.getInt(Achievements.kHard),
      extremeClears: Storage.getInt(Achievements.kExtreme),
      stars3: Storage.getInt(Achievements.kStars3),
      bestStreak: DailyReward.bestStreak,
      challengeBest: DailyQuests.challengeBest,
      questsClaimed: DailyQuests.claimedTotal,
      coinsEarned: Storage.getInt('coins.earned'),
    );
  }
}

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.desc,
    required this.emoji,
    required this.color,
    required this.reward,
    required this.target,
    required this.progress,
  });
  final String id;
  final String title;
  final String desc;
  final String emoji;
  final Color color;
  final int reward;
  final int target;
  final int Function(AchStats s) progress;

  int current(AchStats s) => progress(s).clamp(0, target);
  double fraction(AchStats s) => current(s) / target;
}

/// Tier of a level key ('easy' | 'medium' | 'hard' | 'extreme'), or null.
String? tierOfKey(String? key) {
  final k = (key ?? '').toLowerCase();
  for (final t in const ['extreme', 'hard', 'medium', 'easy']) {
    if (k.contains(t)) return t;
  }
  return null;
}

/// Data-driven badges. Unlocks pay a few coins and show a toast.
class Achievements {
  Achievements._();

  static const kUnlocked = 'ach.unlocked';
  static const kTiers = 'ach.tiers';
  static const kHard = 'ach.hard';
  static const kExtreme = 'ach.extreme';
  static const kStars3 = 'ach.stars3';

  static const _blue = Color(0xFF4DA8FF), _green = Color(0xFF2EE6A8), _purple = Color(0xFFB794FF);
  static const _pink = Color(0xFFFF6FB5), _orange = Color(0xFFFB923C), _red = Color(0xFFFF6B8A);

  static List<Achievement> all() {
    final titles = DailyQuests.gameTitles();
    return [
      Achievement(id: 'first_win', title: 'First Win', desc: 'Win any game or level', emoji: '🎉', color: Pal.gold, reward: 5, target: 1, progress: (s) => s.totalWins),
      Achievement(id: 'levels_10', title: 'Warming Up', desc: 'Complete 10 levels', emoji: '🔟', color: _blue, reward: 10, target: 10, progress: (s) => s.totalLevels),
      Achievement(id: 'levels_50', title: 'Puzzle Pro', desc: 'Complete 50 levels', emoji: '🧠', color: _purple, reward: 20, target: 50, progress: (s) => s.totalLevels),
      Achievement(id: 'levels_100', title: 'Centurion', desc: 'Complete 100 levels', emoji: '💯', color: _pink, reward: 30, target: 100, progress: (s) => s.totalLevels),
      Achievement(id: 'levels_250', title: 'Grandmaster', desc: 'Complete 250 levels', emoji: '👑', color: Pal.gold, reward: 30, target: 250, progress: (s) => s.totalLevels),
      Achievement(id: 'plays_25', title: 'Regular', desc: 'Play 25 times', emoji: '🎮', color: _green, reward: 10, target: 25, progress: (s) => s.totalPlays),
      Achievement(id: 'explorer', title: 'Explorer', desc: 'Play 3 different games', emoji: '🧭', color: _blue, reward: 10, target: 3, progress: (s) => s.gamesPlayed),
      Achievement(id: 'all_games', title: 'Globetrotter', desc: 'Play every game', emoji: '🌍', color: _green, reward: 20, target: titles.isEmpty ? 1 : titles.length, progress: (s) => s.gamesPlayed),
      Achievement(id: 'all_tiers', title: 'Tier Taster', desc: 'Clear Easy, Medium, Hard & Extreme levels', emoji: '🎚️', color: _purple, reward: 20, target: 4, progress: (s) => s.tiers.length),
      Achievement(id: 'hard_clear', title: 'Tough Cookie', desc: 'Clear a Hard level', emoji: '💪', color: _orange, reward: 10, target: 1, progress: (s) => s.hardClears),
      Achievement(id: 'extreme_clear', title: 'Extreme!', desc: 'Clear an Extreme level', emoji: '🔥', color: _red, reward: 20, target: 1, progress: (s) => s.extremeClears),
      Achievement(id: 'extreme_10', title: 'Fearless', desc: 'Clear 10 Extreme levels', emoji: '😤', color: _red, reward: 30, target: 10, progress: (s) => s.extremeClears),
      Achievement(id: 'stars3_1', title: 'Perfectionist', desc: 'Get 3 stars on a level', emoji: '⭐', color: Pal.gold, reward: 5, target: 1, progress: (s) => s.stars3),
      Achievement(id: 'stars3_25', title: 'Star Collector', desc: 'Get 3 stars on 25 levels', emoji: '🌟', color: Pal.gold, reward: 25, target: 25, progress: (s) => s.stars3),
      Achievement(id: 'streak_3', title: 'Habit Forming', desc: 'Reach a 3 day login streak', emoji: '📅', color: _orange, reward: 10, target: 3, progress: (s) => s.bestStreak),
      Achievement(id: 'streak_7', title: 'On Fire', desc: 'Reach a 7 day login streak', emoji: '🔥', color: _orange, reward: 25, target: 7, progress: (s) => s.bestStreak),
      Achievement(id: 'streak_30', title: 'Unstoppable', desc: 'Reach a 30 day login streak', emoji: '🚀', color: _red, reward: 30, target: 30, progress: (s) => s.bestStreak),
      Achievement(id: 'challenge_1', title: 'Daily Champion', desc: 'Complete all 3 daily quests', emoji: '🏅', color: _green, reward: 10, target: 1, progress: (s) => s.challengeBest),
      Achievement(id: 'challenge_7', title: 'Week Warrior', desc: 'Daily Challenge 7 days in a row', emoji: '🗓️', color: _purple, reward: 30, target: 7, progress: (s) => s.challengeBest),
      Achievement(id: 'quests_25', title: 'Quest Hunter', desc: 'Claim 25 daily quests', emoji: '📜', color: _blue, reward: 20, target: 25, progress: (s) => s.questsClaimed),
      Achievement(id: 'coins_1000', title: 'Coin Hoarder', desc: 'Earn 1000 coins', emoji: '💰', color: Pal.gold, reward: 20, target: 1000, progress: (s) => s.coinsEarned),
      Achievement(id: 'coins_5000', title: 'Treasure King', desc: 'Earn 5000 coins', emoji: '💎', color: _blue, reward: 30, target: 5000, progress: (s) => s.coinsEarned),
      for (final e in titles.entries)
        if (e.key == 'game_2048')
          Achievement(id: 'master_${e.key}', title: '${e.value} Master', desc: 'Score 10000+ in ${e.value}', emoji: '🏆', color: _pink, reward: 25, target: 10000, progress: (s) => s.best[e.key] ?? 0)
        else
          Achievement(id: 'master_${e.key}', title: '${e.value} Master', desc: 'Win 20 times in ${e.value}', emoji: '🏆', color: _pink, reward: 25, target: 20, progress: (s) {
            final l = s.levels[e.key] ?? 0, w = s.wins[e.key] ?? 0;
            return l > w ? l : w;
          }),
    ];
  }

  static Set<String> get unlocked => (Storage.getString(kUnlocked) ?? '').split(',').where((s) => s.isNotEmpty).toSet();
  static bool isUnlocked(String id) => unlocked.contains(id);

  /// Records event-derived counters, then evaluates.
  static Future<void> onEvent(RewardEvent e) async {
    if (e.type == 'level') {
      final t = tierOfKey(e.levelKey);
      if (t != null) {
        final tiers = (Storage.getString(kTiers) ?? '').split(',').where((s) => s.isNotEmpty).toSet();
        if (tiers.add(t)) await Storage.setString(kTiers, tiers.join(','));
        if (t == 'hard') await Storage.setInt(kHard, Storage.getInt(kHard) + 1);
        if (t == 'extreme') await Storage.setInt(kExtreme, Storage.getInt(kExtreme) + 1);
      }
      if (e.stars >= 3 && e.firstTime) await Storage.setInt(kStars3, Storage.getInt(kStars3) + 1);
    }
    await evaluate();
  }

  static bool _busy = false;

  /// Unlocks every badge whose target is reached. Returns the new unlocks.
  static Future<List<Achievement>> evaluate({bool reward = true}) async {
    if (_busy) return const [];
    _busy = true;
    final out = <Achievement>[];
    try {
      // Loop: coins from a badge can unlock a coins badge.
      for (var pass = 0; pass < 4; pass++) {
        final s = AchStats.load();
        final have = unlocked;
        final fresh = [for (final a in all()) if (!have.contains(a.id) && a.progress(s) >= a.target) a];
        if (fresh.isEmpty) break;
        have.addAll(fresh.map((a) => a.id));
        await Storage.setString(kUnlocked, have.join(','));
        for (final a in fresh) {
          out.add(a);
          showDailyToast(emoji: a.emoji, title: 'Badge unlocked: ${a.title}', subtitle: a.desc, color: a.color);
          if (reward) await Rewards.addCoins(a.reward, label: a.title);
        }
      }
    } finally {
      _busy = false;
    }
    if (out.isNotEmpty) notifyDailyChanged();
    return out;
  }
}
