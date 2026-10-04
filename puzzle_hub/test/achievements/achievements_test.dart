import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/achievements/achievements.dart';
import 'package:puzzle_hub/core/daily/daily_quests.dart';
import 'package:puzzle_hub/core/daily/daily_reward.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = 'u1.';
    DailyClock.now = () => DateTime(2026, 10, 4, 10);
    DailyQuests.gameTitles = () => const {'sudoku': 'Sudoku', 'arrow_maze': 'Arrow Maze', 'game_2048': '2048'};
  });

  test('catalog has ~25 unique badges with small rewards', () {
    final all = Achievements.all();
    expect(all.length, greaterThanOrEqualTo(24));
    expect(all.map((a) => a.id).toSet().length, all.length);
    for (final a in all) {
      expect(a.reward, inInclusiveRange(5, 30));
      expect(a.target, greaterThan(0));
    }
    expect(all.map((a) => a.id), containsAll(['master_sudoku', 'master_arrow_maze', 'master_game_2048']));
  });

  test('tier detection from level keys', () {
    expect(tierOfKey('extreme-L3'), 'extreme');
    expect(tierOfKey('size4/tier-hard-2048'), 'hard');
    expect(tierOfKey('labyrinth-medium-L1'), 'medium');
    expect(tierOfKey('Easy'), 'easy');
    expect(tierOfKey('daily-20261004'), isNull);
  });

  test('nothing unlocks on a fresh profile', () async {
    expect(await Achievements.evaluate(), isEmpty);
    expect(Achievements.unlocked, isEmpty);
  });

  test('events + records unlock badges once and pay coins', () async {
    await Storage.setInt('rec.sudoku.wins', 1);
    await Storage.setInt('rec.sudoku.plays', 1);
    await Storage.setInt('rec.sudoku.levels', 1);
    for (final t in ['easy-L1', 'medium-L1', 'hard-L1', 'extreme-L1']) {
      await Achievements.onEvent(
          RewardEvent(gameId: 'arrow_maze', type: 'level', levelKey: t, stars: 3, won: true, firstTime: true));
    }
    final u = Achievements.unlocked;
    expect(u, containsAll(['first_win', 'all_tiers', 'hard_clear', 'extreme_clear', 'stars3_1']));
    expect(u, isNot(contains('levels_10')));
    expect(u, isNot(contains('extreme_10')));
    final coins = Storage.getInt('coins');
    expect(coins, greaterThan(0));
    // Re-evaluating does not pay again.
    expect(await Achievements.evaluate(), isEmpty);
    expect(Storage.getInt('coins'), coins);
  });

  test('progress values and streak / coins badges', () async {
    await Storage.setInt('rec.sudoku.levels', 7);
    await Storage.setInt('rec.arrow_maze.levels', 2);
    final s = AchStats.load();
    final l10 = Achievements.all().firstWhere((a) => a.id == 'levels_10');
    expect(l10.current(s), 9);
    expect(l10.fraction(s), closeTo(0.9, 1e-9));

    await Storage.setInt('daily.bestStreak', 7);
    await Storage.setInt('coins.earned', 1000);
    final fresh = (await Achievements.evaluate()).map((a) => a.id);
    expect(fresh, containsAll(['streak_3', 'streak_7', 'coins_1000']));
    expect(fresh, isNot(contains('streak_30')));
  });

  test('master badge per game (2048 uses best score)', () async {
    await Storage.setInt('rec.sudoku.wins', 20);
    await Storage.setInt('rec.game_2048.best', 12000);
    await Achievements.evaluate();
    expect(Achievements.unlocked, containsAll(['master_sudoku', 'master_game_2048']));
    expect(Achievements.isUnlocked('master_arrow_maze'), isFalse);
  });
}
