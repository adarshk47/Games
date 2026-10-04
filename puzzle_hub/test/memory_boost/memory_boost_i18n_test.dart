import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ads/ads_service.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/all.dart';
import 'package:puzzle_hub/core/i18n/strings/memory_boost.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/memory_boost/card_match_game.dart';
import 'package:puzzle_hub/games/memory_boost/logic/mb_tiers.dart';
import 'package:puzzle_hub/games/memory_boost/mb_widgets.dart';
import 'package:puzzle_hub/games/memory_boost/memory_boost_screen.dart';
import 'package:puzzle_hub/games/memory_boost/number_memory_game.dart';
import 'package:puzzle_hub/games/memory_boost/simon_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

Set<String> _placeholders(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

void main() {
  group('memory_boost strings', () {
    test('every key is prefixed and has all 7 languages with identical placeholders', () {
      final langs = AppLang.values.map((l) => l.code).toSet();
      expect(memoryBoostStrings, isNotEmpty);
      memoryBoostStrings.forEach((key, entry) {
        expect(key.startsWith('memory_boost.'), isTrue, reason: key);
        expect(entry.keys.toSet(), langs, reason: key);
        final ph = _placeholders(entry['en']!);
        entry.forEach((lang, s) {
          expect(s.trim(), isNotEmpty, reason: '$key/$lang');
          expect(_placeholders(s), ph, reason: '$key/$lang');
        });
      });
    });

    test('every literal tr() key used in lib/games/memory_boost exists', () {
      final re = RegExp(r"""tr\(\s*'((?:memory_boost|common)\.[a-z0-9_.]+)'""");
      for (final f in Directory('lib/games/memory_boost').listSync(recursive: true).whereType<File>()) {
        for (final m in re.allMatches(f.readAsStringSync())) {
          expect(allStrings.containsKey(m.group(1)), isTrue, reason: '${m.group(1)} in ${f.path}');
        }
      }
      for (final t in Tier.values) {
        expect(memoryBoostStrings.containsKey('memory_boost.card.desc.${t.key}'), isTrue);
        expect(memoryBoostStrings.containsKey('memory_boost.simon.desc.${t.key}'), isTrue);
        expect(allStrings.containsKey('common.tier.${t.key}'), isTrue);
      }
    });
  });

  group('memory_boost screens in every language', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({'coins': 100});
      await Storage.init();
      Storage.userPrefix = '';
      AdsService.rewardedOverride = null;
      Rewards.reload();
    });
    tearDown(() => I18n.lang.value = AppLang.en);

    Future<void> pumpScreen(WidgetTester t, Widget w, [Future<void> Function()? then]) async {
      await t.binding.setSurfaceSize(const Size(400, 860));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(MaterialApp(home: w));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      if (then != null) {
        await then();
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 10));
    }

    for (final lang in AppLang.values) {
      testWidgets('Brain Gym menu + games render in ${lang.code}', (t) async {
        I18n.lang.value = lang;
        await pumpScreen(t, const MemoryBoostScreen(), () async {
          expect(find.text(tr('memory_boost.title')), findsOneWidget);
        });
        await pumpScreen(t, const CardMatchScreen(), () async {
          await t.tap(find.text(tierName(Tier.easy)));
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull);
          await t.tap(find.text(tr('memory_boost.card.grid', {'grid': '2x2'})));
          await t.pump(const Duration(seconds: 1));
          expect(find.text(tr('memory_boost.card.peek_free')), findsOneWidget);
        });
        await pumpScreen(t, const SimonScreen(), () async {
          await t.tap(find.text(tierName(Tier.medium)));
          await t.pump(const Duration(seconds: 1));
          expect(find.text(tr('memory_boost.simon.status.idle')), findsOneWidget);
        });
        await pumpScreen(t, const NumberMemoryScreen(), () async {
          await t.tap(find.text(tierName(Tier.hard)));
          await t.pump(const Duration(milliseconds: 500));
          expect(find.text(tr('memory_boost.number.round_n', {'n': 1})), findsOneWidget);
        });
      });
    }
  });
}
