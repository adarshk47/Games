import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ludo/ludo_board.dart';
import 'logic/snakes_logic.dart';

const _tileColors = [Color(0xFFFFF3C4), Color(0xFFFFD6A5), Color(0xFFCDEAC0), Color(0xFFBDE0FE), Color(0xFFFFC8DD)];
const _snakeColors = [Color(0xFF2E7D32), Color(0xFF6A1B9A), Color(0xFFD84315), Color(0xFF00838F), Color(0xFFC62828)];

/// 10×10 Saanp-Seedhi board with ladders, snakes and the players' tokens.
class SnakesBoard extends StatelessWidget {
  const SnakesBoard({super.key, required this.game});
  final SnakesGame game;

  static Offset _centre(int n, double cell) {
    final (r, c) = Snakes.cellOf(n);
    return Offset((c + 0.5) * cell, (r + 0.5) * cell);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, box) {
        final cell = box.maxWidth / 10;
        final children = <Widget>[
          Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _SnakesPainter()))),
        ];
        // Tokens: spread a little when sharing a square.
        final bySquare = <int, List<int>>{};
        for (var s = 0; s < game.seats.length; s++) {
          if (game.pos[s] > 0) bySquare.putIfAbsent(game.pos[s], () => []).add(s);
        }
        for (var s = 0; s < game.seats.length; s++) {
          final p = game.pos[s];
          final size = cell * (p > 0 && bySquare[p]!.length > 1 ? 0.5 : 0.62);
          Offset o;
          if (p == 0) {
            // Waiting below the board's first square.
            o = Offset(cell * (0.3 + s * 0.42), box.maxWidth - cell * 0.18);
          } else {
            o = _centre(p, cell);
            final group = bySquare[p]!;
            if (group.length > 1) {
              final a = 2 * math.pi * group.indexOf(s) / group.length;
              o += Offset(math.cos(a), math.sin(a)) * cell * 0.2;
            }
          }
          children.add(AnimatedPositioned(
            key: ValueKey('snake_token_$s'),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
            left: o.dx - size / 2,
            top: o.dy - size / 2,
            width: size,
            height: size,
            child: LudoToken(color: ludoColors[game.seats[s].colour], glow: s == game.turn && !game.over),
          ));
        }
        return Stack(clipBehavior: Clip.none, children: children);
      }),
    );
  }
}

class _SnakesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 10;
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * 0.4));
    canvas.save();
    canvas.clipRRect(rr);
    for (var n = 1; n <= 100; n++) {
      final (r, c) = Snakes.cellOf(n);
      final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
      canvas.drawRect(rect, Paint()..color = _tileColors[(r + c) % _tileColors.length]);
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = const Color(0x33000000),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: n == 100 ? '🏆' : '$n',
          style: TextStyle(color: const Color(0xAA4E342E), fontSize: cell * 0.26, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.topLeft + Offset(cell * 0.08, cell * 0.04));
    }
    Offset ctr(int n) {
      final (r, c) = Snakes.cellOf(n);
      return Offset((c + 0.5) * cell, (r + 0.5) * cell);
    }

    // Ladders.
    for (final e in Snakes.ladders.entries) {
      _ladder(canvas, ctr(e.key), ctr(e.value), cell);
    }
    // Snakes.
    var k = 0;
    for (final e in Snakes.snakes.entries) {
      _snake(canvas, ctr(e.key), ctr(e.value), cell, _snakeColors[k++ % _snakeColors.length]);
    }
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.12
        ..color = const Color(0xFF7A5230),
    );
  }

  void _ladder(Canvas canvas, Offset a, Offset b, double cell) {
    final d = b - a;
    final len = d.distance;
    final n = Offset(-d.dy, d.dx) / len * cell * 0.18;
    final rail = Paint()
      ..color = const Color(0xFF8D5524)
      ..strokeWidth = cell * 0.09
      ..strokeCap = StrokeCap.round;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..strokeWidth = cell * 0.11
      ..strokeCap = StrokeCap.round;
    for (final side in [n, -n]) {
      canvas.drawLine(a + side + const Offset(2, 2), b + side + const Offset(2, 2), shadow);
    }
    final rungs = (len / (cell * 0.45)).floor();
    for (var i = 1; i < rungs; i++) {
      final p = a + d * (i / rungs);
      canvas.drawLine(p + n, p - n, rail..strokeWidth = cell * 0.07);
    }
    rail.strokeWidth = cell * 0.09;
    for (final side in [n, -n]) {
      canvas.drawLine(a + side, b + side, rail);
    }
  }

  void _snake(Canvas canvas, Offset head, Offset tail, double cell, Color color) {
    final d = tail - head;
    final len = d.distance;
    final nrm = Offset(-d.dy, d.dx) / len;
    final path = Path()..moveTo(head.dx, head.dy);
    const waves = 3;
    for (var i = 0; i < waves; i++) {
      final p1 = head + d * ((i + 0.5) / waves) + nrm * cell * (i.isEven ? 0.6 : -0.6);
      final p2 = head + d * ((i + 1) / waves);
      path.quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = cell * 0.3
        ..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = cell * 0.26
        ..shader = LinearGradient(colors: [Color.lerp(color, Colors.white, 0.25)!, color, Color.lerp(color, Colors.black, 0.2)!])
            .createShader(Rect.fromPoints(head, tail)),
    );
    // Belly stripe dots.
    final metrics = path.computeMetrics().first;
    for (var t = 0.12; t < 0.95; t += 0.08) {
      final pos = metrics.getTangentForOffset(metrics.length * t)!.position;
      canvas.drawCircle(pos, cell * 0.05, Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: 0.9));
    }
    // Head with eyes and tongue.
    canvas.drawCircle(head, cell * 0.22, Paint()..color = color);
    final dir = (path.computeMetrics().first.getTangentForOffset(1)!.vector);
    final back = Offset(-dir.dx, -dir.dy);
    final side = Offset(-back.dy, back.dx);
    for (final s in [-1.0, 1.0]) {
      final e = head + back * cell * 0.06 + side * s * cell * 0.09;
      canvas.drawCircle(e, cell * 0.06, Paint()..color = Colors.white);
      canvas.drawCircle(e + back * cell * 0.015, cell * 0.03, Paint()..color = Colors.black);
    }
    final tongue = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = cell * 0.035
      ..strokeCap = StrokeCap.round;
    final t0 = head + back * cell * 0.22;
    canvas.drawLine(t0, t0 + back * cell * 0.12, tongue);
  }

  @override
  bool shouldRepaint(_SnakesPainter old) => false;
}
