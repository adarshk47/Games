import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ads/ads_service.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/mom_memory/baby_match_game.dart';
import 'package:puzzle_hub/games/mom_memory/breathe_game.dart';
import 'package:puzzle_hub/games/mom_memory/hospital_bag_game.dart';
import 'package:puzzle_hub/games/mom_memory/lullaby_game.dart';
import 'package:puzzle_hub/games/mom_memory/missing_item_game.dart';
import 'package:puzzle_hub/games/mom_memory/mom_memory_screen.dart';
import 'package:puzzle_hub/games/mom_memory/story_recall_game.dart';
import 'package:puzzle_hub/games/mom_memory/where_was_it_game.dart';
import 'package:puzzle_hub/games/mom_memory/word_pairs_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen + label of the button that moves it past its intro (if any).
final screens = <String, (Widget Function(), String Function()?)>{
  'menu': (() => const MomMemoryScreen(), null),
  'match': (() => const BabyMatchGame(), null),
  'bag': (() => const HospitalBagGame(), () => tr('mom_memory.start')),
  'lullaby': (() => const LullabyGame(), () => tr('mom_memory.start')),
  'breathe': (
    () => const BreatheGame(),
    () => tr('mom_memory.minutes', {'n': 1}),
  ),
  'missing': (() => const MissingItemGame(), () => tr('mom_memory.start')),
  'pairs': (() => const WordPairsGame(), () => tr('mom_memory.start')),
  'where': (() => const WhereWasItGame(), () => tr('mom_memory.start')),
  'story': (() => const StoryRecallGame(), () => tr('mom_memory.start')),
};

Future<void> drain(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(seconds: 2));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
    AdsService.suppressed = 0;
    Rewards.reload();
  });
  tearDown(() => I18n.lang.value = AppLang.en);

  testWidgets('menu shows English texts', (t) async {
    await t.binding.setSurfaceSize(const Size(420, 2000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const MaterialApp(home: MomMemoryScreen()));
    await t.pump(const Duration(seconds: 2));
    expect(find.text('Mom Memory'), findsOneWidget);
    expect(find.text('Baby Items Match'), findsOneWidget);
    expect(find.text('Story Recall'), findsOneWidget);
    expect(find.text('Hello! Take it easy, no hurry'), findsOneWidget);
    expect(
      find.text('Only for fun and light mental exercise, not medical advice.'),
      findsOneWidget,
    );
    await drain(t);
  });

  testWidgets('story recall runs in English and checks by index', (t) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const MaterialApp(home: StoryRecallGame()));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('A short story'), findsOneWidget);
    await t.tap(find.text('Start'));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text("I've read it"));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Question 1/3'), findsOneWidget);
    await drain(t);
  });

  for (final lang in AppLang.values) {
    for (final e in screens.entries) {
      testWidgets('${e.key} pumps in ${lang.code}', (t) async {
        await t.binding.setSurfaceSize(const Size(400, 860));
        addTearDown(() => t.binding.setSurfaceSize(null));
        I18n.lang.value = lang;
        final (build, startLabel) = e.value;
        await t.pumpWidget(MaterialApp(home: build()));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        if (startLabel != null) {
          final f = find.text(startLabel());
          expect(f, findsOneWidget, reason: '${e.key} start in ${lang.code}');
          await t.tap(f);
          for (var i = 0; i < 8; i++) {
            await t.pump(const Duration(milliseconds: 500));
          }
          expect(t.takeException(), isNull);
        }
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }
}
