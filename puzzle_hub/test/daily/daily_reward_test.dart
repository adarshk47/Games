import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/daily/daily_reward.dart';
import 'package:puzzle_hub/core/daily/reminder_service.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = 'u1.';
    now = DateTime(2026, 10, 4, 9);
    DailyClock.now = () => now;
  });

  test('date helpers', () {
    expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    expect(parseDateKey('2026-01-05'), DateTime(2026, 1, 5));
    expect(parseDateKey('bad'), isNull);
    expect(daysBetween(DateTime(2026, 3, 28, 23), DateTime(2026, 3, 30, 1)), 2);
    expect(daysBetween(DateTime(2026, 12, 31), DateTime(2027, 1, 1)), 1);
  });

  test('claim once per day, consecutive days grow the streak', () async {
    expect(DailyReward.canClaim, isTrue);
    expect(DailyReward.todayReward, 10);
    expect(await DailyReward.claim(), 10);
    expect(Storage.getInt('coins'), 10);
    expect(DailyReward.canClaim, isFalse);
    expect(await DailyReward.claim(), 0);
    expect(DailyReward.streak, 1);

    now = DateTime(2026, 10, 5, 22);
    expect(DailyReward.streak, 1);
    expect(DailyReward.todayReward, 15);
    expect(await DailyReward.claim(), 15);
    expect(DailyReward.streak, 2);
    expect(Storage.getInt('coins'), 25);
  });

  test('7 day cycle pays 10..50 then wraps', () async {
    final paid = <int>[];
    for (var i = 0; i < 9; i++) {
      now = DateTime(2026, 10, 4 + i, 12);
      paid.add(await DailyReward.claim());
    }
    expect(paid, [10, 15, 20, 25, 30, 40, 50, 10, 15]);
    expect(DailyReward.streak, 9);
    expect(DailyReward.bestStreak, 9);
    expect(DailyReward.cycleDay(14), 7);
    expect(DailyReward.cycleDay(15), 1);
  });

  test('missing a day resets to day 1 but keeps best streak', () async {
    for (var i = 0; i < 3; i++) {
      now = DateTime(2026, 10, 4 + i);
      await DailyReward.claim();
    }
    now = DateTime(2026, 10, 8); // skipped the 7th
    expect(DailyReward.streak, 0);
    expect(DailyReward.streakBroken, isTrue);
    expect(DailyReward.todayCycleDay, 1);
    expect(await DailyReward.claim(), 10);
    expect(DailyReward.streak, 1);
    expect(DailyReward.bestStreak, 3);
  });

  test('streak is per user', () async {
    await DailyReward.claim();
    Storage.userPrefix = 'u2.';
    expect(DailyReward.canClaim, isTrue);
    expect(DailyReward.streak, 0);
  });

  test('reminder service is a safe no-op in tests', () async {
    await ReminderService.init();
    await ReminderService.ensurePermissionPrompt();
    await ReminderService.reschedule();
    expect(ReminderService.time.value.hour, 19);
    final msg = ReminderService.messageFor(DateTime(2026, 10, 4), streak: 4, rewardReady: true);
    expect(msg, isNotEmpty);
  });
}
