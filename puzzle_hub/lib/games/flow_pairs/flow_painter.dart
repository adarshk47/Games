import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'logic/flow_logic.dart';

/// Neon pipe colors (one per pair; up to 13 pairs).
const flowColors = <Color>[
  Color(0xFFFF4D6D), Color(0xFF38BDF8), Color(0xFFFFD369), Color(0xFF4ADE80),
  Color(0xFFB794FF), Color(0xFFFF9F43), Color(0xFF5EEAD4), Color(0xFFFF6FB5),
  Color(0xFFA3E635), Color(0xFF818CF8), Color(0xFFF472B6), Color(0xFF22D3EE),
  Color(0xFFFFFFFF),
];

Color flowColor(int pair) => flowColors[pair % flowColors.length];

class FlowPainter extends CustomPainter {
  FlowPainter({
    required this.board,
    required this.pulse,
    required this.shimmer,
    required this.solved,
    required this.version,
    super.repaint,
  });

  final FlowBoard board;
  final double pulse; // 0..1 repeating
  final double shimmer; // 0..1 sweep (only used when solved)
  final bool solved;
  final int version;

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    final cell = size.width / n;
    Offset center(int i) => Offset((i % n + 0.5) * cell, (i ~/ n + 0.5) * cell);

    // Tiles.
    final tile = Paint()..color = const Color(0x14FFFFFF);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x22FFFFFF);
    for (var i = 0; i < n * n; i++) {
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH((i % n) * cell + 1.5, (i ~/ n) * cell + 1.5, cell - 3, cell - 3), Radius.circular(cell * 0.18));
      canvas.drawRRect(r, tile);
      final o = board.owner[i];
      if (o >= 0) {
        canvas.drawRRect(r, Paint()..color = flowColor(o).withValues(alpha: 0.13));
      }
      canvas.drawRRect(r, border);
    }

    // Pipes.
    for (var p = 0; p < board.paths.length; p++) {
      final cells = board.paths[p];
      if (cells.length < 2) continue;
      final color = flowColor(p);
      final path = Path()..moveTo(center(cells.first).dx, center(cells.first).dy);
      for (var k = 1; k < cells.length; k++) {
        final c = center(cells[k]);
        path.lineTo(c.dx, c.dy);
      }
      Paint stroke(double w, Color c, {double blur = 0}) => Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = w
        ..color = c
        ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;
      canvas.drawPath(path, stroke(cell * 0.55, color.withValues(alpha: 0.45), blur: cell * 0.2));
      canvas.drawPath(path, stroke(cell * 0.34, color));
      canvas.drawPath(path, stroke(cell * 0.1, Color.lerp(color, Colors.white, 0.7)!.withValues(alpha: 0.7)));
    }

    // Endpoints.
    final wave = 0.5 + 0.5 * math.sin(pulse * math.pi * 2);
    for (var p = 0; p < board.puzzle.pairs.length; p++) {
      final color = flowColor(p);
      final connected = board.isConnected(p);
      for (final e in [board.puzzle.pairs[p].a, board.puzzle.pairs[p].b]) {
        final c = center(e);
        canvas.drawCircle(c, cell * 0.36, Paint()
          ..color = color.withValues(alpha: connected ? 0.5 : 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.14));
        canvas.drawCircle(c, cell * 0.3, Paint()..color = color);
        canvas.drawCircle(c, cell * 0.3, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.04
          ..color = Colors.white.withValues(alpha: 0.6));
        canvas.drawCircle(c - Offset(cell * 0.08, cell * 0.08), cell * 0.07, Paint()..color = Colors.white.withValues(alpha: 0.7));
        if (!connected && !solved) {
          canvas.drawCircle(
              c,
              cell * (0.34 + 0.12 * wave),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = cell * 0.05
                ..color = color.withValues(alpha: 0.55 * (1 - wave)));
        }
      }
    }

    // Active head.
    final a = board.active;
    if (a != null && board.paths[a].isNotEmpty) {
      final h = center(board.paths[a].last);
      canvas.drawCircle(h, cell * 0.24 + cell * 0.04 * wave, Paint()..color = Colors.white.withValues(alpha: 0.35));
    }

    // Completion shimmer.
    if (solved) {
      final s = shimmer * 1.6 - 0.3;
      for (var i = 0; i < n * n; i++) {
        if (board.owner[i] < 0) continue;
        final d = ((i % n + i ~/ n) / (2 * n - 2) - s).abs();
        final a2 = (1 - d * 5).clamp(0.0, 1.0);
        if (a2 <= 0) continue;
        canvas.drawCircle(center(i), cell * 0.3, Paint()
          ..color = Colors.white.withValues(alpha: a2 * 0.75)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.1));
      }
    }
  }

  @override
  bool shouldRepaint(FlowPainter old) => true;
}
