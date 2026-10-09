import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/all.dart';
import 'package:puzzle_hub/core/i18n/strings/tile_match.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/tile_match/logic/tile_match_logic.dart';
import 'package:puzzle_hub/games/tile_match/tile_match_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _langs = {for (final l in AppLang.values) l.code};
final _ph = RegExp(r'\{(\w+)\}');

void main() {
  test('tile_match strings: all 9 languages, identical placeholders', () {
    expect(tileMatchStrings, isNotEmpty);
    for (final MapEntry(:key, :value) in tileMatchStrings.entries) {
      expect(key.startsWith('tile_match.'), isTrue, reason: key);
      expect(value.keys.toSet(), _langs, reason: '$key languages');
      final en = _ph.allMatches(value['en']!).map((m) => m[1]).toSet();
      for (final MapEntry(key: lang, value: s) in value.entries) {
        expect(s.trim(), isNotEmpty, reason: '$key.$lang empty');
        expect(_ph.allMatches(s).map((m) => m[1]).toSet(), en, reason: '$key.$lang placeholders');
      }
      // Native scripts (not Latin) for the Indic languages.
      for (final lang in ['hi', 'te', 'ta', 'pa', 'bho', 'mr', 'sa']) {
        final letters = value[lang]!.replaceAll(_ph, '').replaceAll(RegExp(r'[^A-Za-zऀ-෿਀-੿]'), '');
        final latin = letters.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
        expect(latin * 2 <= letters.length, isTrue, reason: '$key.$lang should use its own script');
      }
    }
    expect(allStrings.containsKey('tile_match.title'), isTrue);
  });

  test('every tr() key used by the game exists', () {
    final re = RegExp(r"""tr\(\s*'([a-z_]+\.[a-z0-9_.]+)'""");
    for (final f in Directory('lib/games/tile_match').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in re.allMatches(f.readAsStringSync())) {
        expect(allStrings.containsKey(m[1]), isTrue, reason: '${m[1]} used in ${f.path}');
      }
    }
    for (final t in TmTier.values) {
      expect(allStrings.containsKey('common.tier.${t.id}'), isTrue);
      expect(tileMatchStrings.containsKey('tile_match.desc.${t.id}'), isTrue);
    }
  });

  group('tile match renders in every language at 360x640', () {
    tearDown(() => I18n.lang.value = AppLang.en);
    for (final lang in AppLang.values) {
      testWidgets(lang.code, (t) async {
        SharedPreferences.setMockInitialValues({});
        await Storage.init();
        I18n.lang.value = lang;
        t.view.physicalSize = const Size(360, 640);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);

        await t.pumpWidget(MaterialApp(theme: ThemeData(splashFactory: InkRipple.splashFactory), home: const TileMatchScreen()));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        expect(find.text(tr('tile_match.choose')), findsOneWidget);

        await t.tap(find.text(tr('common.tier.easy')).first);
        await t.pump(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        expect(find.text(tr('tile_match.play_level', {'n': 1})), findsOneWidget);

        // Skip dialog for a locked level.
        await t.tap(find.byKey(const ValueKey('tm_level_5')));
        await t.pump(const Duration(milliseconds: 500));
        await t.pump(const Duration(milliseconds: 500));
        expect(t.takeException(), isNull);
        expect(find.text(tr('common.skip.title', {'n': 5})), findsOneWidget);
        await t.tap(find.text(tr('common.cancel')));
        await t.pump(const Duration(milliseconds: 500));
        await t.pump(const Duration(milliseconds: 500));
        expect(find.text(tr('common.skip.title', {'n': 5})), findsNothing);

        for (final (tier, level) in [(TmTier.easy, 1), (TmTier.extreme, 100)]) {
          await t.pumpWidget(const SizedBox());
          await t.pumpWidget(MaterialApp(theme: ThemeData(splashFactory: InkRipple.splashFactory), home: TileMatchGame(tier: tier, level: level)));
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull);
          expect(find.text(tr('tile_match.title')), findsOneWidget);
          final lv = tmGenerate(tier, level);
          // A covered tap shows the toast without overflowing.
          final g = TmGame(lv);
          final covered = lv.tiles.where((x) => !g.isFree(x.id) && lv.above[x.id].length == 1).firstOrNull;
          if (covered != null) {
            final box = t.getRect(find.byKey(ValueKey('tm_tile_${covered.id}')));
            final top = lv.tiles[lv.above[covered.id].first];
            await t.tapAt(Offset(top.x > covered.x ? box.left + 2 : box.right - 2, top.y > covered.y ? box.top + 2 : box.bottom - 2));
            await t.pump(const Duration(milliseconds: 300));
            expect(t.takeException(), isNull);
          }
          // Three solution moves: flight, tray and (maybe) a match burst.
          for (final id in lv.solution.take(3)) {
            await t.tap(find.byKey(ValueKey('tm_tile_$id')));
            await t.pump(const Duration(milliseconds: 150));
            await t.pump(const Duration(milliseconds: 600));
          }
          expect(t.takeException(), isNull);
        }

        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      });
    }
  });
}
