import 'package:flutter/material.dart';

import '../daily/daily_quests.dart';
import '../daily/daily_reward.dart';
import '../daily/daily_toast.dart';
import '../i18n/i18n.dart';
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
      Achievement(id: 'first_win', title: tr('ach.first_win.title'), desc: tr('ach.first_win.desc'), emoji: '🎉', color: Pal.gold, reward: 5, target: 1, progress: (s) => s.totalWins),
      Achievement(id: 'levels_10', title: tr('ach.levels_10.title'), desc: tr('ach.levels_n.desc', {'n': 10}), emoji: '🔟', color: _blue, reward: 10, target: 10, progress: (s) => s.totalLevels),
      Achievement(id: 'levels_50', title: tr('ach.levels_50.title'), desc: tr('ach.levels_n.desc', {'n': 50}), emoji: '🧠', color: _purple, reward: 20, target: 50, progress: (s) => s.totalLevels),
      Achievement(id: 'levels_100', title: tr('ach.levels_100.title'), desc: tr('ach.levels_n.desc', {'n': 100}), emoji: '💯', color: _pink, reward: 30, target: 100, progress: (s) => s.totalLevels),
      Achievement(id: 'levels_250', title: tr('ach.levels_250.title'), desc: tr('ach.levels_n.desc', {'n': 250}), emoji: '👑', color: Pal.gold, reward: 30, target: 250, progress: (s) => s.totalLevels),
      Achievement(id: 'plays_25', title: tr('ach.plays_25.title'), desc: tr('ach.plays_25.desc', {'n': 25}), emoji: '🎮', color: _green, reward: 10, target: 25, progress: (s) => s.totalPlays),
      Achievement(id: 'explorer', title: tr('ach.explorer.title'), desc: tr('quest.variety_n', {'n': 3}), emoji: '🧭', color: _blue, reward: 10, target: 3, progress: (s) => s.gamesPlayed),
      Achievement(id: 'all_games', title: tr('ach.all_games.title'), desc: tr('ach.all_games.desc'), emoji: '🌍', color: _green, reward: 20, target: titles.isEmpty ? 1 : titles.length, progress: (s) => s.gamesPlayed),
      Achievement(id: 'all_tiers', title: tr('ach.all_tiers.title'), desc: tr('ach.all_tiers.desc'), emoji: '🎚️', color: _purple, reward: 20, target: 4, progress: (s) => s.tiers.length),
      Achievement(id: 'hard_clear', title: tr('ach.hard_clear.title'), desc: tr('ach.hard_clear.desc'), emoji: '💪', color: _orange, reward: 10, target: 1, progress: (s) => s.hardClears),
      Achievement(id: 'extreme_clear', title: tr('ach.extreme_clear.title'), desc: tr('ach.extreme_clear.desc'), emoji: '🔥', color: _red, reward: 20, target: 1, progress: (s) => s.extremeClears),
      Achievement(id: 'extreme_10', title: tr('ach.extreme_10.title'), desc: tr('ach.extreme_10.desc', {'n': 10}), emoji: '😤', color: _red, reward: 30, target: 10, progress: (s) => s.extremeClears),
      Achievement(id: 'stars3_1', title: tr('ach.stars3_1.title'), desc: tr('ach.stars3_1.desc'), emoji: '⭐', color: Pal.gold, reward: 5, target: 1, progress: (s) => s.stars3),
      Achievement(id: 'stars3_25', title: tr('ach.stars3_25.title'), desc: tr('quest.stars_any', {'n': 25}), emoji: '🌟', color: Pal.gold, reward: 25, target: 25, progress: (s) => s.stars3),
      Achievement(id: 'streak_3', title: tr('ach.streak_3.title'), desc: tr('ach.streak_n.desc', {'n': 3}), emoji: '📅', color: _orange, reward: 10, target: 3, progress: (s) => s.bestStreak),
      Achievement(id: 'streak_7', title: tr('ach.streak_7.title'), desc: tr('ach.streak_n.desc', {'n': 7}), emoji: '🔥', color: _orange, reward: 25, target: 7, progress: (s) => s.bestStreak),
      Achievement(id: 'streak_30', title: tr('ach.streak_30.title'), desc: tr('ach.streak_n.desc', {'n': 30}), emoji: '🚀', color: _red, reward: 30, target: 30, progress: (s) => s.bestStreak),
      Achievement(id: 'challenge_1', title: tr('ach.challenge_1.title'), desc: tr('ach.challenge_1.desc'), emoji: '🏅', color: _green, reward: 10, target: 1, progress: (s) => s.challengeBest),
      Achievement(id: 'challenge_7', title: tr('ach.challenge_7.title'), desc: tr('ach.challenge_7.desc', {'n': 7}), emoji: '🗓️', color: _purple, reward: 30, target: 7, progress: (s) => s.challengeBest),
      Achievement(id: 'quests_25', title: tr('ach.quests_25.title'), desc: tr('ach.quests_25.desc', {'n': 25}), emoji: '📜', color: _blue, reward: 20, target: 25, progress: (s) => s.questsClaimed),
      Achievement(id: 'coins_1000', title: tr('ach.coins_1000.title'), desc: tr('ach.coins_n.desc', {'n': 1000}), emoji: '💰', color: Pal.gold, reward: 20, target: 1000, progress: (s) => s.coinsEarned),
      Achievement(id: 'coins_5000', title: tr('ach.coins_5000.title'), desc: tr('ach.coins_n.desc', {'n': 5000}), emoji: '💎', color: _blue, reward: 30, target: 5000, progress: (s) => s.coinsEarned),
      for (final e in titles.entries)
        if (e.key == 'game_2048')
          Achievement(id: 'master_${e.key}', title: tr('ach.master.title', {'game': e.value}), desc: tr('ach.master_score.desc', {'n': 10000, 'game': e.value}), emoji: '🏆', color: _pink, reward: 25, target: 10000, progress: (s) => s.best[e.key] ?? 0)
        else
          Achievement(id: 'master_${e.key}', title: tr('ach.master.title', {'game': e.value}), desc: tr('ach.master_wins.desc', {'n': 20, 'game': e.value}), emoji: '🏆', color: _pink, reward: 25, target: 20, progress: (s) {
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
          showDailyToast(emoji: a.emoji, title: tr('ach.unlocked_toast', {'name': a.title}), subtitle: a.desc, color: a.color);
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
