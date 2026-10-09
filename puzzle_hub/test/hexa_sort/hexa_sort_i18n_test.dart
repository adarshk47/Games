import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/all.dart';
import 'package:puzzle_hub/core/i18n/strings/hexa_sort.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/hexa_sort/hexa_sort_screen.dart';
import 'package:puzzle_hub/games/hexa_sort/logic/hexa_sort_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _langs = {for (final l in AppLang.values) l.code};
final _ph = RegExp(r'\{(\w+)\}');

void main() {
  test('hexa_sort strings: all 9 languages, identical placeholders, native scripts', () {
    expect(hexaSortStrings, isNotEmpty);
    final scripts = {
      'hi': RegExp(r'[ऀ-ॿ]'),
      'bho': RegExp(r'[ऀ-ॿ]'),
      'mr': RegExp(r'[ऀ-ॿ]'),
      'sa': RegExp(r'[ऀ-ॿ]'),
      'te': RegExp(r'[ఀ-౿]'),
      'ta': RegExp(r'[஀-௿]'),
      'pa': RegExp(r'[਀-੿]'),
    };
    for (final MapEntry(:key, :value) in hexaSortStrings.entries) {
      expect(key.startsWith('hexa_sort.'), isTrue, reason: key);
      expect(value.keys.toSet(), _langs, reason: '$key languages');
      final en = _ph.allMatches(value['en']!).map((m) => m[1]).toSet();
      for (final MapEntry(key: lang, value: s) in value.entries) {
        expect(s.trim(), isNotEmpty, reason: '$key.$lang empty');
        expect(_ph.allMatches(s).map((m) => m[1]).toSet(), en, reason: '$key.$lang placeholders');
        final re = scripts[lang];
        if (re != null && key != 'hexa_sort.combo') {
          expect(re.hasMatch(s), isTrue, reason: '$key.$lang script');
        }
      }
    }
    expect(allStrings.containsKey('hexa_sort.title'), isTrue);
  });

  test('every tr() key used by the game exists', () {
    final re = RegExp(r"""tr\(\s*'([a-z_]+\.[a-z0-9_.]+)'""");
    for (final f in Directory('lib/games/hexa_sort').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in re.allMatches(f.readAsStringSync())) {
        expect(allStrings.containsKey(m[1]), isTrue, reason: '${m[1]} used in ${f.path}');
      }
    }
    for (final t in HsTier.values) {
      expect(allStrings.containsKey('common.tier.${t.id}'), isTrue);
      expect(hexaSortStrings.containsKey('hexa_sort.desc.${t.id}'), isTrue);
    }
  });

  group('hexa sort renders in every language at 360x640', () {
    tearDown(() => I18n.lang.value = AppLang.en);
    for (final lang in AppLang.values) {
      testWidgets(lang.code, (t) async {
        SharedPreferences.setMockInitialValues({});
        await Storage.init();
        I18n.lang.value = lang;
        t.view.physicalSize = const Size(360, 640);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);

        await t.pumpWidget(const MaterialApp(home: HexaSortScreen()));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        expect(find.text(tr('hexa_sort.choose')), findsOneWidget);

        await t.tap(find.text(tr('common.tier.easy')).first);
        await t.pump(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        expect(find.text(tr('hexa_sort.play_level', {'n': 1})), findsOneWidget);

        for (final (tier, n) in [(HsTier.easy, 1), (HsTier.extreme, 100)]) {
          await t.pumpWidget(const SizedBox());
          await t.pumpWidget(MaterialApp(home: HexaSortGame(tier: tier, level: n)));
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull);
          expect(find.text(tr('hexa_sort.title')), findsOneWidget);
          // Place the first offer on the first empty cell and let it resolve.
          final g = HsGame(hsGenerate(tier, n));
          final cell = g.emptyCells.first;
          await t.tap(find.byKey(const ValueKey('hs_offer_0')));
          await t.pump(const Duration(milliseconds: 100));
          await t.tap(find.byKey(ValueKey('hs_cell_$cell')));
          await t.pump(const Duration(milliseconds: 300));
          await t.pump(const Duration(seconds: 2));
          expect(t.takeException(), isNull);
          expect(find.text(tr('hexa_sort.moves', {'n': 1})), findsOneWidget);
          // A stone cell (extreme) shows the toast without overflow.
          if (g.board.blocked.isNotEmpty) {
            await t.tap(find.byKey(ValueKey('hs_cell_${g.board.blocked.first}')));
            await t.pump(const Duration(milliseconds: 300));
            expect(find.text(tr('hexa_sort.blocked')), findsOneWidget);
            expect(t.takeException(), isNull);
          }
        }

        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      });
    }
  });
}
