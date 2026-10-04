import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/all.dart';
import 'package:puzzle_hub/core/i18n/strings/maze_escape.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/maze_escape/labyrinth_game.dart';
import 'package:puzzle_hub/games/maze_escape/logic/levels.dart';
import 'package:puzzle_hub/games/maze_escape/maze_escape_screen.dart';
import 'package:puzzle_hub/games/maze_escape/memory_maze_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _langs = {'en', 'hi', 'hinglish', 'te', 'ta', 'pa', 'bho'};
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
  test('maze_escape strings: all 7 languages, identical placeholders', () {
    checkTable('maze_escape', mazeEscapeStrings);
    checkUsedKeys('lib/games/maze_escape');
    for (final t in MazeTier.values) {
      expect(allStrings.containsKey('maze_escape.blurb.${t.name}'), isTrue);
      expect(allStrings.containsKey('common.tier.${t.name}'), isTrue);
    }
    for (final m in MazeMode.values) {
      expect(allStrings.containsKey('maze_escape.mode.${m.name}'), isTrue);
      expect(allStrings.containsKey('maze_escape.sub.${m.name}'), isTrue);
      expect(allStrings.containsKey('maze_escape.tagline.${m.name}'), isTrue);
    }
  });

  group('maze_escape screens render in every language', () {
    tearDown(() => I18n.lang.value = AppLang.en);
    for (final lang in AppLang.values) {
      testWidgets(lang.code, (t) async {
        SharedPreferences.setMockInitialValues({});
        await Storage.init();
        I18n.lang.value = lang;
        t.view.physicalSize = const Size(360, 640);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);

        await t.pumpWidget(const MaterialApp(home: MazeEscapeScreen()));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        expect(find.text(tr('maze_escape.title')), findsOneWidget);

        for (final m in MazeMode.values) {
          await t.pumpWidget(const MaterialApp(home: MazeEscapeScreen()));
          await t.pump(const Duration(seconds: 1));
          await t.ensureVisible(find.byKey(ValueKey('mode-${m.name}')));
          await t.pump();
          await t.tap(find.byKey(ValueKey('mode-${m.name}')));
          await t.pump(const Duration(seconds: 1));
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull);
          expect(find.text(tr('maze_escape.choose_difficulty')), findsOneWidget);
          await t.ensureVisible(find.text(tr('common.tier.easy')));
          await t.pump();
          await t.tap(find.text(tr('common.tier.easy')));
          await t.pump(const Duration(seconds: 1));
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        }

        await t.pumpWidget(const MaterialApp(home: LabyrinthGame(tier: MazeTier.hard, level: 9)));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));

        await t.pumpWidget(const MaterialApp(home: MemoryMazeGame(tier: MazeTier.extreme, level: 1)));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        expect(find.text(tr('maze_escape.memorise')), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 4));
      });
    }
  });
}
