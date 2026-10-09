import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/all.dart';
import 'package:puzzle_hub/core/i18n/strings/mom_memory.dart';
import 'package:puzzle_hub/games/mom_memory/logic/mom_extra_logic.dart';
import 'package:puzzle_hub/games/mom_memory/logic/mom_logic.dart';

const langs = ['en', 'hi', 'hinglish', 'te', 'ta', 'pa', 'bho', 'mr', 'sa'];

List<String> placeholders(String s) =>
    RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toList()
      ..sort();

void expectAllLangs(Map<String, String> m, String what) {
  for (final l in langs) {
    expect(m[l], isNotNull, reason: '$what missing $l');
    expect(m[l]!.trim(), isNotEmpty, reason: '$what empty $l');
  }
}

void main() {
  tearDown(() => I18n.lang.value = AppLang.en);

  test('mmLangs matches every app language', () {
    expect(mmLangs.toSet(), AppLang.values.map((l) => l.code).toSet());
    expect(langs.toSet(), mmLangs.toSet());
  });

  group('UI strings', () {
    test('keys are prefixed and have all 7 languages', () {
      expect(momMemoryStrings, isNotEmpty);
      for (final e in momMemoryStrings.entries) {
        expect(e.key.startsWith('mom_memory.'), isTrue, reason: e.key);
        expectAllLangs(e.value, e.key);
      }
    });

    test('placeholders are identical in every language', () {
      for (final e in momMemoryStrings.entries) {
        final en = placeholders(e.value['en']!);
        for (final l in langs) {
          expect(placeholders(e.value[l]!), en, reason: '${e.key} [$l]');
        }
      }
    });

    test('emoji kept in every language', () {
      for (final e in momMemoryStrings.entries) {
        for (final emo in ['💗', '🌸']) {
          if (e.value['en']!.contains(emo)) {
            for (final l in langs) {
              expect(e.value[l]!.contains(emo), isTrue, reason: '${e.key} $l');
            }
          }
        }
      }
    });

    test('every tr() key used by Mom Memory exists', () {
      final files = Directory('lib/games/mom_memory')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final re = RegExp(r"""tr\(\s*'([a-z_0-9]+\.[a-z_0-9]+)'""");
      var found = 0;
      for (final f in files) {
        for (final m in re.allMatches(f.readAsStringSync())) {
          found++;
          expect(allStrings.containsKey(m.group(1)), isTrue,
              reason: '${m.group(1)} in ${f.path}');
        }
      }
      expect(found, greaterThan(50));
      for (final l in matchLevels) {
        expect(momMemoryStrings.containsKey(l.labelKey), isTrue);
      }
      for (var i = 1; i <= 6; i++) {
        expect(momMemoryStrings.containsKey('mom_memory.praise_$i'), isTrue);
      }
      for (var i = 1; i <= 4; i++) {
        expect(momMemoryStrings.containsKey('mom_memory.gentle_$i'), isTrue);
      }
    });

    test('disclaimer is present in every language', () {
      final f = momMemoryStrings['mom_memory.footnote']!;
      expectAllLangs(f, 'footnote');
      expect(f['en'], contains('not medical advice'));
      I18n.lang.value = AppLang.ta;
      expect(mmFootnote, f['ta']);
    });
  });

  group('content data', () {
    test('items, colours and word pairs have all 7 languages', () {
      for (final b in bagItems) {
        expectAllLangs(b.names, 'bag ${b.emoji}');
      }
      for (final t in missingPool) {
        expectAllLangs(t.names, 'missing ${t.emoji}');
      }
      for (final c in breathColors) {
        expectAllLangs(c.names, 'colour ${c.argb}');
      }
      for (final p in wordPairs) {
        expectAllLangs(p.words, 'pair word ${p.partner.emoji}');
        expectAllLangs(p.partner.names, 'pair partner ${p.partner.emoji}');
      }
    });

    test('names are unique per language (options never look the same)', () {
      for (final l in langs) {
        Set<String> uniq(Iterable<String> xs) => xs.toSet();
        expect(uniq(bagItems.map((b) => b.names[l]!)).length, bagItems.length,
            reason: 'bag $l');
        expect(uniq(missingPool.map((b) => b.names[l]!)).length,
            missingPool.length,
            reason: 'missing $l');
        expect(uniq(breathColors.map((b) => b.names[l]!)).length,
            breathColors.length,
            reason: 'colour $l');
        expect(uniq(wordPairs.map((p) => p.words[l]!)).length,
            wordPairs.length,
            reason: 'pair words $l');
        expect(uniq(wordPairs.map((p) => p.partner.names[l]!)).length,
            wordPairs.length,
            reason: 'pair partners $l');
      }
    });

    test('names follow the current language with fallbacks', () {
      expect(bagItems.first.name, 'Clothes');
      expect(wordPairs.first.word, 'Milk');
      I18n.lang.value = AppLang.hi;
      expect(bagItems.first.name, 'कपड़े');
      expect(breathColors.first.name, 'गुलाबी');
      I18n.lang.value = AppLang.hinglish;
      expect(wordPairs.first.word, 'Doodh');
      expect(missingPool.first.name, 'Bottle');
      I18n.lang.value = AppLang.pa;
      expect(stories.first.title, 'ਛੋਟੀ ਚਿੜੀ');
      // Fallback chain: a map without 'bho' uses Hindi.
      I18n.lang.value = AppLang.bho;
      expect(mmPick({'en': 'a', 'hi': 'b'}), 'b');
    });
  });

  group('stories', () {
    test('10 stories, each with 3 questions in all 7 languages', () {
      expect(stories.length, 10);
      for (final s in stories) {
        final id = s.titles['en']!;
        expectAllLangs(s.titles, 'title $id');
        for (final l in langs) {
          final lines = s.lineTexts[l];
          expect(lines, isNotNull, reason: '$id lines $l');
          expect(lines!.length, s.lineTexts['en']!.length, reason: '$id $l');
          expect(lines.length >= 3 && lines.length <= 4, isTrue);
          expect(lines.every((x) => x.trim().isNotEmpty), isTrue);
        }
        expect(s.questions.length, 3, reason: id);
        for (final q in s.questions) {
          expectAllLangs(q.texts, '$id question');
          for (final l in langs) {
            final o = q.optionTexts[l];
            expect(o, isNotNull, reason: '$id options $l');
            expect(o!.length, 3, reason: '$id ${q.texts['en']} $l');
            expect(o.toSet().length, 3, reason: '$id ${q.texts['en']} $l');
            expect(o.every((x) => x.trim().isNotEmpty), isTrue);
          }
          // One answer index shared by all languages.
          expect(q.answer >= 0 && q.answer < 3, isTrue);
        }
      }
    });

    test('correct answer is the same option in every language', () {
      // The answer index is shared; the English answer text must appear in the
      // English story, proving the index points at the right option.
      for (final s in stories) {
        final text = s.lineTexts['en']!.join(' ').toLowerCase();
        for (final q in s.questions) {
          final ans = q.optionTexts['en']![q.answer].toLowerCase();
          final word = ans.replaceFirst(RegExp(r'^(a|the|at|in the) '), '');
          expect(text.contains(word.split(' ').last), isTrue,
              reason: '${s.titles['en']}: $ans');
        }
      }
    });

    test('getters follow the current language', () {
      final s = stories.first;
      I18n.lang.value = AppLang.te;
      expect(s.title, s.titles['te']);
      expect(s.lines, s.lineTexts['te']);
      expect(s.questions.first.q, s.questions.first.texts['te']);
      expect(s.questions.first.options, s.questions.first.optionTexts['te']);
    });
  });
}
