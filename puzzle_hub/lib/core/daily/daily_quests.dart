import 'dart:convert';
import 'dart:math';

import '../../games/registry.dart';
import '../i18n/i18n.dart';
import '../rewards.dart';
import '../storage.dart';
import 'daily_reward.dart';
import 'daily_toast.dart';

/// One kind of daily quest. [distinctGames] quests count different game ids
/// among matching events instead of the number of events.
class QuestTemplate {
  const QuestTemplate({
    required this.id,
    required this.category,
    required this.title,
    required this.emoji,
    required this.target,
    required this.reward,
    required this.matches,
    this.distinctGames = false,
  });
  final String id;
  final String category;
  final String title;
  final String emoji;
  final int target;
  final int reward;
  final bool Function(RewardEvent e) matches;
  final bool distinctGames;
}

/// A quest for today with its progress.
class DailyQuest {
  const DailyQuest(this.template, this.progress, this.claimed);
  final QuestTemplate template;
  final int progress;
  final bool claimed;
  bool get completed => progress >= template.target;
  bool get claimable => completed && !claimed;
  double get fraction => (progress / template.target).clamp(0, 1).toDouble();
}

bool _isHardKey(String? k) {
  final s = (k ?? '').toLowerCase();
  return s.contains('hard') || s.contains('extreme');
}

/// Builds the template pool, only referencing games in [titles] (id -> title).
List<QuestTemplate> questTemplates(Map<String, String> titles) {
  final t = <QuestTemplate>[
    QuestTemplate(
        id: 'levels_3', category: 'levels', title: tr('quest.levels_n', {'n': 3}), emoji: '🧩',
        target: 3, reward: 15, matches: (e) => e.type == 'level'),
    QuestTemplate(
        id: 'levels_5', category: 'levels', title: tr('quest.levels_n', {'n': 5}), emoji: '🚀',
        target: 5, reward: 25, matches: (e) => e.type == 'level'),
    QuestTemplate(
        id: 'variety_2', category: 'variety', title: tr('quest.variety_n', {'n': 2}), emoji: '🎮',
        target: 2, reward: 10, matches: (_) => true, distinctGames: true),
    QuestTemplate(
        id: 'variety_3', category: 'variety', title: tr('quest.variety_n', {'n': 3}), emoji: '🌈',
        target: 3, reward: 20, matches: (_) => true, distinctGames: true),
    QuestTemplate(
        id: 'hard_clear', category: 'hard', title: tr('quest.hard_clear'), emoji: '💪',
        target: 1, reward: 25, matches: (e) => e.type == 'level' && _isHardKey(e.levelKey)),
    QuestTemplate(
        id: 'stars_any', category: 'stars', title: tr('quest.stars_any', {'n': 2}), emoji: '🌟',
        target: 2, reward: 20, matches: (e) => e.type == 'level' && e.stars >= 3),
  ];
  const winGames = ['sudoku', 'ball_sort', 'maze_escape', 'arrows', 'arrow_maze', 'minesweeper', 'flow_pairs', 'sliding_puzzle', 'block_puzzle'];
  for (final g in winGames) {
    final name = titles[g];
    if (name == null) continue;
    t.add(QuestTemplate(
        id: 'win_$g', category: 'win', title: tr('quest.win_game', {'game': name}), emoji: '🏆',
        target: 1, reward: 15, matches: (e) => e.gameId == g && e.won));
  }
  const starGames = ['arrow_maze', 'arrows', 'ball_sort', 'maze_escape', 'memory_boost', 'flow_pairs', 'sliding_puzzle'];
  for (final g in starGames) {
    final name = titles[g];
    if (name == null) continue;
    t.add(QuestTemplate(
        id: 'stars_$g', category: 'stars', title: tr('quest.stars_game', {'game': name}), emoji: '⭐',
        target: 1, reward: 20, matches: (e) => e.gameId == g && e.type == 'level' && e.stars >= 3));
  }
  if (titles.containsKey('game_2048')) {
    t.add(QuestTemplate(
        id: 'score_2048', category: 'score', title: tr('quest.score_game', {'n': 1000, 'game': titles['game_2048']}), emoji: '🔢',
        target: 1, reward: 20, matches: (e) => e.gameId == 'game_2048' && (e.score ?? 0) >= 1000));
  }
  if (titles.containsKey('focus_color')) {
    t.add(QuestTemplate(
        id: 'run_focus', category: 'score', title: tr('quest.runs_game', {'n': 2, 'game': titles['focus_color']}), emoji: '🎯',
        target: 2, reward: 15, matches: (e) => e.gameId == 'focus_color' && e.type == 'run'));
  }
  return t;
}

int _seed(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Deterministically picks 3 quests (different categories) for [date].
List<QuestTemplate> pickQuests(DateTime date, Map<String, String> titles) {
  final pool = questTemplates(titles);
  final byCat = <String, List<QuestTemplate>>{};
  for (final q in pool) {
    byCat.putIfAbsent(q.category, () => []).add(q);
  }
  final rng = Random(_seed(date));
  final cats = byCat.keys.toList()..sort();
  cats.shuffle(rng);
  return [for (final c in cats.take(3)) byCat[c]![rng.nextInt(byCat[c]!.length)]];
}

/// Today's 3 quests, their progress (persisted per date), claims, the all-done
/// bonus and the Daily Challenge streak (days where all 3 were completed).
class DailyQuests {
  DailyQuests._();

  static const bonusCoins = 40;
  static const _kState = 'quests.state';
  static const _kChLast = 'daily.challenge.last';
  static const _kChStreak = 'daily.challenge.streak';
  static const _kChBest = 'daily.challenge.best';
  static const kClaimedTotal = 'quests.claimedTotal';

  /// Enabled games (id -> title). Overridable in tests.
  static Map<String, String> Function() gameTitles = () => {for (final g in games) g.id: g.title};

  static Map<String, dynamic> _load() {
    final today = dateKey(DailyClock.today());
    Map<String, dynamic>? s;
    try {
      final raw = Storage.getString(_kState);
      if (raw != null) s = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
    if (s == null || s['date'] != today) {
      final titles = gameTitles();
      s = {
        'date': today,
        'ids': [for (final q in pickQuests(DailyClock.today(), titles)) q.id],
        'p': <String, dynamic>{},
        'g': <String, dynamic>{},
        'c': <dynamic>[],
        'b': false,
        'done': false,
      };
    }
    return s;
  }

  static Future<void> _save(Map<String, dynamic> s) => Storage.setString(_kState, jsonEncode(s));

  static Map<String, QuestTemplate> _templates() => {for (final t in questTemplates(gameTitles())) t.id: t};

  static List<DailyQuest> today() {
    final s = _load();
    final all = _templates();
    final p = (s['p'] as Map).cast<String, dynamic>();
    final c = (s['c'] as List).cast<String>();
    return [
      for (final id in (s['ids'] as List).cast<String>())
        if (all[id] != null) DailyQuest(all[id]!, (p[id] as int?) ?? 0, c.contains(id)),
    ];
  }

  static bool get allCompleted {
    final q = today();
    return q.isNotEmpty && q.every((x) => x.completed);
  }

  static bool get bonusClaimed => _load()['b'] == true;
  static bool get bonusClaimable => allCompleted && !bonusClaimed;

  /// Feed every reward event here (done by DailyService).
  static Future<void> onEvent(RewardEvent e) async {
    final s = _load();
    final all = _templates();
    final p = (s['p'] as Map).cast<String, dynamic>();
    final g = (s['g'] as Map).cast<String, dynamic>();
    final ids = (s['ids'] as List).cast<String>();
    var changed = false;
    for (final id in ids) {
      final t = all[id];
      if (t == null) continue;
      final before = (p[id] as int?) ?? 0;
      if (before >= t.target || !t.matches(e)) continue;
      int after;
      if (t.distinctGames) {
        final set = ((g[id] as List?) ?? const []).cast<String>().toSet()..add(e.gameId);
        g[id] = set.toList();
        after = set.length;
      } else {
        after = before + 1;
      }
      after = min(after, t.target);
      if (after == before) continue;
      p[id] = after;
      changed = true;
      if (after >= t.target) {
        showDailyToast(
            emoji: t.emoji,
            title: tr('daily.quest_complete'),
            subtitle: tr('daily.quest_toast_sub', {'title': t.title, 'coins': t.reward}));
      }
    }
    if (!changed) return;
    s['p'] = p;
    s['g'] = g;
    final allDone = ids.isNotEmpty && ids.every((id) => all[id] != null && ((p[id] as int?) ?? 0) >= all[id]!.target);
    if (allDone && s['done'] != true) {
      s['done'] = true;
      await _bumpChallenge();
    }
    await _save(s);
    notifyDailyChanged();
  }

  static Future<void> _bumpChallenge() async {
    final today = DailyClock.today();
    final last = parseDateKey(Storage.getString(_kChLast));
    final gap = last == null ? -1 : daysBetween(last, today);
    if (gap == 0) return;
    final next = gap == 1 ? Storage.getInt(_kChStreak) + 1 : 1;
    await Storage.setString(_kChLast, dateKey(today));
    await Storage.setInt(_kChStreak, next);
    if (next > Storage.getInt(_kChBest)) await Storage.setInt(_kChBest, next);
  }

  /// Days in a row with all 3 quests completed (alive if today or yesterday).
  static int get challengeStreak {
    final last = parseDateKey(Storage.getString(_kChLast));
    if (last == null) return 0;
    final gap = daysBetween(last, DailyClock.today());
    return (gap == 0 || gap == 1) ? Storage.getInt(_kChStreak) : 0;
  }

  static int get challengeBest => Storage.getInt(_kChBest);
  static int get claimedTotal => Storage.getInt(kClaimedTotal);

  /// Pays a completed quest. Returns coins paid (0 if not claimable).
  static Future<int> claim(String id) async {
    final s = _load();
    final t = _templates()[id];
    final c = (s['c'] as List).cast<String>();
    final p = (s['p'] as Map).cast<String, dynamic>();
    if (t == null || c.contains(id) || ((p[id] as int?) ?? 0) < t.target) return 0;
    s['c'] = [...c, id];
    await _save(s);
    await Storage.setInt(kClaimedTotal, claimedTotal + 1);
    await Rewards.addCoins(t.reward, label: tr('daily.quest_complete'));
    notifyDailyChanged();
    return t.reward;
  }

  /// Pays the all-3 bonus once per day. Returns coins paid.
  static Future<int> claimBonus() async {
    if (!bonusClaimable) return 0;
    final s = _load();
    s['b'] = true;
    await _save(s);
    await Rewards.addCoins(bonusCoins, label: tr('daily.challenge_bonus_label'));
    notifyDailyChanged();
    return bonusCoins;
  }
}
