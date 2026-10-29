import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/all.dart';
import 'package:puzzle_hub/core/i18n/strings/euro.dart';

void main() {
  final ph = RegExp(r'\{\w+\}');
  List<String> placeholders(String s) => [for (final m in ph.allMatches(s)) m.group(0)!]..sort();

  test('European tables only use known keys and keep every placeholder', () {
    for (final lang in ['de', 'fr', 'es', 'it']) {
      final table = euroStrings[lang]!;
      expect(table.length, greaterThan(1000), reason: lang);
      for (final e in table.entries) {
        final en = allStrings[e.key]?['en'];
        expect(en, isNotNull, reason: '$lang ${e.key} has no English source');
        expect(placeholders(e.value), placeholders(en!), reason: '$lang ${e.key}');
      }
    }
  });

  test('tr() uses the European table, then falls back to English', () {
    addTearDown(() => I18n.lang.value = AppLang.en);
    I18n.lang.value = AppLang.de;
    expect(tr('common.yes'), 'Ja');
    expect(tr('common.level_n', {'n': 3}), 'Level 3');
    I18n.lang.value = AppLang.fr;
    expect(tr('common.yes'), 'Oui');
    expect(tr('no.such.key'), 'no.such.key');
  });

  test('European countries list their language first', () {
    expect(languagesFor('DE').first, AppLang.de);
    expect(languagesFor('FR').first, AppLang.fr);
    expect(languagesFor('ES').first, AppLang.es);
    expect(languagesFor('IT').first, AppLang.it);
    expect(languagesFor('IN').first, AppLang.hi);
    expect(languagesFor('DE').toSet(), AppLang.values.toSet());
  });
}
