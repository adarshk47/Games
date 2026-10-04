// Shared helpers for the hidden-games i18n tests (block_puzzle, flow_pairs,
// sliding_puzzle, minesweeper).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/all.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const langCodes = ['en', 'hi', 'hinglish', 'te', 'ta', 'pa', 'bho'];

Set<String> _placeholders(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

/// Every key has [prefix], all 7 languages, non-empty text and the same placeholders as English.
void checkTable(String prefix, Map<String, Map<String, String>> table) {
  expect(table, isNotEmpty);
  for (final MapEntry(:key, :value) in table.entries) {
    expect(key.startsWith('$prefix.'), isTrue, reason: key);
    expect(value.keys.toSet(), langCodes.toSet(), reason: key);
    final ph = _placeholders(value['en']!);
    for (final c in langCodes) {
      expect(value[c]!.trim(), isNotEmpty, reason: '$key/$c');
      expect(_placeholders(value[c]!), ph, reason: '$key/$c placeholders');
    }
  }
}

/// Every literal `tr('key')` used under [dir] exists in the string tables.
void checkSourceKeys(String dir) {
  final re = RegExp(r"tr\('([a-z0-9_.]+)'");
  var found = 0;
  final files = Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  for (final f in files) {
    for (final m in re.allMatches(f.readAsStringSync())) {
      found++;
      expect(allStrings.containsKey(m.group(1)), isTrue, reason: '${m.group(1)} in ${f.path}');
    }
  }
  expect(found, greaterThan(0));
}

/// Pumps [screen] once per language and checks nothing throws. [then] can
/// drive further into the game (e.g. open a tier) in that language.
void firstScreenInAllLanguages(
  String name,
  Widget Function() screen, {
  Size size = const Size(360, 780),
  Future<void> Function(WidgetTester t)? then,
}) {
  for (final lang in AppLang.values) {
    testWidgets('$name renders in ${lang.code}', (t) async {
      SharedPreferences.setMockInitialValues({});
      await Storage.init();
      I18n.lang.value = lang;
      addTearDown(() => I18n.lang.value = AppLang.en);
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: screen()));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      expect(find.textContaining(tr('common.tier.easy')), findsWidgets);
      if (then != null) {
        await then(t);
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });
  }
}
