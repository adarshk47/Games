import 'dart:math' as math;

import 'package:flutter/material.dart';

/// New Master G app-icon concepts (square, readable at small sizes, no
/// small text). [variant]: 0 = gold G with a puzzle tab, 1 = brain of
/// coloured tiles, 2 = festive G with a diya flame.
class AppIconDesign extends CustomPainter {
  const AppIconDesign(this.variant, {this.background = true, this.font = 'MGRoboto'});
  final int variant;
  final bool background;
  final String font;

  static const _gold = [Color(0xFFFFF1B8), Color(0xFFFFD369), Color(0xFFF5A623), Color(0xFFC77A0A)];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    if (background) _bg(canvas, size);
    switch (variant) {
      case 0:
        _goldG(canvas, s, center: Offset(s * 0.5, s * 0.52), height: s * 0.72);
        _puzzleTab(canvas, s);
        _sparkle(canvas, Offset(s * 0.78, s * 0.22), s * 0.06, const Color(0xFFFFF1B8));
        _sparkle(canvas, Offset(s * 0.2, s * 0.78), s * 0.035, const Color(0xFFFFD369));
      case 1:
        _brain(canvas, s);
      default:
        _goldG(canvas, s, center: Offset(s * 0.5, s * 0.56), height: s * 0.66);
        _diya(canvas, s);
    }
  }

  void _bg(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final colors = switch (variant) {
      0 => [const Color(0xFF7B3FE4), const Color(0xFF3A1580), const Color(0xFF1B0B45)],
      1 => [const Color(0xFF3A2C8F), const Color(0xFF1E1557), const Color(0xFF0E0A30)],
      _ => [const Color(0xFFB0331F), const Color(0xFF5E0F12), const Color(0xFF2A0508)],
    };
    canvas.drawRect(
      r,
      Paint()
        ..shader = RadialGradient(center: const Alignment(-0.3, -0.4), radius: 1.1, colors: colors, stops: const [0, 0.55, 1])
            .createShader(r),
    );
    // Soft light ring.
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width * 0.42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012
        ..color = Colors.white.withValues(alpha: 0.07),
    );
  }

  void _goldG(Canvas canvas, double s, {required Offset center, required double height}) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'G',
        style: TextStyle(fontFamily: font, fontSize: height, fontWeight: FontWeight.w900, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final o = center - Offset(tp.width / 2, tp.height / 2);
    final rect = o & tp.size;
    // Shadow / depth.
    final depth = TextPainter(
      text: TextSpan(
        text: 'G',
        style: TextStyle(
          fontFamily: font,
          fontSize: height,
          fontWeight: FontWeight.w900,
          height: 1,
          color: const Color(0xFF6B3A00),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    depth.paint(canvas, o + Offset(0, s * 0.025));
    canvas.saveLayer(rect.inflate(4), Paint());
    tp.paint(canvas, o);
    canvas.drawRect(
      rect.inflate(4),
      Paint()
        ..blendMode = BlendMode.srcIn
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _gold, stops: [0, 0.35, 0.7, 1])
            .createShader(rect),
    );
    canvas.restore();
  }

  void _puzzleTab(Canvas canvas, double s) {
    // A puzzle-piece knob sitting on the G's bar.
    final c = Offset(s * 0.66, s * 0.53);
    final r = s * 0.075;
    final p = Paint()
      ..shader = const RadialGradient(colors: [Color(0xFF7CF0D0), Color(0xFF16B98C)]).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, p);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.28;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _brain(Canvas canvas, double s) {
    // Brain silhouette made of rounded tiles (two lobes).
    const colors = [Color(0xFFFF6FB5), Color(0xFFFFC93C), Color(0xFF4DA8FF), Color(0xFF2EE6A8), Color(0xFFB794FF), Color(0xFFFF8F1F)];
    final cell = s * 0.105;
    final gap = s * 0.014;
    // Rows of (startCol, count) forming a brain from the side.
    const rows = [(2, 4), (1, 6), (0, 8), (0, 8), (0, 8), (1, 6), (2, 3)];
    final width = 8 * (cell + gap) - gap;
    final ox = (s - width) / 2;
    final oy = s * 0.13;
    var k = 0;
    for (var r = 0; r < rows.length; r++) {
      final (start, count) = rows[r];
      for (var c = start; c < start + count; c++) {
        // Split between the two lobes.
        if (c == 4 && r > 0 && r < rows.length - 1) continue;
        final rect = Rect.fromLTWH(ox + c * (cell + gap), oy + r * (cell + gap), cell, cell);
        final col = colors[(k++ * 5 + r) % colors.length];
        final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.28));
        canvas.drawRRect(
          rr,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(col, Colors.white, 0.3)!, col, Color.lerp(col, Colors.black, 0.25)!],
            ).createShader(rect),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(rect.left + cell * 0.18, rect.top + cell * 0.12, cell * 0.5, cell * 0.16), Radius.circular(cell * 0.1)),
          Paint()..color = Colors.white.withValues(alpha: 0.45),
        );
      }
    }
    _goldG(canvas, s, center: Offset(s * 0.5, s * 0.86), height: s * 0.2);
  }

  void _diya(Canvas canvas, double s) {
    final c = Offset(s * 0.5, s * 0.14);
    canvas.drawCircle(
      c,
      s * 0.13,
      Paint()
        ..shader = RadialGradient(colors: [const Color(0xFFFFE08A).withValues(alpha: 0.75), const Color(0x00FFB347)])
            .createShader(Rect.fromCircle(center: c, radius: s * 0.13)),
    );
    final flame = Path()
      ..moveTo(c.dx, c.dy - s * 0.075)
      ..quadraticBezierTo(c.dx + s * 0.05, c.dy + s * 0.01, c.dx, c.dy + s * 0.05)
      ..quadraticBezierTo(c.dx - s * 0.05, c.dy + s * 0.01, c.dx, c.dy - s * 0.075)
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF6C8), Color(0xFFFFB347), Color(0xFFE8590C)])
            .createShader(Rect.fromCenter(center: c, width: s * 0.1, height: s * 0.13)),
    );
    // Marigold dots around the bottom.
    for (var i = 0; i < 9; i++) {
      final a = math.pi * (0.15 + 0.7 * i / 8);
      final p = Offset(s * 0.5 + math.cos(a) * s * 0.44, s * 0.52 + math.sin(a) * s * 0.44);
      canvas.drawCircle(p, s * 0.025, Paint()..color = i.isEven ? const Color(0xFFFF9F1C) : const Color(0xFFFFC93C));
    }
  }

  @override
  bool shouldRepaint(AppIconDesign o) => o.variant != variant || o.background != background;
}
