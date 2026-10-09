import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/chess/chess_screen.dart';
import 'package:puzzle_hub/games/chess/logic/chess_engine.dart';
import 'package:puzzle_hub/games/chess/logic/chess_positions.dart';
import 'package:puzzle_hub/games/chess/widgets/chess_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openChess(WidgetTester t, {Size size = const Size(360, 640), Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  await Storage.init();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(const MaterialApp(home: ChessScreen()));
  await t.pump(const Duration(milliseconds: 600));
}

/// Taps square [name] (e.g. 'e2') on the board, white at the bottom.
Future<void> tapSquare(WidgetTester t, String name, {bool flipped = false}) async {
  final r = t.getRect(find.byKey(const ValueKey('chessBoard')));
  final cell = r.width / 8;
  var col = name.codeUnitAt(0) - 97, row = 7 - (name.codeUnitAt(1) - 49);
  if (flipped) {
    col = 7 - col;
    row = 7 - row;
  }
  await t.tapAt(Offset(r.left + (col + 0.5) * cell, r.top + (row + 0.5) * cell));
  await t.pump(const Duration(milliseconds: 50));
}

/// Scrolls the menu to the start button and taps it.
Future<void> tapStart(WidgetTester t) async {
  final f = find.byKey(const ValueKey('startGame'));
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.pump(const Duration(milliseconds: 500));
  await t.tap(f);
}

Finder historyText(RegExp re) => find.byWidgetPredicate((w) => w is Text && w.data != null && re.hasMatch(w.data!));

Future<void> waitFor(WidgetTester t, Finder f, {int tries = 100}) async {
  for (var i = 0; i < tries && f.evaluate().isEmpty; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await t.pump(const Duration(milliseconds: 120));
  }
}

Future<void> disposeScreen(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('3-min game vs computer: move, AI replies, free undo', (t) async {
    await openChess(t);
    expect(find.text('Chess'), findsWidgets);
    await t.tap(find.byKey(const ValueKey('mode_cpu')));
    await t.tap(find.byKey(const ValueKey('level_easy')));
    await t.tap(find.byKey(const ValueKey('tc_3m')));
    await t.pump();
    await tapStart(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('chessBoard')), findsOneWidget);
    expect(find.text('3:00'), findsNWidgets(2));

    await tapSquare(t, 'e2');
    await tapSquare(t, 'e4');
    expect(historyText(RegExp(r'^1\. e4')), findsOneWidget);

    await waitFor(t, historyText(RegExp(r'^1\. e4 \S+')));
    expect(historyText(RegExp(r'^1\. e4 \S+')), findsOneWidget, reason: 'computer replied');
    expect(t.takeException(), isNull);

    // Black's clock started after white's first move.
    await t.pump(const Duration(milliseconds: 300));

    // Free undo takes back both moves.
    await t.tap(find.byKey(const ValueKey('undoBtn')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('No moves yet'), findsOneWidget);
    await disposeScreen(t);
  });

  testWidgets('play as black: computer moves first; illegal tap ignored', (t) async {
    await openChess(t, prefs: {'chess.pref.color': 1, 'chess.pref.level': 1});
    await tapStart(t);
    await t.pump(const Duration(milliseconds: 200));
    await waitFor(t, historyText(RegExp(r'^1\. \S+')));
    expect(historyText(RegExp(r'^1\. \S+')), findsOneWidget);
    // Try an illegal move for black (rook through pawns).
    await tapSquare(t, 'a8', flipped: true);
    await tapSquare(t, 'a5', flipped: true);
    expect(historyText(RegExp(r'^1\. \S+ \S+')), findsNothing);
    expect(t.takeException(), isNull);
    await disposeScreen(t);
  });

  testWidgets('2 players: fool\'s mate shows result and records stats', (t) async {
    await openChess(t, prefs: {'chess.pref.mode': 1, 'chess.pref.rotate': false});
    await tapStart(t);
    await t.pump(const Duration(milliseconds: 200));
    for (final (a, b) in [('f2', 'f3'), ('e7', 'e5'), ('g2', 'g4'), ('d8', 'h4')]) {
      await tapSquare(t, a);
      await tapSquare(t, b);
    }
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Black wins!'), findsOneWidget);
    expect(find.textContaining('Checkmate'), findsOneWidget);
    expect(Storage.getInt('chess.pvp.3m.l'), 1);
    expect(t.takeException(), isNull);
    await disposeScreen(t);
  });

  testWidgets('menu lists all time controls and 2-player options', (t) async {
    await openChess(t);
    for (final id in ['2m', '3m', '3m2', '5m', '5m3', '10m']) {
      expect(find.byKey(ValueKey('tc_$id')), findsOneWidget);
    }
    await t.tap(find.byKey(const ValueKey('mode_pvp')));
    await t.pump();
    expect(find.text('Auto-rotate board'), findsOneWidget);
    expect(I18n.lang.value, AppLang.en);
    await disposeScreen(t);
  });

  midgameTests();
}

/// Reads the board shown on screen and returns the squares of a legal,
/// non-promoting, non-castling move for [white] in that position.
(String, String) pickMove(WidgetTester t, {bool white = true}) {
  final board = t.widget<ChessBoardView>(find.byType(ChessBoardView)).board;
  final sb = StringBuffer();
  for (var r = 7; r >= 0; r--) {
    var empty = 0;
    for (var f = 0; f < 8; f++) {
      final p = board[r * 8 + f];
      if (p == 0) {
        empty++;
        continue;
      }
      if (empty > 0) sb.write(empty);
      empty = 0;
      final ch = 'pnbrqk'[p.abs() - 1];
      sb.write(p > 0 ? ch.toUpperCase() : ch);
    }
    if (empty > 0) sb.write(empty);
    if (r > 0) sb.write('/');
  }
  final pos = Position.fromFen('$sb ${white ? 'w' : 'b'} - - 0 1');
  final m = pos.legalMoves().firstWhere((m) => movePromo(m) == 0);
  return (sqName(moveFrom(m)), sqName(moveTo(m)));
}

void midgameTests() {
  testWidgets('2-minute mid-game vs computer: header label, move, AI replies', (t) async {
    await openChess(t, prefs: {'chess.pref.start': 1, 'chess.pref.tc': 0});
    await t.tap(find.byKey(const ValueKey('mode_cpu')));
    await t.tap(find.byKey(const ValueKey('level_easy')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('tc_2m')));
    await t.pump();
    await t.scrollUntilVisible(find.text(tr('chess.mid_hint')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('start_std')), findsOneWidget);
    expect(find.byKey(const ValueKey('start_mid')), findsOneWidget);
    await tapStart(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('chessBoard')), findsOneWidget);
    expect(find.text('2:00'), findsNWidgets(2));
    final label = t.widget<Text>(find.byKey(const ValueKey('midLabel'))).data!;
    expect(midgamePositions.any((p) => label.endsWith(p.name)), isTrue, reason: label);
    expect(find.text('No moves yet'), findsOneWidget);

    // If black is to move the computer opens; wait for the player's turn.
    final yourTurn = find.text(tr('chess.your_turn'));
    await waitFor(t, yourTurn);
    expect(yourTurn, findsOneWidget);
    final before = historyText(RegExp(r'^\d+\. ')).evaluate().length;

    final (from, to) = pickMove(t);
    await tapSquare(t, from);
    await tapSquare(t, to);
    await t.pump(const Duration(milliseconds: 100));
    expect(yourTurn, findsNothing, reason: 'move accepted, computer to play');
    final afterMine = List<int>.of(t.widget<ChessBoardView>(find.byType(ChessBoardView)).board);

    await waitFor(t, yourTurn);
    expect(yourTurn, findsOneWidget, reason: 'computer replied');
    expect(t.widget<ChessBoardView>(find.byType(ChessBoardView)).board, isNot(afterMine));
    expect(historyText(RegExp(r'^\d+\. ')).evaluate().length, greaterThanOrEqualTo(before));
    expect(Storage.getInt('chess.pref.start'), 1);
    expect(t.takeException(), isNull);
    await disposeScreen(t);
  });

  testWidgets('mid-game in 2 players: side to move plays first; standard still default', (t) async {
    await openChess(t, prefs: {'chess.pref.mode': 1, 'chess.pref.rotate': false});
    // Default is the standard start.
    await tapStart(t);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('midLabel')), findsNothing);
    await disposeScreen(t);

    await openChess(t, prefs: {'chess.pref.mode': 1, 'chess.pref.rotate': false, 'chess.pref.start': 1, 'chess.pref.tc': 5});
    await tapStart(t);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('midLabel')), findsOneWidget);
    expect(find.text('10:00'), findsNWidgets(2));
    final whiteToMove = find.text(tr('chess.turn_white')).evaluate().isNotEmpty;
    final (from, to) = pickMove(t, white: whiteToMove);
    await tapSquare(t, from);
    await tapSquare(t, to);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(tr(whiteToMove ? 'chess.turn_black' : 'chess.turn_white')), findsOneWidget);
    // Black-to-move starts show "N. ... move".
    if (!whiteToMove) expect(historyText(RegExp(r'^\d+\. \.\.\. \S+')), findsOneWidget);
    expect(t.takeException(), isNull);
    await disposeScreen(t);
  });
}
