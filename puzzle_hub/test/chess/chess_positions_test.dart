import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/chess/logic/chess_engine.dart';
import 'package:puzzle_hub/games/chess/logic/chess_game.dart';
import 'package:puzzle_hub/games/chess/logic/chess_positions.dart';

void main() {
  test('at least 40 curated positions with unique names and FENs', () {
    expect(midgamePositions.length, greaterThanOrEqualTo(40));
    expect(midgamePositions.map((p) => p.name).toSet().length, midgamePositions.length);
    expect(midgamePositions.map((p) => p.fen).toSet().length, midgamePositions.length);
    // Side to move varies.
    final white = midgamePositions.where((p) => Position.fromFen(p.fen).whiteToMove).length;
    expect(white, inInclusiveRange(10, midgamePositions.length - 10));
  });

  for (final mp in midgamePositions) {
    test('legal, playable middlegame: ${mp.name}', () {
      final pos = Position.fromFen(mp.fen);
      expect(pos.toFen(), mp.fen, reason: 'FEN round-trips');
      // Exactly one king each.
      expect(pos.board.where((p) => p == pKing).length, 1);
      expect(pos.board.where((p) => p == -pKing).length, 1);
      // No pawns on the back ranks.
      for (var f = 0; f < 8; f++) {
        expect(pos.board[f].abs() == pPawn, isFalse);
        expect(pos.board[56 + f].abs() == pPawn, isFalse);
      }
      // The side NOT to move is not in check.
      final idleKing = pos.whiteToMove ? pos.blackKing : pos.whiteKing;
      expect(pos.isAttacked(idleKing, pos.whiteToMove), isFalse);
      // Enough play, not over.
      expect(pos.legalMoves().length, greaterThanOrEqualTo(10));
      final g = ChessGame(mp.fen);
      expect(g.over, isFalse);
      expect(g.result, ChessResult.ongoing);
      // Roughly balanced material, a real middlegame.
      expect(g.materialDiff().abs(), lessThanOrEqualTo(1));
      expect(pos.board.where((p) => p != 0).length, greaterThanOrEqualTo(20));
      expect(pos.fullmove, greaterThanOrEqualTo(9));
    });
  }

  test('randomMidgame picks from the list', () {
    for (var i = 0; i < 20; i++) {
      expect(midgamePositions.contains(randomMidgame()), isTrue);
    }
  });
}
