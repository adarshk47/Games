import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/daily/daily_quests.dart';
import 'package:puzzle_hub/core/daily/daily_reward.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;

  const titles = {'sudoku': 'Sudoku', 'arrow_maze': 'Arrow Maze', 'game_2048': '2048', 'ball_sort': 'Ball Sort'};

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = 'u1.';
    now = DateTime(2026, 10, 4, 10);
    DailyClock.now = () => now;
    DailyQuests.gameTitles = () => titles;
  });

  Future<void> forceQuests(List<String> ids) => Storage.setString('quests.state',
      '{"date":"${dateKey(now)}","ids":["${ids.join('","')}"],"p":{},"g":{},"c":[],"b":false,"done":false}');

  test('picks are deterministic, 3 distinct categories, only enabled games', () {
    final enabled = {for (final g in games) g.id: g.title};
    final disabled = allGames.where((g) => !g.enabled).map((g) => g.id).toList();
    for (var d = 0; d < 60; d++) {
      final date = DateTime(2026, 1, 1).add(Duration(days: d));
      final a = pickQuests(date, enabled);
      final b = pickQuests(date, enabled);
      expect(a.map((q) => q.id), b.map((q) => q.id));
      expect(a.length, 3);
      expect(a.map((q) => q.category).toSet().length, 3);
      for (final q in a) {
        expect(q.reward, inInclusiveRange(10, 25));
        for (final id in disabled) {
          expect(q.id.endsWith(id), isFalse, reason: '${q.id} references disabled game');
        }
      }
    }
  });

  test('templates skip games that are not enabled', () {
    final ids = questTemplates(const {'sudoku': 'Sudoku'}).map((t) => t.id).toSet();
    expect(ids, contains('win_sudoku'));
    expect(ids.any((i) => i.contains('arrow_maze') || i.contains('2048')), isFalse);
  });

  test('progress from events, claim, bonus and challenge streak', () async {
    await forceQuests(['levels_3', 'variety_2', 'hard_clear']);

    await DailyQuests.onEvent(const RewardEvent(gameId: 'sudoku', type: 'level', levelKey: 'easy', won: true));
    await DailyQuests.onEvent(const RewardEvent(gameId: 'sudoku', type: 'level', levelKey: 'medium', won: true));
    var q = {for (final x in DailyQuests.today()) x.template.id: x};
    expect(q['levels_3']!.progress, 2);
    expect(q['variety_2']!.progress, 1); // same game twice
    expect(q['hard_clear']!.progress, 0);
    expect(await DailyQuests.claim('levels_3'), 0); // not done yet

    await DailyQuests.onEvent(const RewardEvent(gameId: 'game_2048', type: 'run', score: 300));
    await DailyQuests.onEvent(
        const RewardEvent(gameId: 'arrow_maze', type: 'level', levelKey: 'extreme-L4', stars: 3, won: true));
    q = {for (final x in DailyQuests.today()) x.template.id: x};
    expect(q.values.every((x) => x.completed), isTrue);
    expect(q['variety_2']!.progress, 2);
    expect(DailyQuests.challengeStreak, 1);

    expect(await DailyQuests.claim('levels_3'), 15);
    expect(await DailyQuests.claim('levels_3'), 0);
    expect(DailyQuests.bonusClaimable, isTrue);
    expect(await DailyQuests.claimBonus(), DailyQuests.bonusCoins);
    expect(await DailyQuests.claimBonus(), 0);
    expect(Storage.getInt('coins'), 15 + 40);
    expect(DailyQuests.claimedTotal, 1);
  });

  test('specific matchers: 2048 score, 3 stars in a game, win a game', () async {
    await forceQuests(['score_2048', 'stars_arrow_maze', 'win_sudoku']);
    await DailyQuests.onEvent(const RewardEvent(gameId: 'game_2048', type: 'run', score: 999));
    await DailyQuests.onEvent(const RewardEvent(gameId: 'arrow_maze', type: 'level', levelKey: 'easy-L1', stars: 2, won: true));
    await DailyQuests.onEvent(const RewardEvent(gameId: 'sudoku', type: 'run', won: false));
    expect(DailyQuests.today().every((x) => x.progress == 0), isTrue);
    await DailyQuests.onEvent(const RewardEvent(gameId: 'game_2048', type: 'level', levelKey: 'size4/tier-easy-512', score: 1000, won: true));
    await DailyQuests.onEvent(const RewardEvent(gameId: 'arrow_maze', type: 'level', levelKey: 'easy-L2', stars: 3, won: true));
    await DailyQuests.onEvent(const RewardEvent(gameId: 'sudoku', type: 'level', levelKey: 'easy', won: true));
    expect(DailyQuests.allCompleted, isTrue);
  });

  test('new day gets fresh progress; challenge streak continues then resets', () async {
    Future<void> completeToday() async {
      await forceQuests(DailyQuests.today().map((q) => q.template.id).toList());
      final events = [
        for (final g in titles.keys) ...[
          RewardEvent(gameId: g, type: 'level', levelKey: 'hard-L1', stars: 3, score: 5000, won: true, firstTime: true),
          RewardEvent(gameId: g, type: 'run', score: 5000, won: true),
        ],
      ];
      for (var i = 0; i < 3; i++) {
        for (final e in events) {
          await DailyQuests.onEvent(e);
        }
      }
      expect(DailyQuests.allCompleted, isTrue);
    }

    await completeToday();
    expect(DailyQuests.challengeStreak, 1);
    now = DateTime(2026, 10, 5, 8);
    expect(DailyQuests.today().every((q) => q.progress == 0), isTrue);
    expect(DailyQuests.challengeStreak, 1); // still alive
    await completeToday();
    expect(DailyQuests.challengeStreak, 2);
    now = DateTime(2026, 10, 7, 8);
    expect(DailyQuests.challengeStreak, 0);
    await completeToday();
    expect(DailyQuests.challengeStreak, 1);
    expect(DailyQuests.challengeBest, 2);
  });
}
