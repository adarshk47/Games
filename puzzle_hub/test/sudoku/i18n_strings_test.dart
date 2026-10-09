import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/ball_sort.dart';
import 'package:puzzle_hub/core/i18n/strings/game_2048.dart';
import 'package:puzzle_hub/core/i18n/strings/sudoku.dart';

/// Every key of the Sudoku / 2048 / Ball Sort tables has all languages and
/// the same placeholders as English.
void main() {
  final tables = {
    'sudoku': sudokuStrings,
    'game_2048': game2048Strings,
    'ball_sort': ballSortStrings,
  };
  Set<String> holders(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

  tables.forEach((module, table) {
    test('$module strings: all languages, prefixed keys, identical placeholders', () {
      expect(table, isNotEmpty);
      for (final MapEntry(:key, :value) in table.entries) {
        expect(key.startsWith('$module.'), isTrue, reason: key);
        for (final l in AppLang.values) {
          final s = value[l.code];
          expect(s, isNotNull, reason: '$key missing ${l.code}');
          expect(s!.trim(), isNotEmpty, reason: '$key empty ${l.code}');
          expect(holders(s), holders(value['en']!), reason: '$key placeholders differ in ${l.code}');
        }
      }
    });
  });
}
