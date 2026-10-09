import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/chess_engine.dart';

// Filled chess glyphs (king..pawn) forced to text presentation so Android
// does not swap the pawn for an emoji.
const _glyphs = {
  pKing: '♚︎',
  pQueen: '♛︎',
  pRook: '♜︎',
  pBishop: '♝︎',
  pKnight: '♞︎',
  pPawn: '♟︎',
};

/// A glossy chess piece: Unicode glyph with an outline, gradient fill and
/// soft drop shadow. [piece] uses the engine's signed encoding.
class PieceGlyph extends StatelessWidget {
  const PieceGlyph(this.piece, {super.key, required this.size});
  final int piece;
  final double size;

  @override
  Widget build(BuildContext context) {
    final white = piece > 0;
    final g = _glyphs[piece.abs()]!;
    final style = TextStyle(fontSize: size * 0.84, height: 1.0, fontFamilyFallback: const ['Noto Sans Symbols 2', 'Segoe UI Symbol', 'DejaVu Sans']);
    final rect = Rect.fromLTWH(0, 0, size, size);
    final fill = white
        ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFFFFF), Color(0xFFF3E7CF), Color(0xFFD9C29A)])
        : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5B5470), Color(0xFF2A2536), Color(0xFF0E0B14)]);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Text(g,
            textAlign: TextAlign.center,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = size * 0.075
                ..strokeJoin = StrokeJoin.round
                ..color = white ? const Color(0xFF3B2A1A) : const Color(0xFFE8DCC6),
              shadows: [Shadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: size * 0.08, offset: Offset(0, size * 0.05))],
            )),
        Text(g, textAlign: TextAlign.center, style: style.copyWith(foreground: Paint()..shader = fill.createShader(rect))),
      ]),
    );
  }
}

/// The wooden board with pieces, highlights and tap / drag input.
class ChessBoardView extends StatefulWidget {
  const ChessBoardView({
    super.key,
    required this.board,
    required this.flipped,
    required this.onTapSquare,
    required this.onDrop,
    required this.canDrag,
    this.selected,
    this.targets = const [],
    this.lastMove,
    this.animMove,
    this.animSeq = 0,
    this.checkSquare,
  });

  final List<int> board;
  final bool flipped;
  final int? selected;

  /// Legal destination squares of the selected piece.
  final List<int> targets;
  final int? lastMove;

  /// Move whose piece slides into place (null = no animation).
  final int? animMove;
  final int animSeq;
  final int? checkSquare;
  final void Function(int sq) onTapSquare;
  final void Function(int from, int to) onDrop;
  final bool Function(int sq) canDrag;

  @override
  State<ChessBoardView> createState() => _ChessBoardViewState();
}

class _ChessBoardViewState extends State<ChessBoardView> {
  int? _dragFrom;
  Offset? _dragPos;

  Offset _origin(int sq, double cell) {
    final col = widget.flipped ? 7 - sqFile(sq) : sqFile(sq);
    final row = widget.flipped ? sqRank(sq) : 7 - sqRank(sq);
    return Offset(col * cell, row * cell);
  }

  int? _squareAt(Offset p, double cell) {
    final col = (p.dx / cell).floor(), row = (p.dy / cell).floor();
    if (col < 0 || col > 7 || row < 0 || row > 7) return null;
    final file = widget.flipped ? 7 - col : col;
    final rank = widget.flipped ? row : 7 - row;
    return rank * 8 + file;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final side = math.min(box.maxWidth, box.maxHeight);
      const frame = 8.0;
      final inner = side - frame * 2;
      final cell = inner / 8;
      final pieces = <Widget>[];
      for (var sq = 0; sq < 64; sq++) {
        final p = widget.board[sq];
        if (p == 0 || sq == _dragFrom) continue;
        final o = _origin(sq, cell);
        Widget w = PieceGlyph(p, size: cell);
        final am = widget.animMove;
        if (am != null && moveTo(am) == sq) {
          final from = _origin(moveFrom(am), cell);
          w = TweenAnimationBuilder<Offset>(
            key: ValueKey('anim${widget.animSeq}'),
            tween: Tween(begin: from - o, end: Offset.zero),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => Transform.translate(offset: v, child: child),
            child: w,
          );
        }
        pieces.add(Positioned(left: o.dx, top: o.dy, width: cell, height: cell, child: IgnorePointer(child: w)));
      }
      return Center(
        child: Container(
          width: side,
          height: side,
          padding: const EdgeInsets.all(frame),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6B3E1F), Color(0xFF3E2210), Color(0xFF5A321A)],
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 24, offset: const Offset(0, 10))],
            border: Border.all(color: const Color(0xFFB98A55).withValues(alpha: 0.6)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: GestureDetector(
              key: const ValueKey('chessBoard'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final sq = _squareAt(d.localPosition, cell);
                if (sq != null) widget.onTapSquare(sq);
              },
              onPanStart: (d) {
                final sq = _squareAt(d.localPosition, cell);
                if (sq != null && widget.board[sq] != 0 && widget.canDrag(sq)) {
                  setState(() {
                    _dragFrom = sq;
                    _dragPos = d.localPosition;
                  });
                }
              },
              onPanUpdate: (d) {
                if (_dragFrom != null) setState(() => _dragPos = d.localPosition);
              },
              onPanEnd: (_) {
                final from = _dragFrom, pos = _dragPos;
                setState(() {
                  _dragFrom = null;
                  _dragPos = null;
                });
                if (from == null || pos == null) return;
                final to = _squareAt(pos, cell);
                if (to != null && to != from) widget.onDrop(from, to);
              },
              onPanCancel: () => setState(() {
                _dragFrom = null;
                _dragPos = null;
              }),
              child: SizedBox(
                width: inner,
                height: inner,
                child: Stack(children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BoardPainter(
                        flipped: widget.flipped,
                        selected: _dragFrom ?? widget.selected,
                        lastMove: widget.lastMove,
                        checkSquare: widget.checkSquare,
                      ),
                    ),
                  ),
                  ...pieces,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _TargetsPainter(flipped: widget.flipped, targets: widget.targets, board: widget.board),
                      ),
                    ),
                  ),
                  if (_dragFrom != null && _dragPos != null)
                    Positioned(
                      left: _dragPos!.dx - cell * 0.65,
                      top: _dragPos!.dy - cell * 1.1,
                      child: IgnorePointer(child: PieceGlyph(widget.board[_dragFrom!], size: cell * 1.3)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      );
    });
  }
}

Rect _cellRect(int sq, double cell, bool flipped) {
  final col = flipped ? 7 - sqFile(sq) : sqFile(sq);
  final row = flipped ? sqRank(sq) : 7 - sqRank(sq);
  return Rect.fromLTWH(col * cell, row * cell, cell, cell);
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({required this.flipped, this.selected, this.lastMove, this.checkSquare});
  final bool flipped;
  final int? selected;
  final int? lastMove;
  final int? checkSquare;

  static const _light = [Color(0xFFF4DDB2), Color(0xFFE6C690)];
  static const _dark = [Color(0xFFB07A4A), Color(0xFF8E5B32)];

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 8;
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var sq = 0; sq < 64; sq++) {
      final r = _cellRect(sq, cell, flipped);
      final light = (sqFile(sq) + sqRank(sq)) & 1 == 1;
      final cols = light ? _light : _dark;
      canvas.drawRect(r, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: cols).createShader(r));
      // Subtle wood grain: a few wavy lines seeded by the square.
      grain.color = (light ? const Color(0xFFC9A26B) : const Color(0xFF6E4424)).withValues(alpha: 0.28);
      final rnd = math.Random(sq * 31 + 7);
      for (var i = 0; i < 3; i++) {
        final y0 = r.top + r.height * (0.15 + 0.3 * i + rnd.nextDouble() * 0.1);
        final amp = r.height * 0.04 * (1 + rnd.nextDouble());
        final path = Path()..moveTo(r.left, y0);
        for (var x = 0.0; x <= cell; x += cell / 6) {
          path.lineTo(r.left + x, y0 + math.sin((x / cell) * math.pi * 2 + i + sq) * amp);
        }
        canvas.drawPath(path, grain);
      }
    }
    // Last move.
    final lm = lastMove;
    if (lm != null) {
      final p = Paint()..color = const Color(0x77F7D154);
      canvas.drawRect(_cellRect(moveFrom(lm), cell, flipped), p);
      canvas.drawRect(_cellRect(moveTo(lm), cell, flipped), p);
    }
    if (selected != null) {
      canvas.drawRect(_cellRect(selected!, cell, flipped), Paint()..color = const Color(0x9960C878));
    }
    if (checkSquare != null) {
      final r = _cellRect(checkSquare!, cell, flipped);
      canvas.drawRect(
        r,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0xEEFF2D2D), Color(0x99D61F1F), Color(0x00D61F1F)], stops: [0, 0.55, 1])
              .createShader(r),
      );
    }
    // Coordinates.
    for (var i = 0; i < 8; i++) {
      final file = flipped ? 7 - i : i;
      final rank = flipped ? i : 7 - i;
      final bottomRank = flipped ? 7 : 0, leftFile = flipped ? 7 : 0;
      _label(canvas, 'abcdefgh'[file], Offset((i + 1) * cell - cell * 0.2, size.height - cell * 0.27), cell, (file + bottomRank) & 1 == 0);
      _label(canvas, '${rank + 1}', Offset(cell * 0.06, i * cell + cell * 0.03), cell, (leftFile + rank) & 1 == 0);
    }
  }

  void _label(Canvas c, String s, Offset at, double cell, bool onDark) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: onDark ? const Color(0xFFF4DDB2) : const Color(0xFF8E5B32), fontSize: cell * 0.2, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at);
  }

  @override
  bool shouldRepaint(_BoardPainter o) => o.flipped != flipped || o.selected != selected || o.lastMove != lastMove || o.checkSquare != checkSquare;
}

class _TargetsPainter extends CustomPainter {
  _TargetsPainter({required this.flipped, required this.targets, required this.board});
  final bool flipped;
  final List<int> targets;
  final List<int> board;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 8;
    final dot = Paint()..color = const Color(0x55201A10);
    final ring = Paint()
      ..color = const Color(0x66201A10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.09;
    for (final t in targets) {
      final r = _cellRect(t, cell, flipped);
      if (board[t] != 0) {
        canvas.drawCircle(r.center, cell * 0.43, ring);
      } else {
        canvas.drawCircle(r.center, cell * 0.16, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_TargetsPainter o) => o.flipped != flipped || o.targets != targets || o.board != board;
}
