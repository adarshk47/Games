import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'festive_palette.dart';

// Motif painters for the festive home layout: toran garland, saree-border
// game cards (temple border, paisley pallu, zari edges, rangoli corners),
// mandala rings, the pooja thali and small preview thumbnails. All are static
// (no animation) so they are painted once and cached behind RepaintBoundaries.

/// Keri / buta (paisley) outline fitted into [r]; the curled tip points to the
/// top-right, or top-left when [mirror] is set.
Path paisleyPath(Rect r, {bool mirror = false}) {
  double x(double f) => mirror ? r.right - f * r.width : r.left + f * r.width;
  double y(double f) => r.top + f * r.height;
  return Path()
    ..moveTo(x(0.5), y(1.0))
    ..cubicTo(x(0.04), y(1.0), x(-0.02), y(0.5), x(0.32), y(0.36))
    ..cubicTo(x(0.56), y(0.25), x(0.62), y(0.08), x(0.92), y(0.0))
    ..cubicTo(x(0.78), y(0.14), x(1.02), y(0.32), x(0.97), y(0.62))
    ..cubicTo(x(0.93), y(0.9), x(0.76), y(1.0), x(0.5), y(1.0))
    ..close();
}

void _marigold(Canvas c, Offset p, double r, Color color) {
  final f = Paint()..color = Color.lerp(color, Colors.black, 0.25)!;
  c.drawCircle(p, r, f);
  f.color = color;
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    c.drawCircle(p + Offset(math.cos(a), math.sin(a)) * (r * 0.45), r * 0.55, f);
  }
  f.color = Color.lerp(color, Festive.haldi, 0.6)!;
  c.drawCircle(p, r * 0.32, f);
}

Path _leafPath(Offset top, double len, double w) => Path()
  ..moveTo(top.dx, top.dy)
  ..cubicTo(top.dx + w, top.dy + len * 0.28, top.dx + w * 0.55, top.dy + len * 0.82, top.dx, top.dy + len)
  ..cubicTo(top.dx - w * 0.55, top.dy + len * 0.82, top.dx - w, top.dy + len * 0.28, top.dx, top.dy)
  ..close();

/// Toran: a marigold (genda) garland strung across the top with hanging mango
/// leaves and small marigold strands (lari).
class ToranPainter extends CustomPainter {
  const ToranPainter();

  @override
  void paint(Canvas canvas, Size s) {
    if (s.width <= 0) return;
    final sag = math.min(8.0, s.height * 0.18);
    double sy(double x) => 6 + sag * math.sin(math.pi * x / s.width);

    final n = math.max(4, (s.width / 26).round());
    final step = s.width / n;
    final leafLen = math.max(12.0, s.height - 16);
    final leafPaint = Paint();
    final rib = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFA5D6A7).withValues(alpha: 0.8);
    final thread = Paint()
      ..strokeWidth = 1
      ..color = Festive.haldi.withValues(alpha: 0.8);

    // Hanging pieces first so the garland sits on top of their stems.
    for (var i = 0; i < n; i++) {
      final x = (i + 0.5) * step;
      final top = Offset(x, sy(x) + 2);
      if (i.isEven) {
        final len = leafLen * (i % 4 == 0 ? 1.0 : 0.86);
        final w = math.min(9.0, step * 0.42);
        leafPaint.shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Festive.leaf, Festive.leafDark],
        ).createShader(Rect.fromLTWH(x - w, top.dy, w * 2, len));
        canvas.drawPath(_leafPath(top, len, w), leafPaint);
        canvas.drawLine(top, top.translate(0, len * 0.9), rib);
      } else {
        final len = leafLen * 0.7;
        canvas.drawLine(top, top.translate(0, len), thread);
        _marigold(canvas, top.translate(0, len * 0.45), 3.8, Festive.marigoldDeep);
        _marigold(canvas, top.translate(0, len * 0.85), 3.4, Festive.haldi);
      }
    }

    // Garland: overlapping marigolds along the sagging thread.
    const colors = [Festive.marigold, Festive.marigoldDeep, Festive.haldi];
    var k = 0;
    for (double x = 3; x <= s.width - 3; x += 7.5) {
      _marigold(canvas, Offset(x, sy(x)), 4.6, colors[k++ % 3]);
    }
    // Longer lari at both ends.
    for (final x in [5.0, s.width - 5]) {
      final y0 = sy(x);
      canvas.drawLine(Offset(x, y0), Offset(x, s.height - 4), thread);
      for (var j = 1; j <= 3; j++) {
        _marigold(canvas, Offset(x, y0 + (s.height - y0 - 4) * j / 3.2), 4, colors[(j + 1) % 3]);
      }
    }
  }

  @override
  bool shouldRepaint(ToranPainter oldDelegate) => false;
}

/// Quarter rangoli ornament around [c], filling the quadrant [start]..[start+90°].
void paintRangoliCorner(Canvas canvas, Offset c, double r, double start, double alpha) {
  final f = Paint()..isAntiAlias = true;
  for (var i = 0; i < 5; i++) {
    final a = start + (i + 0.5) * (math.pi / 2) / 5;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(a + math.pi / 2);
    f.color = Festive.rangoli[i % Festive.rangoli.length].withValues(alpha: alpha);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -r * 0.62), width: r * 0.24, height: r * 0.5), f);
    canvas.restore();
  }
  f
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = Festive.zariLight.withValues(alpha: alpha * 0.9);
  canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.3), start, math.pi / 2, false, f);
  canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, math.pi / 2, false, f);
  f.style = PaintingStyle.fill;
  for (var i = 0; i <= 6; i++) {
    final a = start + i * (math.pi / 2) / 6;
    f.color = (i.isEven ? Festive.haldi : Festive.kumkum).withValues(alpha: alpha);
    canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * (r * 1.12), 1.6, f);
  }
}

/// A row of paisleys with dots on a coloured band (saree border / pallu).
void paintPaisleyBand(Canvas canvas, Rect band, Color base) {
  canvas.drawRect(
    band,
    Paint()
      ..shader = LinearGradient(
        colors: [Color.lerp(base, Colors.black, 0.35)!, Festive.sindoor, Color.lerp(base, Colors.black, 0.35)!],
      ).createShader(band),
  );
  final zari = Paint()..color = Festive.zari;
  canvas.drawRect(Rect.fromLTWH(band.left, band.top, band.width, 1.6), zari);
  canvas.drawRect(Rect.fromLTWH(band.left, band.top + 3.2, band.width, 0.7), zari..color = Festive.zariLight.withValues(alpha: 0.7));
  final h = band.height - 7;
  if (h < 6) return;
  final w = h * 0.72;
  final n = math.max(1, (band.width / (w * 2.1)).floor());
  final step = band.width / n;
  final fill = Paint()..color = Festive.zariLight.withValues(alpha: 0.92);
  final dot = Paint()..color = Festive.kumkum;
  for (var i = 0; i < n; i++) {
    final cx = band.left + (i + 0.5) * step;
    final r = Rect.fromCenter(center: Offset(cx, band.top + 4 + h / 2 + 1), width: w, height: h);
    canvas.drawPath(paisleyPath(r, mirror: i.isOdd), fill);
    canvas.drawCircle(r.center.translate(0, h * 0.18), h * 0.14, dot);
    // Small bindi between motifs.
    canvas.drawCircle(Offset(band.left + i * step, band.top + 4 + h / 2 + 1), 1.4, fill);
  }
}

/// Kanjeevaram "temple" border: a row of small gold triangles.
void paintTempleBorder(Canvas canvas, Rect r) {
  canvas.drawRect(r, Paint()..color = Festive.sindoor.withValues(alpha: 0.85));
  final p = Paint()..color = Festive.zari;
  final w = r.height * 1.1;
  final n = math.max(1, (r.width / w).floor());
  final step = r.width / n;
  final path = Path();
  for (var i = 0; i < n; i++) {
    final x = r.left + i * step;
    path
      ..moveTo(x + step * 0.15, r.bottom)
      ..lineTo(x + step * 0.5, r.top + 1)
      ..lineTo(x + step * 0.85, r.bottom)
      ..close();
  }
  canvas.drawPath(path, p);
  canvas.drawRect(Rect.fromLTWH(r.left, r.bottom, r.width, 1), p);
}

/// Game card background styled like a silk saree: deep body, temple border on
/// top, paisley pallu band at the bottom, rangoli corners and a zari edge.
class SareeCardPainter extends CustomPainter {
  const SareeCardPainter({required this.color, required this.base, this.radius = 22, this.band = 22});
  final Color color;
  final Color base;
  final double radius;
  final double band;

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Festive.sindoor, 0.45)!.withValues(alpha: 0.85),
            Color.lerp(base, Colors.black, 0.2)!.withValues(alpha: 0.94),
          ],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRRect(rr);
    paintTempleBorder(canvas, Rect.fromLTWH(0, 0, s.width, 7));
    paintRangoliCorner(canvas, const Offset(0, 8), 30, 0, 0.55);
    paintRangoliCorner(canvas, Offset(s.width, 8), 30, math.pi / 2, 0.35);
    paintPaisleyBand(canvas, Rect.fromLTWH(0, s.height - band, s.width, band), color);
    canvas.restore();
    canvas.drawRRect(
      rr.deflate(0.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = Festive.zariGradient.createShader(rect),
    );
    canvas.drawRRect(
      rr.deflate(3.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = Festive.zariLight.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(SareeCardPainter o) =>
      o.color != color || o.base != base || o.radius != radius || o.band != band;
}

/// Mandala ring of petals and dots drawn around a central circle.
class MandalaRingPainter extends CustomPainter {
  const MandalaRingPainter({required this.color, this.petals = 16});
  final Color color;
  final int petals;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.shortestSide / 2;
    final ri = r * 0.68, ro = r * 0.99;
    final w = r * 0.16;
    final petal = Path()
      ..moveTo(0, -ri)
      ..quadraticBezierTo(w, -(ri + ro) / 2, 0, -ro)
      ..quadraticBezierTo(-w, -(ri + ro) / 2, 0, -ri)
      ..close();
    final fill = Paint()..isAntiAlias = true;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Festive.zariLight.withValues(alpha: 0.9);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    for (var i = 0; i < petals; i++) {
      fill.color = (i.isEven ? Festive.marigold : Color.lerp(color, Festive.haldi, 0.35)!).withValues(alpha: 0.9);
      canvas.drawPath(petal, fill);
      canvas.drawPath(petal, edge);
      canvas.rotate(2 * math.pi / petals);
    }
    canvas.restore();
    fill.color = Festive.kumkum;
    for (var i = 0; i < petals; i++) {
      final a = (i + 0.5) * 2 * math.pi / petals;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * (r * 0.8), r * 0.04 + 0.6, fill);
    }
    canvas.drawCircle(
      c,
      ri,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = Festive.zariGradient.createShader(Rect.fromCircle(center: c, radius: ri)),
    );
  }

  @override
  bool shouldRepaint(MandalaRingPainter o) => o.color != color || o.petals != petals;
}

/// Pooja thali: a brass plate with an embossed rim, a lit diya, kumkum, rice
/// and marigold petals. The game emoji sits in the middle (drawn by the widget).
class ThaliPainter extends CustomPainter {
  const ThaliPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.shortestSide / 2 * 0.97;
    canvas.drawCircle(
      c.translate(0, 2),
      r,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Festive.zariLight, Festive.zari, Color(0xFF8C6A14)],
          stops: [0.0, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF7A5A0E);
    canvas.drawCircle(c, r * 0.86, ring);
    canvas.drawCircle(c, r * 0.54, ring);
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.65);
    for (var i = 0; i < 28; i++) {
      final a = i * 2 * math.pi / 28;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * (r * 0.93), r * 0.025 + 0.5, dot);
    }
    Offset at(double deg, double f) {
      final a = deg * math.pi / 180;
      return c + Offset(math.cos(a), math.sin(a)) * (r * f);
    }

    // Diya (bottom-left).
    final d = at(135, 0.7);
    final ds = r * 0.13;
    canvas.drawCircle(d.translate(0, -ds * 0.4), ds * 2.2,
        Paint()..shader = RadialGradient(colors: [Festive.flame.withValues(alpha: 0.7), Festive.flame.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: d.translate(0, -ds * 0.4), radius: ds * 2.2)));
    canvas.drawArc(Rect.fromCenter(center: d, width: ds * 2.2, height: ds * 1.4), 0, math.pi, true,
        Paint()..color = Festive.marigoldDeep);
    canvas.drawOval(Rect.fromCenter(center: d.translate(0, -ds * 0.6), width: ds * 0.7, height: ds * 1.3),
        Paint()..color = Festive.zariLight);
    // Kumkum mound (bottom-right).
    final k = at(45, 0.7);
    canvas.drawCircle(k, r * 0.1, Paint()..color = Festive.kumkum);
    canvas.drawCircle(k.translate(-r * 0.03, -r * 0.03), r * 0.035, Paint()..color = Colors.white.withValues(alpha: 0.4));
    // Rice (top-right).
    final rice = Paint()..color = const Color(0xFFFFF8E1);
    final rc = at(-45, 0.7);
    for (var i = 0; i < 7; i++) {
      final a = i * 2.4;
      canvas.drawOval(
          Rect.fromCenter(center: rc + Offset(math.cos(a), math.sin(a)) * (r * 0.05 * (1 + i % 3)), width: 3, height: 1.8),
          rice);
    }
    // Marigold (top-left).
    _marigold(canvas, at(-135, 0.7), r * 0.11, Festive.marigold);
  }

  @override
  bool shouldRepaint(ThaliPainter o) => o.color != color;
}

/// Banner frame for the thali card: rich gradient, gota-lace scallops along
/// the top and bottom edges, a rangoli corner and a zari edge.
class GotaFramePainter extends CustomPainter {
  const GotaFramePainter({required this.color, required this.base, this.radius = 26});
  final Color color;
  final Color base;
  final double radius;

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Festive.sindoor, 0.4)!.withValues(alpha: 0.9),
            Color.lerp(base, Colors.black, 0.15)!.withValues(alpha: 0.94),
            Color.lerp(Festive.peacock, base, 0.45)!.withValues(alpha: 0.9),
          ],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRRect(rr);
    paintRangoliCorner(canvas, Offset(s.width, s.height), 54, math.pi, 0.3);
    final lace = Paint()..color = Festive.zari.withValues(alpha: 0.75);
    final bead = Paint()..color = Festive.zariLight;
    const step = 12.0;
    for (double x = step / 2; x < s.width; x += step) {
      canvas.drawArc(Rect.fromCircle(center: Offset(x, 0), radius: 5), 0, math.pi, true, lace);
      canvas.drawArc(Rect.fromCircle(center: Offset(x, s.height), radius: 5), math.pi, math.pi, true, lace);
      canvas.drawCircle(Offset(x, 7.5), 1.1, bead);
      canvas.drawCircle(Offset(x, s.height - 7.5), 1.1, bead);
    }
    canvas.restore();
    canvas.drawRRect(
      rr.deflate(0.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..shader = Festive.zariGradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(GotaFramePainter o) => o.color != color || o.base != base || o.radius != radius;
}

/// Small lit diya icon (section headings).
class DiyaPainter extends CustomPainter {
  const DiyaPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final flame = Offset(w / 2, h * 0.32);
    canvas.drawCircle(flame, w * 0.45,
        Paint()..shader = RadialGradient(colors: [Festive.flame.withValues(alpha: 0.6), Festive.flame.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: flame, radius: w * 0.45)));
    canvas.drawOval(Rect.fromCenter(center: flame, width: w * 0.24, height: h * 0.42), Paint()..color = Festive.zariLight);
    canvas.drawOval(Rect.fromCenter(center: flame.translate(0, h * 0.06), width: w * 0.1, height: h * 0.18),
        Paint()..color = Festive.marigoldDeep);
    canvas.drawArc(Rect.fromLTWH(0, h * 0.42, w, h * 0.52), 0, math.pi, true,
        Paint()
          ..shader = const LinearGradient(colors: [Festive.marigoldDeep, Festive.sindoor])
              .createShader(Rect.fromLTWH(0, h * 0.5, w, h * 0.5)));
    canvas.drawLine(Offset(w * 0.08, h * 0.68), Offset(w * 0.92, h * 0.68),
        Paint()
          ..color = Festive.zari
          ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(DiyaPainter oldDelegate) => false;
}

/// Thumbnail of a home layout for the settings selector. [festive] picks
/// between the classic glass grid and the toran + saree-card grid.
class LayoutPreviewPainter extends CustomPainter {
  const LayoutPreviewPainter({required this.festive, required this.bg0, required this.bg1, required this.accent});
  final bool festive;
  final Color bg0, bg1, accent;

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(rect, Paint()..shader = LinearGradient(colors: [bg1, bg0]).createShader(rect));
    final top = festive ? 16.0 : 12.0;
    if (festive) {
      // Mini toran.
      for (double x = 3; x < s.width; x += 5) {
        canvas.drawCircle(Offset(x, 4 + 2 * math.sin(math.pi * x / s.width)), 2.4,
            Paint()..color = (x ~/ 5).isEven ? Festive.marigold : Festive.haldi);
      }
      final leaf = Paint()..color = Festive.leaf;
      for (double x = 8; x < s.width - 4; x += 12) {
        canvas.drawPath(_leafPath(Offset(x, 6 + 2 * math.sin(math.pi * x / s.width)), 8, 3), leaf);
      }
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(6, 4, s.width * 0.4, 5), const Radius.circular(3)),
          Paint()..color = Colors.white.withValues(alpha: 0.5));
    }
    // 2 x 2 card grid.
    const gap = 5.0;
    final cw = (s.width - gap * 3) / 2;
    final ch = (s.height - top - gap * 2) / 2;
    for (var i = 0; i < 4; i++) {
      final r = Rect.fromLTWH(gap + (i % 2) * (cw + gap), top + (i ~/ 2) * (ch + gap), cw, ch);
      final cr = RRect.fromRectAndRadius(r, const Radius.circular(6));
      if (festive) {
        canvas.drawRRect(cr, Paint()..color = Color.lerp(Festive.sindoor, bg1, 0.3)!);
        canvas.save();
        canvas.clipRRect(cr);
        canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 5, r.width, 5), Paint()..color = Festive.marigoldDeep);
        canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 5, r.width, 1), Paint()..color = Festive.zari);
        canvas.restore();
        canvas.drawRRect(cr, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Festive.zari);
        canvas.drawCircle(r.center.translate(0, -2), math.min(cw, ch) * 0.24,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = Festive.marigold);
      } else {
        canvas.drawRRect(cr, Paint()..color = Colors.white.withValues(alpha: 0.14));
        canvas.drawRRect(cr, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white.withValues(alpha: 0.3));
        canvas.drawCircle(r.center.translate(0, -2), math.min(cw, ch) * 0.22, Paint()..color = accent);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LayoutPreviewPainter o) =>
      o.festive != festive || o.bg0 != bg0 || o.bg1 != bg1 || o.accent != accent;
}
