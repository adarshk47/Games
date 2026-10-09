import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/all.dart';
import 'package:puzzle_hub/core/i18n/strings/arrow_maze.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/arrow_maze/arrow_maze_screen.dart';
import 'package:puzzle_hub/games/arrow_maze/logic/arrow_maze_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _langs = AppLang.values.map((l) => l.code).toSet();
final _ph = RegExp(r'\{(\w+)\}');

void checkTable(String prefix, Map<String, Map<String, String>> table) {
  expect(table, isNotEmpty);
  for (final MapEntry(:key, :value) in table.entries) {
    expect(key.startsWith('$prefix.'), isTrue, reason: key);
    expect(value.keys.toSet(), _langs, reason: '$key languages');
    final en = _ph.allMatches(value['en']!).map((m) => m[1]).toSet();
    for (final MapEntry(key: lang, value: s) in value.entries) {
      expect(s.trim(), isNotEmpty, reason: '$key.$lang empty');
      expect(_ph.allMatches(s).map((m) => m[1]).toSet(), en, reason: '$key.$lang placeholders');
    }
  }
}

/// Every literal `tr('...')` key used in [dir] must exist.
void checkUsedKeys(String dir) {
  final re = RegExp(r"""tr\(\s*'([a-z_]+\.[a-z0-9_.]+)'""");
  for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    for (final m in re.allMatches(f.readAsStringSync())) {
      expect(allStrings.containsKey(m[1]), isTrue, reason: '${m[1]} used in ${f.path}');
    }
  }
}

void main() {
  test('arrow_maze strings: all languages, identical placeholders', () {
    checkTable('arrow_maze', arrowMazeStrings);
    checkUsedKeys('lib/games/arrow_maze');
    for (final t in MazeTier.values) {
      expect(allStrings.containsKey('arrow_maze.blurb.${t.key}'), isTrue);
      expect(allStrings.containsKey('common.tier.${t.key}'), isTrue);
    }
    for (var i = 0; i < kMazeThemes.length; i++) {
      expect(allStrings.containsKey('arrow_maze.theme.$i'), isTrue);
    }
    for (var i = 0; i < kMazePalettes.length; i++) {
      expect(allStrings.containsKey('arrow_maze.palette.$i'), isTrue);
    }
  });

  group('arrow_maze screens render in every language', () {
    tearDown(() => I18n.lang.value = AppLang.en);
    for (final lang in AppLang.values) {
      testWidgets(lang.code, (t) async {
        SharedPreferences.setMockInitialValues({});
        await Storage.init();
        I18n.lang.value = lang;
        t.view.physicalSize = const Size(360, 640);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);

        await t.pumpWidget(const MaterialApp(home: ArrowMazeScreen()));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        expect(find.text(tr('arrow_maze.title')), findsOneWidget);

        await t.tap(find.text(tr('common.tier.easy')));
        await t.pump(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);

        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(const MaterialApp(home: ArrowMazeGamePage(tier: MazeTier.extreme, level: 1)));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        await t.tap(find.byIcon(Icons.palette_rounded));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);

        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 2));
      });
    }
  });
}
