import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/chess/logic/chess_engine.dart';
import 'package:puzzle_hub/games/chess/logic/chess_game.dart';

const kiwipete = 'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1';

void main() {
  group('perft', () {
    test('start position depth 1-3', () {
      final p = Position.start();
      expect(perft(p, 1), 20);
      expect(perft(p, 2), 400);
      expect(perft(p, 3), 8902);
    });

    test('kiwipete depth 1-2', () {
      final p = Position.fromFen(kiwipete);
      expect(perft(p, 1), 48);
      expect(perft(p, 2), 2039);
    });

    test('position 3 (en passant / pins) depth 1-3', () {
      final p = Position.fromFen('8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1');
      expect(perft(p, 1), 14);
      expect(perft(p, 2), 191);
      expect(perft(p, 3), 2812);
    });

    test('position 4 (promotions / castling) depth 1-2', () {
      final p = Position.fromFen('r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1');
      expect(perft(p, 1), 6);
      expect(perft(p, 2), 264);
    });

    test('make/unmake restores FEN and incremental hash', () {
      final p = Position.fromFen(kiwipete);
      final fen = p.toFen();
      void walk(int d) {
        if (d == 0) return;
        for (final m in p.legalMoves()) {
          p.makeMove(m);
          expect(p.hash, p.computeHash(), reason: moveUci(m));
          walk(d - 1);
          p.unmakeMove();
        }
      }

      walk(2);
      expect(p.toFen(), fen);
    });
  });

  group('rules', () {
    test('fool\'s mate is checkmate with # in SAN', () {
      final g = ChessGame();
      for (final s in ['f3', 'e5', 'g4', 'Qh4']) {
        expect(g.playSan(s), isTrue, reason: s);
      }
      expect(g.result, ChessResult.blackWins);
      expect(g.reason, EndReason.checkmate);
      expect(g.sans.last, 'Qh4#');
    });

    test('stalemate', () {
      final g = ChessGame('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      expect(g.result, ChessResult.draw);
      expect(g.reason, EndReason.stalemate);
    });

    test('castling both sides, SAN and rook placement', () {
      final g = ChessGame('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      expect(g.playSan('O-O'), isTrue);
      expect(g.pos.board[sqParse('f1')], pRook);
      expect(g.pos.board[sqParse('g1')], pKing);
      expect(g.playSan('O-O-O'), isTrue);
      expect(g.pos.board[sqParse('d8')], -pRook);
      expect(g.pos.board[sqParse('c8')], -pKing);
      expect(g.sans, ['O-O', 'O-O-O']);
    });

    test('cannot castle through check or after king moved', () {
      final g = ChessGame('r3k2r/8/8/8/8/8/5r2/R3K2R w KQkq - 0 1');
      expect(g.pos.findUci('e1g1'), isNull); // f1/f2 attacked: e1 is not, f1 is attacked by rook f2
      final g2 = ChessGame('4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1');
      g2.playUci('e1f1');
      g2.playUci('e8e7');
      g2.playUci('f1e1');
      g2.playUci('e7e8');
      expect(g2.pos.findUci('e1g1'), isNull);
    });

    test('en passant capture', () {
      final g = ChessGame('4k3/8/8/8/1p6/8/P7/4K3 w - - 0 1');
      expect(g.playUci('a2a4'), isTrue);
      expect(g.pos.ep, sqParse('a3'));
      expect(g.playUci('b4a3'), isTrue);
      expect(g.sans.last, 'bxa3');
      expect(g.pos.board[sqParse('a4')], 0);
      g.undo();
      expect(g.pos.board[sqParse('a4')], pPawn);
    });

    test('promotion with choice and SAN', () {
      final g = ChessGame('8/P6k/8/8/8/8/8/K7 w - - 0 1');
      expect(g.legal.where((m) => movePromo(m) != 0).length, 4);
      final m = g.pos.findMove(sqParse('a7'), sqParse('a8'), pKnight)!;
      expect(g.play(m), isTrue);
      expect(g.pos.board[sqParse('a8')], pKnight);
      expect(g.sans.last, 'a8=N');
    });

    test('SAN disambiguation', () {
      final g = ChessGame('4k3/8/8/R7/8/8/4K3/R6R w - - 0 1');
      final sans = [for (final m in g.legal) g.pos.san(m, g.legal)];
      expect(sans, containsAll(['Rad1', 'Rhd1', 'R1a3', 'R5a3', 'Rab1', 'R1a2', 'Ra6']));
    });

    test('threefold repetition', () {
      final g = ChessGame();
      for (var i = 0; i < 2; i++) {
        for (final s in ['Nf3', 'Nf6', 'Ng1', 'Ng8']) {
          g.playSan(s);
        }
      }
      expect(g.result, ChessResult.draw);
      expect(g.reason, EndReason.repetition);
    });

    test('fifty-move rule', () {
      final g = ChessGame('4k3/8/8/8/8/8/8/R3K3 w - - 99 80');
      g.playUci('a1a2');
      expect(g.reason, EndReason.fiftyMove);
    });

    test('insufficient material', () {
      expect(ChessGame('4k3/8/8/8/8/8/8/4KN2 w - - 0 1').reason, EndReason.insufficient);
      expect(ChessGame('4k3/8/8/8/8/8/8/4K3 w - - 0 1').reason, EndReason.insufficient);
      expect(ChessGame('4kb2/8/8/8/8/8/8/2B1K3 w - - 0 1').reason, EndReason.insufficient);
      expect(ChessGame('4k3/8/8/8/8/8/8/4KR2 w - - 0 1').over, isFalse);
    });

    test('undo restores position and clears result', () {
      final g = ChessGame();
      for (final s in ['f3', 'e5', 'g4', 'Qh4']) {
        g.playSan(s);
      }
      g.undo(2);
      expect(g.over, isFalse);
      expect(g.moves.length, 2);
      expect(g.legal.length, greaterThan(0));
    });

    test('captured pieces and material', () {
      final g = ChessGame();
      for (final s in ['e4', 'd5', 'exd5']) {
        g.playSan(s);
      }
      expect(g.captured(false), [pPawn]);
      expect(g.materialDiff(), 1);
    });
  });

  group('clock', () {
    test('flag on time is a loss, increment added', () {
      final c = ChessClock(const TimeControl(3, 2));
      expect(c.whiteMs, 180000);
      c.consume(true, 5000);
      c.moved(true);
      expect(c.whiteMs, 177000);
      expect(c.consume(false, 179999), isFalse);
      expect(c.low(false), isTrue);
      expect(c.consume(false, 10), isTrue);
      expect(c.blackMs, 0);
      final g = ChessGame();
      g.flag(false);
      expect(g.result, ChessResult.whiteWins);
      expect(g.reason, EndReason.timeout);
    });

    test('flag vs lone king is a draw', () {
      final g = ChessGame('4k3/8/8/8/8/8/8/3QK3 b - - 0 1');
      g.flag(true); // white flags but... white has Q: black cannot mate -> draw
      expect(g.result, ChessResult.draw);
      expect(g.reason, EndReason.timeoutMaterial);
    });

    test('format', () {
      expect(ChessClock.format(180000), '3:00');
      expect(ChessClock.format(65000), '1:05');
      expect(ChessClock.format(9400), '0:09.4');
    });
  });
}
