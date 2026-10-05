import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/all.dart';
import 'package:puzzle_hub/core/i18n/strings/screw_jam.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/screw_jam/logic/screw_jam_logic.dart';
import 'package:puzzle_hub/games/screw_jam/screw_jam_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _langs = {'en', 'hi', 'hinglish', 'te', 'ta', 'pa', 'bho'};
final _ph = RegExp(r'\{(\w+)\}');

void main() {
  test('screw_jam strings: all 7 languages, identical placeholders', () {
    expect(screwJamStrings, isNotEmpty);
    for (final MapEntry(:key, :value) in screwJamStrings.entries) {
      expect(key.startsWith('screw_jam.'), isTrue, reason: key);
      expect(value.keys.toSet(), _langs, reason: '$key languages');
      final en = _ph.allMatches(value['en']!).map((m) => m[1]).toSet();
      for (final MapEntry(key: lang, value: s) in value.entries) {
        expect(s.trim(), isNotEmpty, reason: '$key.$lang empty');
        expect(_ph.allMatches(s).map((m) => m[1]).toSet(), en, reason: '$key.$lang placeholders');
      }
    }
    expect(allStrings.containsKey('screw_jam.title'), isTrue);
  });

  test('every tr() key used by the game exists', () {
    final re = RegExp(r"""tr\(\s*'([a-z_]+\.[a-z0-9_.]+)'""");
    for (final f in Directory('lib/games/screw_jam').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in re.allMatches(f.readAsStringSync())) {
        expect(allStrings.containsKey(m[1]), isTrue, reason: '${m[1]} used in ${f.path}');
      }
    }
    for (final t in SjTier.values) {
      expect(allStrings.containsKey('common.tier.${t.id}'), isTrue);
      expect(screwJamStrings.containsKey('screw_jam.desc.${t.id}'), isTrue);
    }
  });

  group('screw jam renders in every language at 360x640', () {
    tearDown(() => I18n.lang.value = AppLang.en);
    for (final lang in AppLang.values) {
      testWidgets(lang.code, (t) async {
        SharedPreferences.setMockInitialValues({});
        await Storage.init();
        I18n.lang.value = lang;
        t.view.physicalSize = const Size(360, 640);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);

        await t.pumpWidget(const MaterialApp(home: ScrewJamScreen()));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        expect(find.text(tr('screw_jam.choose')), findsOneWidget);

        await t.tap(find.text(tr('common.tier.easy')).first);
        await t.pump(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        expect(find.text(tr('screw_jam.play_level', {'n': 1})), findsOneWidget);

        for (final tier in [SjTier.easy, SjTier.extreme]) {
          await t.pumpWidget(const SizedBox());
          await t.pumpWidget(MaterialApp(home: ScrewJamGame(tier: tier, level: tier == SjTier.easy ? 1 : 30)));
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull);
          expect(find.text(tr('screw_jam.title')), findsOneWidget);
          // A blocked tap shows the toast without overflowing.
          final g = SjGame(sjGenerate(tier, 1));
          final blocked = g.level.screws.where((s) => g.isBlocked(s.id));
          if (tier == SjTier.easy && blocked.isNotEmpty) {
            await t.tap(find.byKey(ValueKey('sj_screw_${blocked.first.id}')));
            await t.pump(const Duration(milliseconds: 300));
            expect(t.takeException(), isNull);
          }
          // Play one move: flight + tray/box rendering.
          final first = SjGame(sjGenerate(tier, tier == SjTier.easy ? 1 : 30)).level.solution.first;
          await t.tap(find.byKey(ValueKey('sj_screw_$first')));
          await t.pump(const Duration(milliseconds: 300));
          await t.pump(const Duration(seconds: 2));
          expect(t.takeException(), isNull);
        }

        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      });
    }
  });
}
