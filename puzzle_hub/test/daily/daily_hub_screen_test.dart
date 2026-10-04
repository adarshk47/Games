import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/achievements/achievements_screen.dart';
import 'package:puzzle_hub/core/daily/daily_hub_screen.dart';
import 'package:puzzle_hub/core/daily/daily_quests.dart';
import 'package:puzzle_hub/core/daily/daily_reward.dart';
import 'package:puzzle_hub/core/daily/reminder_tile.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = 'u1.';
    DailyClock.now = () => DateTime(2026, 10, 4, 10);
    DailyQuests.gameTitles = () => const {'sudoku': 'Sudoku', 'arrow_maze': 'Arrow Maze', 'game_2048': '2048'};
  });

  Future<void> pumpPhone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360 * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('DailyHubScreen renders and claims the login reward', (tester) async {
    await pumpPhone(tester, const Scaffold(body: DailyHubScreen()));
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Claim 10 🪙'), findsOneWidget);
    await tester.tap(find.text('Claim 10 🪙'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(DailyReward.claimedToday, isTrue);
    expect(find.text('Reward claimed!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('AchievementsScreen renders badges', (tester) async {
    await pumpPhone(tester, const AchievementsScreen());
    expect(find.text('Achievements'), findsOneWidget);
    expect(find.textContaining('badges'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('ReminderSettingsTile shows switch and time', (tester) async {
    await pumpPhone(tester, const Scaffold(body: ReminderSettingsTile()));
    expect(find.text('Daily reminder'), findsOneWidget);
    expect(find.text('Reminder time'), findsOneWidget);
  });
}
