import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/chess/logic/chess_ai.dart';
import 'package:puzzle_hub/games/chess/logic/chess_engine.dart';
import 'package:puzzle_hub/games/chess/logic/chess_game.dart';

void main() {
  test('every level returns a legal move quickly from the start', () {
    for (final lvl in ChessLevel.values) {
      final cfg = AiConfig.levels[lvl]!;
      final g = ChessGame();
      final sw = Stopwatch()..start();
      final uci = chessSearchEntry(chessSearchRequest(g.pos, g.hashHistory, cfg, timeMs: 800));
      expect(sw.elapsedMilliseconds, lessThan(2500), reason: lvl.name);
      expect(g.pos.findUci(uci), isNotNull, reason: '${lvl.name}: $uci');
    }
  });

  test('finds mate in one', () {
    // White: Qh5 + Bc4 vs weakened f7 -> Qxf7#.
    final g = ChessGame('r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4');
    final uci = chessSearchEntry(chessSearchRequest(g.pos, g.hashHistory, AiConfig.levels[ChessLevel.hard]!));
    expect(uci, 'h5f7');
  });

  test('captures a hanging queen', () {
    final g = ChessGame('4k3/8/8/3q4/8/8/3R4/4K3 w - - 0 1');
    final uci = chessSearchEntry(chessSearchRequest(g.pos, g.hashHistory, AiConfig.levels[ChessLevel.medium]!.withoutNoise));
    expect(uci, 'd2d5');
  });

  test('returns empty when no legal moves', () {
    final g = ChessGame('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
    expect(chessSearchEntry(chessSearchRequest(g.pos, g.hashHistory, AiConfig.levels[ChessLevel.easy]!)), '');
  });

  test('search runs inside an isolate via compute', () async {
    final g = ChessGame();
    g.playSan('e4');
    final uci = await compute(chessSearchEntry, chessSearchRequest(g.pos, g.hashHistory, AiConfig.levels[ChessLevel.hard]!, timeMs: 500));
    expect(g.pos.findUci(uci), isNotNull);
  });

  test('evaluation is symmetric', () {
    final p = Position.start();
    expect(evaluate(p), 0);
  });
}

extension on AiConfig {
  AiConfig get withoutNoise => AiConfig(depth, timeMs, 0);
}
