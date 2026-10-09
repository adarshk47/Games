import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ads/ads_service.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/all.dart';
import 'package:puzzle_hub/core/i18n/strings/focus_color.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/focus_color/focus_color_screen.dart';
import 'package:puzzle_hub/games/focus_color/focus_play.dart';
import 'package:puzzle_hub/games/focus_color/logic/focus_common.dart';
import 'package:puzzle_hub/games/focus_color/logic/focus_difficulty.dart';
import 'package:puzzle_hub/games/focus_color/logic/stroop_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

Set<String> _placeholders(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

Future<void> _initStorage() async {
  SharedPreferences.setMockInitialValues({'coins': 100});
  await Storage.init();
  Storage.userPrefix = '';
  AdsService.rewardedOverride = null;
  Rewards.reload();
}

void main() {
  tearDown(() => I18n.lang.value = AppLang.en);

  group('focus_color strings', () {
    test('every key is prefixed and has all languages with identical placeholders', () {
      final langs = AppLang.values.map((l) => l.code).toSet();
      expect(focusColorStrings, isNotEmpty);
      focusColorStrings.forEach((key, entry) {
        expect(key.startsWith('focus_color.'), isTrue, reason: key);
        expect(entry.keys.toSet(), langs, reason: key);
        final ph = _placeholders(entry['en']!);
        entry.forEach((lang, s) {
          expect(s.trim(), isNotEmpty, reason: '$key/$lang');
          expect(_placeholders(s), ph, reason: '$key/$lang');
        });
      });
    });

    test('every literal and per-enum tr() key used in lib/games/focus_color exists', () {
      final re = RegExp(r"""tr\(\s*'((?:focus_color|common)\.[a-z0-9_.]+)'""");
      for (final f in Directory('lib/games/focus_color').listSync(recursive: true).whereType<File>()) {
        for (final m in re.allMatches(f.readAsStringSync())) {
          expect(allStrings.containsKey(m.group(1)), isTrue, reason: '${m.group(1)} in ${f.path}');
        }
      }
      for (final m in FocusMode.values) {
        expect(focusColorStrings.containsKey('focus_color.mode.${m.name}.title'), isTrue);
        expect(focusColorStrings.containsKey('focus_color.mode.${m.name}.blurb'), isTrue);
      }
      for (final t in FocusTier.values) {
        expect(focusColorStrings.containsKey('focus_color.tier_blurb.${t.name}'), isTrue);
        expect(allStrings.containsKey('common.tier.${t.name}'), isTrue);
      }
    });

    test('Stroop color names exist and are distinct in every language', () {
      for (final lang in AppLang.values) {
        I18n.lang.value = lang;
        final names = StroopColor.values.map(stroopColorName).toList();
        for (final c in StroopColor.values) {
          expect(focusColorStrings['focus_color.color.${c.name}']![lang.code], isNotNull, reason: '${c.name}/${lang.code}');
        }
        expect(names.toSet().length, names.length, reason: lang.code);
      }
      I18n.lang.value = AppLang.hi;
      expect(stroopColorName(StroopColor.red), 'लाल');
      expect(stroopColorName(StroopColor.red), isNot(StroopColor.red.label));
    });

    test('Stroop answers are judged by color id, not by the (translated) text', () {
      I18n.lang.value = AppLang.ta;
      final g = StroopGenerator(Random(7), focusParams(FocusMode.stroop, FocusTier.extreme));
      for (var i = 0; i < 300; i++) {
        final r = g.next(i);
        for (final c in r.options) {
          expect(r.isCorrect(c), c == r.ink);
        }
        // The displayed word is a different color than the ink, and its text never
        // names the correct answer.
        expect(stroopColorName(r.word), isNot(stroopColorName(r.ink)));
      }
    });
  });

  group('focus_color screens', () {
    setUp(_initStorage);

    for (final lang in AppLang.values) {
      testWidgets('menu, chooser and play screens render in ${lang.code}', (t) async {
        I18n.lang.value = lang;
        await t.binding.setSurfaceSize(const Size(400, 860));
        addTearDown(() => t.binding.setSurfaceSize(null));

        await t.pumpWidget(const MaterialApp(home: FocusColorScreen()));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        expect(find.text(tr('focus_color.title')), findsOneWidget);
        await t.tap(find.text(focusModes.first.title));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        expect(find.text(tr('focus_color.choose')), findsOneWidget);
        await t.pumpWidget(const SizedBox());

        for (final m in focusModes) {
          for (final tier in [FocusTier.easy, FocusTier.extreme]) {
            await t.pumpWidget(MaterialApp(home: FocusPlayScreen(info: m, tier: tier)));
            await t.pump(const Duration(milliseconds: 500));
            expect(t.takeException(), isNull);
            await t.pump(const Duration(milliseconds: 2600)); // countdown over -> playing
            await t.pump(const Duration(milliseconds: 500));
            expect(t.takeException(), isNull, reason: '${m.mode} $tier');
            await t.pumpWidget(const SizedBox());
          }
        }
        await t.pump(const Duration(seconds: 2));
      });
    }

    testWidgets('Stroop in Hindi: translated words, answers judged by color id', (t) async {
      I18n.lang.value = AppLang.hi;
      await t.binding.setSurfaceSize(const Size(400, 860));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(MaterialApp(home: FocusPlayScreen(info: focusModes.first, tier: FocusTier.medium)));
      await t.pump(const Duration(milliseconds: 3000));
      await t.pump(const Duration(milliseconds: 300));

      final hindiNames = {for (final c in StroopColor.values) stroopColorName(c): c};
      final englishLabels = StroopColor.values.map((c) => c.label).toSet();
      final scoreKey = ValueKey('focus-stat-${tr('common.score').toUpperCase()}');
      int score() => int.parse(t.widget<Text>(find.byKey(scoreKey)).data!);

      StroopColor inkOnScreen() {
        final word = t.widget<Text>(find.byKey(const ValueKey('stroop-word')));
        expect(hindiNames.containsKey(word.data), isTrue, reason: 'word "${word.data}" should be Hindi');
        expect(englishLabels.contains(word.data), isFalse);
        final argb = word.style!.color!.toARGB32();
        final ink = StroopColor.values.firstWhere((c) => c.argb == argb);
        expect(hindiNames[word.data], isNot(ink)); // word never names the ink
        return ink;
      }

      var expected = 0, streak = 0;
      for (var i = 0; i < 12; i++) {
        final ink = inkOnScreen();
        // English labels are never shown as buttons.
        for (final l in englishLabels) {
          expect(find.text(l), findsNothing);
        }
        await t.tap(find.text(stroopColorName(ink)));
        await t.pump(const Duration(milliseconds: 500));
        expected += pointsFor(streak);
        streak++;
        expect(score(), expected, reason: 'round $i');
      }

      // A wrong (but valid, translated) option does not score.
      final ink = inkOnScreen();
      final wrong = hindiNames.entries.firstWhere(
          (e) => e.value != ink && find.text(e.key).evaluate().length == 1 && t.widget<Text>(find.byKey(const ValueKey('stroop-word'))).data != e.key);
      await t.tap(find.text(wrong.key));
      await t.pump(const Duration(milliseconds: 500));
      expect(score(), expected);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    });
  });
}
