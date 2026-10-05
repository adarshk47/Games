import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Car body colors (index = Vehicle.color).
const pjCarColors = <Color>[
  Color(0xFFE53935), // red
  Color(0xFF1E88E5), // blue
  Color(0xFF43A047), // green
  Color(0xFFFDD835), // yellow
  Color(0xFF8E24AA), // purple
  Color(0xFFFB8C00), // orange
  Color(0xFF00ACC1), // cyan
  Color(0xFFEC407A), // pink
];

/// Top-down glossy vehicle drawn nose-up. Rotate it for other headings.
/// [length] 2 = car, 3 = bus ([variant] even) or truck ([variant] odd).
class VehiclePainter extends CustomPainter {
  VehiclePainter({required this.color, required this.length, this.variant = 0, this.glow = 0, this.glowColor});
  final Color color;
  final int length;
  final int variant;

  /// 0..1 highlight strength (hint).
  final double glow;
  final Color? glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final pad = w * 0.11;
    final body = Rect.fromLTRB(pad, pad * 0.6, w - pad, h - pad * 0.6);
    final r = Radius.circular(w * 0.2);
    final rr = RRect.fromRectAndRadius(body, r);

    // Hint glow.
    if (glow > 0) {
      final gc = glowColor ?? Colors.white;
      canvas.drawRRect(
          rr.inflate(w * 0.06),
          Paint()
            ..color = gc.withValues(alpha: 0.35 + 0.45 * glow)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * (0.08 + 0.08 * glow)));
    }
    // Drop shadow.
    canvas.drawRRect(
        rr.shift(Offset(w * 0.04, w * 0.08)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06));

    // Wheels peeking out at the sides.
    final wheel = Paint()..color = const Color(0xFF15161C);
    final ww = w * 0.1, wh = w * 0.3;
    final axles = length == 2 ? [0.22, 0.78] : [0.13, 0.62, 0.86];
    for (final a in axles) {
      final cy = body.top + body.height * a;
      for (final x in [body.left - ww * 0.45, body.right - ww * 0.55]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x, cy - wh / 2, ww, wh), Radius.circular(ww * 0.4)), wheel);
      }
    }

    final dark = Color.lerp(color, Colors.black, 0.4)!;
    final light = Color.lerp(color, Colors.white, 0.35)!;
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [dark, color, light, color, dark],
        stops: const [0, 0.18, 0.45, 0.8, 1],
      ).createShader(body);
    final truck = length == 3 && variant.isOdd;

    if (truck) {
      _truck(canvas, body, w, bodyPaint, dark, light);
    } else {
      canvas.drawRRect(rr, bodyPaint);
      if (length == 2) {
        _car(canvas, body, w, dark, light);
      } else {
        _bus(canvas, body, w, dark, light);
      }
    }

    // Outline.
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, w * 0.02)
          ..color = Colors.black.withValues(alpha: 0.35));
    // Gloss streak on the left flank.
    final gloss = Rect.fromLTWH(body.left + body.width * 0.1, body.top + body.height * 0.06, body.width * 0.12,
        body.height * 0.88);
    canvas.drawRRect(
        RRect.fromRectAndRadius(gloss, Radius.circular(w * 0.06)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0.0)],
          ).createShader(gloss));

    _lights(canvas, body, w);
  }

  void _car(Canvas canvas, Rect b, double w, Color dark, Color light) {
    final glass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9FD3FF), Color(0xFF2B4F7E), Color(0xFF14213D)],
      ).createShader(b);
    // Windshield (trapezoid).
    final ws = Path()
      ..moveTo(b.left + b.width * 0.12, b.top + b.height * 0.40)
      ..lineTo(b.right - b.width * 0.12, b.top + b.height * 0.40)
      ..lineTo(b.right - b.width * 0.2, b.top + b.height * 0.27)
      ..quadraticBezierTo(b.center.dx, b.top + b.height * 0.23, b.left + b.width * 0.2, b.top + b.height * 0.27)
      ..close();
    canvas.drawPath(ws, glass);
    // Roof.
    final roof = Rect.fromLTRB(
        b.left + b.width * 0.14, b.top + b.height * 0.42, b.right - b.width * 0.14, b.top + b.height * 0.72);
    canvas.drawRRect(
        RRect.fromRectAndRadius(roof, Radius.circular(w * 0.1)),
        Paint()
          ..shader = LinearGradient(colors: [Color.lerp(dark, light, 0.4)!, light, Color.lerp(dark, light, 0.5)!])
              .createShader(roof));
    // Rear window.
    final rw = Path()
      ..moveTo(b.left + b.width * 0.15, b.top + b.height * 0.74)
      ..lineTo(b.right - b.width * 0.15, b.top + b.height * 0.74)
      ..lineTo(b.right - b.width * 0.22, b.top + b.height * 0.84)
      ..lineTo(b.left + b.width * 0.22, b.top + b.height * 0.84)
      ..close();
    canvas.drawPath(rw, glass);
    // Hood line.
    canvas.drawLine(
        Offset(b.center.dx, b.top + b.height * 0.06),
        Offset(b.center.dx, b.top + b.height * 0.22),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..strokeWidth = math.max(1, w * 0.015));
    // Side mirrors.
    final mirror = Paint()..color = dark;
    for (final x in [b.left - w * 0.05, b.right - w * 0.03]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, b.top + b.height * 0.36, w * 0.08, w * 0.06), Radius.circular(w * 0.03)),
          mirror);
    }
  }

  void _bus(Canvas canvas, Rect b, double w, Color dark, Color light) {
    final glass = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF9FD3FF), Color(0xFF2B4F7E)]).createShader(b);
    // Front windshield.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(b.left + b.width * 0.1, b.top + b.height * 0.04, b.right - b.width * 0.1, b.top + b.height * 0.12),
            Radius.circular(w * 0.06)),
        glass);
    // Side window strips.
    final win = Paint()..color = const Color(0xFF1F3657);
    for (var i = 0; i < 6; i++) {
      final y = b.top + b.height * (0.17 + i * 0.13);
      for (final x in [b.left + b.width * 0.04, b.right - b.width * 0.14]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x, y, b.width * 0.1, b.height * 0.1), Radius.circular(w * 0.02)), win);
      }
    }
    // Roof panel with AC units.
    final roof = Rect.fromLTRB(
        b.left + b.width * 0.2, b.top + b.height * 0.16, b.right - b.width * 0.2, b.bottom - b.height * 0.06);
    canvas.drawRRect(RRect.fromRectAndRadius(roof, Radius.circular(w * 0.08)),
        Paint()..shader = LinearGradient(colors: [light, Colors.white.withValues(alpha: 0.9), light]).createShader(roof));
    final ac = Paint()..color = Colors.grey.shade400;
    for (final f in [0.3, 0.62]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(b.center.dx, b.top + b.height * f), width: b.width * 0.42, height: b.height * 0.1),
              Radius.circular(w * 0.04)),
          ac);
    }
  }

  void _truck(Canvas canvas, Rect b, double w, Paint bodyPaint, Color dark, Color light) {
    // Cab.
    final cab = Rect.fromLTRB(b.left, b.top, b.right, b.top + b.height * 0.3);
    canvas.drawRRect(RRect.fromRectAndCorners(cab, topLeft: Radius.circular(w * 0.2), topRight: Radius.circular(w * 0.2),
        bottomLeft: Radius.circular(w * 0.06), bottomRight: Radius.circular(w * 0.06)), bodyPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(cab.left + cab.width * 0.12, cab.top + cab.height * 0.42, cab.right - cab.width * 0.12,
                cab.top + cab.height * 0.7),
            Radius.circular(w * 0.05)),
        Paint()..shader = const LinearGradient(colors: [Color(0xFF9FD3FF), Color(0xFF2B4F7E)]).createShader(cab));
    // Cargo box.
    final box = Rect.fromLTRB(b.left - w * 0.01, b.top + b.height * 0.33, b.right + w * 0.01, b.bottom);
    canvas.drawRRect(
        RRect.fromRectAndRadius(box, Radius.circular(w * 0.06)),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF9EA3AE), Color(0xFFF2F4F8), Color(0xFFC9CDD6), Color(0xFF8C919C)],
            stops: [0, 0.4, 0.75, 1],
          ).createShader(box));
    // Colored stripe + ribs.
    canvas.drawRect(Rect.fromLTWH(box.left, box.top + box.height * 0.04, box.width, box.height * 0.06), Paint()..color = color);
    final rib = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = math.max(1, w * 0.012);
    for (var i = 1; i < 6; i++) {
      final y = box.top + box.height * (0.12 + i * 0.14);
      canvas.drawLine(Offset(box.left + w * 0.04, y), Offset(box.right - w * 0.04, y), rib);
    }
  }

  void _lights(Canvas canvas, Rect b, double w) {
    final head = Paint()..color = const Color(0xFFFFF6C8);
    final headGlow = Paint()
      ..color = const Color(0xFFFFF1A8).withValues(alpha: 0.7)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05);
    final tail = Paint()..color = const Color(0xFFFF2D3A);
    for (final x in [b.left + b.width * 0.2, b.right - b.width * 0.2]) {
      final c = Offset(x, b.top + w * 0.05);
      canvas.drawOval(Rect.fromCenter(center: c.translate(0, -w * 0.02), width: w * 0.2, height: w * 0.12), headGlow);
      canvas.drawOval(Rect.fromCenter(center: c, width: w * 0.14, height: w * 0.07), head);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, b.bottom - w * 0.04), width: w * 0.16, height: w * 0.05),
              Radius.circular(w * 0.02)),
          tail);
    }
  }

  @override
  bool shouldRepaint(VehiclePainter old) =>
      old.color != color || old.length != length || old.variant != variant || old.glow != glow || old.glowColor != glowColor;
}

/// Top-down traffic cone.
class ConePainter extends CustomPainter {
  const ConePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = size.center(Offset.zero);
    canvas.drawCircle(
        c.translate(w * 0.04, w * 0.07),
        w * 0.34,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05));
    final base = Rect.fromCenter(center: c, width: w * 0.7, height: w * 0.7);
    canvas.drawRRect(RRect.fromRectAndRadius(base, Radius.circular(w * 0.1)), Paint()..color = const Color(0xFFD9480F));
    canvas.drawCircle(
        c,
        w * 0.28,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.3),
            colors: [Color(0xFFFFB37A), Color(0xFFFF6A1A), Color(0xFFC2410C)],
          ).createShader(Rect.fromCircle(center: c, radius: w * 0.28)));
    canvas.drawCircle(
        c,
        w * 0.17,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.07
          ..color = Colors.white.withValues(alpha: 0.95));
    canvas.drawCircle(c, w * 0.07, Paint()..color = const Color(0xFFFF8A3D));
  }

  @override
  bool shouldRepaint(ConePainter old) => false;
}

/// Asphalt lot ([n] x [n] cells) with parking lines, surrounded by a road
/// ring [margin] cells wide.
class LotPainter extends CustomPainter {
  const LotPainter({required this.n, required this.margin});
  final int n;
  final double margin;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / (n + 2 * margin);
    final full = Offset.zero & size;
    // Road.
    canvas.drawRect(
        full,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF262833), Color(0xFF1B1C24)],
          ).createShader(full));
    // Dashed road center line around the lot.
    final mid = Rect.fromLTWH(margin * cell * 0.45, margin * cell * 0.45, size.width - margin * cell * 0.9,
        size.height - margin * cell * 0.9);
    final dash = Paint()
      ..color = const Color(0xFFFFC94D).withValues(alpha: 0.55)
      ..strokeWidth = math.max(1.2, cell * 0.04);
    final step = cell * 0.5;
    for (var x = mid.left; x < mid.right; x += step) {
      final x2 = math.min(x + step * 0.55, mid.right);
      canvas.drawLine(Offset(x, mid.top), Offset(x2, mid.top), dash);
      canvas.drawLine(Offset(x, mid.bottom), Offset(x2, mid.bottom), dash);
    }
    for (var y = mid.top; y < mid.bottom; y += step) {
      final y2 = math.min(y + step * 0.55, mid.bottom);
      canvas.drawLine(Offset(mid.left, y), Offset(mid.left, y2), dash);
      canvas.drawLine(Offset(mid.right, y), Offset(mid.right, y2), dash);
    }

    // Lot asphalt.
    final lot = Rect.fromLTWH(margin * cell, margin * cell, n * cell, n * cell);
    final lotR = RRect.fromRectAndRadius(lot, Radius.circular(cell * 0.12));
    canvas.drawRRect(
        lotR.inflate(cell * 0.05),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.12));
    canvas.drawRRect(
        lotR,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A4D5C), Color(0xFF3A3C48), Color(0xFF30323D)],
          ).createShader(lot));
    // Asphalt speckle (deterministic).
    final speck = Paint()..color = Colors.white.withValues(alpha: 0.05);
    var seed = 1234567;
    for (var i = 0; i < n * n * 6; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final x = lot.left + (seed % 10000) / 10000 * lot.width;
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final y = lot.top + (seed % 10000) / 10000 * lot.height;
      canvas.drawCircle(Offset(x, y), cell * 0.025, speck);
    }
    // Parking bay lines.
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = math.max(1, cell * 0.025);
    for (var i = 1; i < n; i++) {
      final o = i * cell;
      canvas.drawLine(Offset(lot.left + o, lot.top + cell * 0.1), Offset(lot.left + o, lot.bottom - cell * 0.1), line);
      canvas.drawLine(Offset(lot.left + cell * 0.1, lot.top + o), Offset(lot.right - cell * 0.1, lot.top + o), line);
    }
    // Curb.
    canvas.drawRRect(
        lotR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, cell * 0.05)
          ..color = Colors.white.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(LotPainter old) => old.n != n || old.margin != margin;
}
