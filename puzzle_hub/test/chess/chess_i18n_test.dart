import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/all.dart';
import 'package:puzzle_hub/core/i18n/strings/chess.dart';

import 'chess_widget_test.dart' show openChess, tapStart, tapSquare, disposeScreen;

const langCodes = ['en', 'hi', 'hinglish', 'te', 'ta', 'pa', 'bho', 'mr', 'sa'];

Set<String> _ph(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

void main() {
  test('chess strings: all 9 languages, non-empty, same placeholders', () {
    expect(chessStrings, isNotEmpty);
    expect(langCodes.toSet(), AppLang.values.map((l) => l.code).toSet());
    for (final MapEntry(:key, :value) in chessStrings.entries) {
      expect(key.startsWith('chess.'), isTrue, reason: key);
      expect(value.keys.toSet(), langCodes.toSet(), reason: key);
      for (final c in langCodes) {
        expect(value[c]!.trim(), isNotEmpty, reason: '$key/$c');
        expect(_ph(value[c]!), _ph(value['en']!), reason: '$key/$c placeholders');
      }
    }
  });

  test('scripts: Devanagari / Telugu / Tamil / Gurmukhi where expected', () {
    final scripts = {
      'hi': RegExp(r'[ऀ-ॿ]'),
      'bho': RegExp(r'[ऀ-ॿ]'),
      'mr': RegExp(r'[ऀ-ॿ]'),
      'sa': RegExp(r'[ऀ-ॿ]'),
      'te': RegExp(r'[ఀ-౿]'),
      'ta': RegExp(r'[஀-௿]'),
      'pa': RegExp(r'[਀-੿]'),
    };
    for (final MapEntry(:key, :value) in chessStrings.entries) {
      for (final MapEntry(key: lang, value: re) in scripts.entries) {
        expect(re.hasMatch(value[lang]!), isTrue, reason: '$key/$lang');
      }
      expect(RegExp(r'[ऀ-෿]').hasMatch(value['hinglish']!), isFalse, reason: '$key/hinglish is Roman');
    }
  });

  test('every tr() key used by the chess sources exists', () {
    final re = RegExp(r"tr\('([a-z0-9_.]+)'");
    var found = 0;
    for (final f in Directory('lib/games/chess').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final m in re.allMatches(f.readAsStringSync())) {
        found++;
        expect(allStrings.containsKey(m.group(1)), isTrue, reason: '${m.group(1)} in ${f.path}');
      }
    }
    expect(found, greaterThan(20));
  });

  for (final lang in AppLang.values) {
    testWidgets('chess renders in ${lang.code} at 360x640', (t) async {
      I18n.lang.value = lang;
      addTearDown(() => I18n.lang.value = AppLang.en);
      await openChess(t);
      expect(t.takeException(), isNull);
      expect(find.text(tr('chess.title')), findsWidgets);
      expect(find.text(tr('common.tier.easy')), findsOneWidget);
      // 2-player menu too.
      await t.tap(find.byKey(const ValueKey('mode_pvp')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('chess.auto_rotate')), findsOneWidget);
      expect(t.takeException(), isNull);
      // Start a 2-player game, play a move, open the resign dialog.
      await tapStart(t);
      await t.pump(const Duration(milliseconds: 400));
      await tapSquare(t, 'e2');
      await tapSquare(t, 'e4');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('chess.turn_black')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('resignBtn')));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text(tr('chess.resign_q')), findsOneWidget);
      await t.tap(find.text(tr('chess.resign')).last);
      await t.pump(const Duration(seconds: 1));
      expect(find.text(tr('chess.white_wins')), findsOneWidget);
      expect(t.takeException(), isNull);
      await disposeScreen(t);
    });
  }
}
