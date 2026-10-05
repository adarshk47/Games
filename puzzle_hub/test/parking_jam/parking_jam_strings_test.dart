import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/all.dart';
import 'package:puzzle_hub/core/i18n/strings/parking_jam.dart';
import 'package:puzzle_hub/games/parking_jam/logic/parking_logic.dart';

Set<String> _placeholders(String s) => {for (final m in RegExp(r'\{(\w+)\}').allMatches(s)) m.group(1)!};

void main() {
  test('every parking_jam key has all 7 languages with the same placeholders', () {
    expect(parkingJamStrings, isNotEmpty);
    final langs = AppLang.values.map((l) => l.code).toSet();
    expect(langs.length, 7);
    parkingJamStrings.forEach((key, map) {
      expect(key.startsWith('parking_jam.'), isTrue, reason: key);
      expect(map.keys.toSet(), langs, reason: key);
      final ph = _placeholders(map['en']!);
      for (final l in langs) {
        expect(map[l]!.trim(), isNotEmpty, reason: '$key/$l');
        expect(_placeholders(map[l]!), ph, reason: '$key/$l');
      }
    });
  });

  test('scripts: Devanagari for hi/bho, Telugu, Tamil, Gurmukhi, Roman Hinglish', () {
    bool has(String s, int lo, int hi) => s.runes.any((r) => r >= lo && r <= hi);
    for (final e in parkingJamStrings.entries) {
      final m = e.value;
      expect(has(m['hi']!, 0x0900, 0x097F), isTrue, reason: '${e.key}/hi');
      expect(has(m['bho']!, 0x0900, 0x097F), isTrue, reason: '${e.key}/bho');
      expect(has(m['te']!, 0x0C00, 0x0C7F), isTrue, reason: '${e.key}/te');
      expect(has(m['ta']!, 0x0B80, 0x0BFF), isTrue, reason: '${e.key}/ta');
      expect(has(m['pa']!, 0x0A00, 0x0A7F), isTrue, reason: '${e.key}/pa');
      expect(has(m['hinglish']!, 0x0900, 0x0DFF), isFalse, reason: '${e.key}/hinglish');
    }
  });

  test('every key used in the source exists and is registered', () {
    final used = <String>{};
    final re = RegExp(r"'(parking_jam\.[a-z_.]+?)(\$\{[^}]*\})?'");
    for (final f in Directory('lib/games/parking_jam').listSync(recursive: true).whereType<File>()) {
      for (final m in re.allMatches(f.readAsStringSync())) {
        final k = m.group(1)!;
        if (m.group(2) != null) {
          for (final t in PjTier.values) {
            used.add('$k${t.id}');
          }
        } else if (!k.endsWith('.') && k.split('.').length == 2) {
          used.add(k);
        }
      }
    }
    // Storage keys like parking_jam.tier are not strings.
    used.remove('parking_jam.tier');
    expect(used, isNotEmpty);
    for (final k in used) {
      expect(parkingJamStrings.containsKey(k), isTrue, reason: k);
      expect(allStrings.containsKey(k), isTrue, reason: k);
    }
    for (final k in [
      'common.tier.easy',
      'common.level_n',
      'common.moves',
      'common.replay',
      'common.next_level',
      'common.hint',
      'common.undo',
      'common.restart',
      'common.levels',
    ]) {
      expect(allStrings.containsKey(k), isTrue, reason: k);
    }
  });
}
