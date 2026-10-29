import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/cloud/online_service.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/online.dart';
import 'package:puzzle_hub/games/chess/online/online_lobby_screen.dart';

import 'chess_widget_test.dart' show openChess, disposeScreen;

void main() {
  test('online strings: all 9 languages, identical placeholders', () {
    final ph = RegExp(r'\{(\w+)\}');
    for (final e in onlineStrings.entries) {
      final want = ph.allMatches(e.value['en']!).map((m) => m[1]).toSet();
      for (final l in AppLang.tableLangs) {
        final s = e.value[l.code];
        expect(s, isNotNull, reason: '${e.key} missing ${l.code}');
        expect(ph.allMatches(s!).map((m) => m[1]).toSet(), want, reason: '${e.key} ${l.code}');
      }
    }
  });

  test('online game document: turns and result', () {
    final g = OnlineGame.fromDoc('g1', {
      'white': 'a',
      'black': 'b',
      'whiteName': 'ann',
      'blackName': 'bob',
      'moves': ['e2e4', 'e7e5', 'g1f3'],
      'status': 'active',
    });
    expect(g.whiteToMove, isFalse);
    expect(g.turnUid(), 'b');
    expect(g.over, isFalse);
    final over = OnlineGame.fromDoc('g1', {'white': 'a', 'black': 'b', 'moves': const [], 'status': 'over', 'result': 'draw'});
    expect(over.over, isTrue);
    expect(over.result, 'draw');
  });

  test('handle rules and suggestions', () {
    expect(OnlineService.handlePattern.hasMatch('adarsh_47'), isTrue);
    expect(OnlineService.handlePattern.hasMatch('ab'), isFalse);
    expect(OnlineService.handlePattern.hasMatch('Has Space'), isFalse);
    final s = OnlineService.suggestHandle('Adarsh Kumar!');
    expect(OnlineService.handlePattern.hasMatch(s), isTrue);
    expect(s.startsWith('adarshkumar'), isTrue);
  });

  testWidgets('chess menu opens the online lobby (cloud not set up on the test host)', (t) async {
    await openChess(t);
    final f = find.byKey(const ValueKey('mode_online'));
    expect(f, findsOneWidget);
    await t.tap(f);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(OnlineLobbyScreen), findsOneWidget);
    expect(t.takeException(), isNull);
    await disposeScreen(t);
  });
}
