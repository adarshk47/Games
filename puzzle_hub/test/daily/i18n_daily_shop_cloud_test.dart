import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/achievements/achievements.dart';
import 'package:puzzle_hub/core/ads/ads_service.dart';
import 'package:puzzle_hub/core/daily/daily_hub_screen.dart';
import 'package:puzzle_hub/core/daily/daily_quests.dart';
import 'package:puzzle_hub/core/daily/daily_reward.dart';
import 'package:puzzle_hub/core/daily/reminder_service.dart';
import 'package:puzzle_hub/core/economy/continue_offer.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/cloud.dart';
import 'package:puzzle_hub/core/i18n/strings/daily.dart';
import 'package:puzzle_hub/core/i18n/strings/shop.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/shop/shop_screen.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Set<String> _placeholders(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

void main() {
  final tables = {'daily': dailyStrings, 'shop': shopStrings, 'cloud': cloudStrings};
  final langs = [for (final l in AppLang.values) l.code];

  group('string tables', () {
    for (final t in tables.entries) {
      test('${t.key}: every key has all 7 languages and identical placeholders', () {
        expect(t.value, isNotEmpty);
        for (final e in t.value.entries) {
          for (final l in langs) {
            final s = e.value[l];
            expect(s, isNotNull, reason: '${e.key} missing $l');
            expect(s!.trim(), isNotEmpty, reason: '${e.key} empty $l');
            expect(_placeholders(s), _placeholders(e.value['en']!), reason: '${e.key} placeholders differ in $l');
          }
          expect(e.value.keys.toSet(), langs.toSet(), reason: '${e.key} has unknown language codes');
        }
      });
    }

    test('no key collides between the three tables', () {
      final seen = <String>{};
      for (final t in tables.values) {
        for (final k in t.keys) {
          expect(seen.add(k), isTrue, reason: 'duplicate key $k');
        }
      }
    });
  });

  group('screens in every language', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({'coins': 25});
      await Storage.init();
      Storage.userPrefix = '';
      DailyClock.now = () => DateTime(2026, 10, 4, 10);
      DailyQuests.gameTitles = () => const {'sudoku': 'Sudoku', 'arrow_maze': 'Arrow Maze', 'game_2048': '2048'};
      AdsService.rewardedOverride = null;
      AdsService.clock = DateTime.now;
      Rewards.reload();
    });
    tearDown(() => I18n.lang.value = AppLang.en);

    Future<void> pumpPhone(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(360 * 3, 760 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: child));
      await tester.pump(const Duration(milliseconds: 800));
    }

    for (final lang in AppLang.values) {
      testWidgets('DailyHubScreen renders in ${lang.code}', (tester) async {
        I18n.lang.value = lang;
        await pumpPhone(tester, const Scaffold(body: DailyHubScreen()));
        expect(tester.takeException(), isNull);
        expect(find.text(tr('daily.title')), findsOneWidget);
        expect(find.text(tr('daily.claim', {'coins': 10})), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
      });

      testWidgets('ShopScreen renders in ${lang.code}', (tester) async {
        I18n.lang.value = lang;
        await pumpPhone(tester, const Material(color: Colors.black, child: ShopScreen()));
        expect(tester.takeException(), isNull);
        expect(find.text(tr('shop.title')), findsOneWidget);
        expect(find.text(tr('shop.pass_title')), findsOneWidget);
      });
    }

    test('dynamic texts are localized (Hindi) and fall back cleanly', () {
      I18n.lang.value = AppLang.hi;
      expect(ReminderService.messageFor(DateTime(2026, 10, 4), streak: 2, rewardReady: true), isNot(contains('{')));
      for (final q in questTemplates(DailyQuests.gameTitles())) {
        expect(q.title, isNot(contains('{')));
        expect(q.title, isNot(contains('quest.')));
      }
      for (final a in Achievements.all()) {
        expect(a.title, isNot(startsWith('ach.')));
        expect(a.desc, isNot(contains('{')));
      }
      expect(Prices.of(OfferKind.hint), 20);
    });
  });
}
