import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/chess_engine.dart';

/// A chess piece drawn with vector shapes (not a font glyph, so it looks the
/// same on every phone): white pieces are creamy white with a light red
/// outline, black pieces are pure black with a thin grey rim. [piece] uses the
/// engine's signed encoding.
class PieceGlyph extends StatelessWidget {
  const PieceGlyph(this.piece, {super.key, required this.size});
  final int piece;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _PiecePainter(piece)),
      );
}

class _PiecePainter extends CustomPainter {
  _PiecePainter(this.piece);
  final int piece;

  @override
  void paint(Canvas canvas, Size size) {
    final white = piece > 0;
    final k = size.width / 100;
    canvas.save();
    canvas.scale(k);
    final body = _shape(piece.abs());
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        // White side: creamy white; black side: pure black.
        colors: white
            ? const [Color(0xFFFFFBF0), Color(0xFFFFF3D9), Color(0xFFF5E3BD)]
            : const [Color(0xFF000000), Color(0xFF000000), Color(0xFF000000)],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = white ? 4.5 : 3
      ..strokeJoin = StrokeJoin.round
      // Light red outline and details on the creamy pieces; a thin grey rim
      // keeps the black pieces visible on dark squares.
      ..color = white ? const Color(0xFFE57373) : const Color(0xFF5A5A5A);
    // Soft shadow under the piece.
    canvas.drawPath(
      body.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(body, fill);
    canvas.drawPath(body, rim);
    // Detail lines (collars, eye) in the outline colour.
    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = rim.color;
    for (final l in _details(piece.abs())) {
      canvas.drawLine(l.$1, l.$2, detail);
    }
    if (piece.abs() == pKnight) canvas.drawCircle(const Offset(52, 30), 3.2, Paint()..color = rim.color);
    canvas.restore();
  }

  /// Every piece stands on the same base.
  static Path _base() => Path()
    ..addRRect(RRect.fromLTRBR(20, 80, 80, 92, const Radius.circular(5)))
    ..addRRect(RRect.fromLTRBR(28, 72, 72, 81, const Radius.circular(3)));

  static Path _shape(int t) {
    final p = _base();
    switch (t) {
      case pPawn:
        p.addPath(
          Path()
            ..moveTo(34, 73)
            ..quadraticBezierTo(38, 56, 44, 46)
            ..lineTo(56, 46)
            ..quadraticBezierTo(62, 56, 66, 73)
            ..close(),
          Offset.zero,
        );
        p.addOval(Rect.fromCenter(center: const Offset(50, 45), width: 30, height: 9));
        p.addOval(Rect.fromCircle(center: const Offset(50, 30), radius: 13));
      case pRook:
        p.addPath(
          Path()
            ..moveTo(32, 73)
            ..lineTo(35, 40)
            ..lineTo(65, 40)
            ..lineTo(68, 73)
            ..close(),
          Offset.zero,
        );
        p.addPath(
          Path()
            ..moveTo(26, 40)
            ..lineTo(26, 16)
            ..lineTo(36, 16)
            ..lineTo(36, 24)
            ..lineTo(45, 24)
            ..lineTo(45, 16)
            ..lineTo(55, 16)
            ..lineTo(55, 24)
            ..lineTo(64, 24)
            ..lineTo(64, 16)
            ..lineTo(74, 16)
            ..lineTo(74, 40)
            ..close(),
          Offset.zero,
        );
      case pKnight:
        p.addPath(
          Path()
            ..moveTo(30, 73)
            ..cubicTo(30, 60, 40, 54, 42, 48)
            ..cubicTo(34, 50, 24, 52, 22, 44)
            ..cubicTo(20, 36, 30, 28, 38, 22)
            ..lineTo(40, 12)
            ..lineTo(48, 18)
            ..cubicTo(62, 16, 74, 28, 76, 46)
            ..cubicTo(78, 60, 72, 66, 72, 73)
            ..close(),
          Offset.zero,
        );
      case pBishop:
        p.addPath(
          Path()
            ..moveTo(34, 73)
            ..quadraticBezierTo(40, 58, 44, 50)
            ..lineTo(56, 50)
            ..quadraticBezierTo(60, 58, 66, 73)
            ..close(),
          Offset.zero,
        );
        p.addOval(Rect.fromCenter(center: const Offset(50, 49), width: 30, height: 8));
        p.addPath(
          Path()
            ..moveTo(50, 14)
            ..cubicTo(64, 24, 66, 36, 60, 46)
            ..lineTo(40, 46)
            ..cubicTo(34, 36, 36, 24, 50, 14)
            ..close(),
          Offset.zero,
        );
        p.addOval(Rect.fromCircle(center: const Offset(50, 11), radius: 5));
      case pQueen:
        p.addPath(
          Path()
            ..moveTo(32, 73)
            ..quadraticBezierTo(40, 56, 40, 42)
            ..lineTo(60, 42)
            ..quadraticBezierTo(60, 56, 68, 73)
            ..close(),
          Offset.zero,
        );
        p.addPath(
          Path()
            ..moveTo(28, 44)
            ..lineTo(22, 20)
            ..lineTo(36, 32)
            ..lineTo(42, 14)
            ..lineTo(50, 30)
            ..lineTo(58, 14)
            ..lineTo(64, 32)
            ..lineTo(78, 20)
            ..lineTo(72, 44)
            ..close(),
          Offset.zero,
        );
        for (final x in [22.0, 42.0, 58.0, 78.0]) {
          p.addOval(Rect.fromCircle(center: Offset(x, x == 22 || x == 78 ? 18 : 12), radius: 4.5));
        }
      default: // King
        p.addPath(
          Path()
            ..moveTo(32, 73)
            ..quadraticBezierTo(40, 56, 40, 42)
            ..lineTo(60, 42)
            ..quadraticBezierTo(60, 56, 68, 73)
            ..close(),
          Offset.zero,
        );
        p.addPath(
          Path()
            ..moveTo(28, 44)
            ..cubicTo(22, 30, 34, 22, 44, 30)
            ..lineTo(50, 24)
            ..lineTo(56, 30)
            ..cubicTo(66, 22, 78, 30, 72, 44)
            ..close(),
          Offset.zero,
        );
        p.addRect(const Rect.fromLTRB(46, 4, 54, 24));
        p.addRect(const Rect.fromLTRB(40, 10, 60, 17));
    }
    p.fillType = PathFillType.nonZero;
    return p;
  }

  static List<(Offset, Offset)> _details(int t) => switch (t) {
        pRook => const [(Offset(33, 46), Offset(67, 46))],
        pBishop => const [(Offset(46, 26), Offset(54, 36))],
        pQueen || pKing => const [(Offset(33, 50), Offset(67, 50))],
        pKnight => const [(Offset(42, 48), Offset(48, 40))],
        _ => const [],
      };

  @override
  bool shouldRepaint(_PiecePainter o) => o.piece != piece;
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
