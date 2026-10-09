import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/all.dart';
import 'package:puzzle_hub/core/i18n/strings/bus_jam.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/bus_jam/bus_jam_screen.dart';
import 'package:puzzle_hub/games/bus_jam/logic/bus_jam_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _langs = {'en', 'hi', 'hinglish', 'te', 'ta', 'pa', 'bho', 'mr', 'sa'};
final _ph = RegExp(r'\{(\w+)\}');

void main() {
  test('bus_jam strings: all 9 languages, identical placeholders', () {
    expect(busJamStrings, isNotEmpty);
    expect(AppLang.values.map((l) => l.code).toSet(), _langs);
    for (final MapEntry(:key, :value) in busJamStrings.entries) {
      expect(key.startsWith('bus_jam.'), isTrue, reason: key);
      expect(value.keys.toSet(), _langs, reason: '$key languages');
      final en = _ph.allMatches(value['en']!).map((m) => m[1]).toSet();
      for (final MapEntry(key: lang, value: s) in value.entries) {
        expect(s.trim(), isNotEmpty, reason: '$key.$lang empty');
        expect(_ph.allMatches(s).map((m) => m[1]).toSet(), en, reason: '$key.$lang placeholders');
      }
    }
    expect(allStrings.containsKey('bus_jam.title'), isTrue);
  });

  test('every tr() key used by the game exists', () {
    final re = RegExp(r"""tr\(\s*'([a-z_]+\.[a-z0-9_.]+)'""");
    for (final f in Directory('lib/games/bus_jam').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in re.allMatches(f.readAsStringSync())) {
        expect(allStrings.containsKey(m[1]), isTrue, reason: '${m[1]} used in ${f.path}');
      }
    }
    for (final t in BjTier.values) {
      expect(allStrings.containsKey('common.tier.${t.id}'), isTrue);
      expect(busJamStrings.containsKey('bus_jam.desc.${t.id}'), isTrue);
    }
  });

  group('bus jam renders in every language at 360x640', () {
    tearDown(() => I18n.lang.value = AppLang.en);
    for (final lang in AppLang.values) {
      testWidgets(lang.code, (t) async {
        SharedPreferences.setMockInitialValues({});
        await Storage.init();
        I18n.lang.value = lang;
        t.view.physicalSize = const Size(360, 640);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);

        await t.pumpWidget(const MaterialApp(home: BusJamScreen()));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        expect(find.text(tr('bus_jam.choose')), findsOneWidget);

        await t.tap(find.text(tr('common.tier.easy')).first);
        await t.pump(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        expect(find.text(tr('bus_jam.play_level', {'n': 1})), findsOneWidget);

        for (final (tier, level) in [(BjTier.easy, 1), (BjTier.extreme, 100)]) {
          await t.pumpWidget(const SizedBox());
          await t.pumpWidget(MaterialApp(home: BusJamGame(tier: tier, level: level)));
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull);
          expect(find.text(tr('bus_jam.title')), findsOneWidget);
          final g = BjGame(bjGenerate(tier, level));
          // A blocked tap shows the toast without overflowing.
          final blocked = g.crowd.where((id) => !g.canTap(id));
          if (blocked.isNotEmpty) {
            await t.tap(find.byKey(ValueKey('bj_p_${blocked.first}')), warnIfMissed: false);
            await t.pump(const Duration(milliseconds: 300));
            expect(t.takeException(), isNull);
          }
          // A few moves: walking, boarding, waiting area.
          for (final id in g.level.solution.take(4)) {
            await t.tap(find.byKey(ValueKey('bj_p_$id')));
            await t.pump(const Duration(milliseconds: 200));
          }
          await t.pump(const Duration(seconds: 3));
          expect(t.takeException(), isNull);
        }

        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      });
    }
  });
}
