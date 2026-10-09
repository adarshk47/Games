import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'logic/screw_jam_logic.dart';

/// Accent color of the game.
const sjAccent = Color(0xFF94A3B8);
const sjAccentHot = Color(0xFFFFB347);

/// Screw / toolbox colors.
const sjScrewColors = <Color>[
  Color(0xFFEF4444), // red
  Color(0xFF3B82F6), // blue
  Color(0xFF22C55E), // green
  Color(0xFFFACC15), // yellow
  Color(0xFFA855F7), // purple
  Color(0xFFF97316), // orange
  Color(0xFF06B6D4), // cyan
  Color(0xFFEC4899), // pink
  Color(0xFFF1F5F9), // white
  Color(0xFF8B5A2B), // brown
];

Color sjColor(int i) => sjScrewColors[i % sjScrewColors.length];

/// Plate tints (wood and metal both use them, metal desaturated).
const _plateTints = <Color>[
  Color(0xFFE0A15A), // honey
  Color(0xFF6EC6CA), // teal
  Color(0xFFB79CFF), // lilac
  Color(0xFFFF9EAA), // rose
  Color(0xFFA7D86F), // lime
  Color(0xFF7FB2FF), // sky
];

/// Paints a glossy 3D screw head centered at [c] with radius [r].
void paintScrew(Canvas canvas, Offset c, double r, Color color, {double angle = 0, bool shadow = true}) {
  if (shadow) {
    canvas.drawCircle(
      c + Offset(r * 0.12, r * 0.22),
      r * 0.98,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
    );
  }
  final rect = Rect.fromCircle(center: c, radius: r);
  // Washer / rim.
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.5),
        radius: 1.1,
        colors: [
          Color.lerp(color, Colors.white, 0.55)!,
          color,
          Color.lerp(color, Colors.black, 0.6)!,
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect),
  );
  // Domed head.
  final hr = r * 0.78;
  final head = Rect.fromCircle(center: c, radius: hr);
  canvas.drawCircle(
    c,
    hr,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 1.0,
        colors: [
          Color.lerp(color, Colors.white, 0.4)!,
          color,
          Color.lerp(color, Colors.black, 0.35)!,
        ],
        stops: const [0, 0.6, 1],
      ).createShader(head),
  );
  canvas.drawCircle(
    c,
    hr,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.06)
      ..color = Colors.black.withValues(alpha: 0.25),
  );
  // Phillips cross slot.
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(angle + math.pi / 4);
  final slotW = r * 0.2, slotL = r * 0.95;
  final dark = Paint()..color = Color.lerp(color, Colors.black, 0.7)!;
  final lite = Paint()..color = Colors.white.withValues(alpha: 0.35);
  for (final vertical in [false, true]) {
    final rr = RRect.fromRectAndRadius(
      vertical
          ? Rect.fromCenter(center: Offset.zero, width: slotW, height: slotL)
          : Rect.fromCenter(center: Offset.zero, width: slotL, height: slotW),
      Radius.circular(slotW / 2),
    );
    canvas.drawRRect(rr.shift(Offset(0, r * 0.05)), lite);
    canvas.drawRRect(rr, dark);
  }
  canvas.restore();
  // Specular highlight.
  final spec = Rect.fromCenter(center: c + Offset(-r * 0.32, -r * 0.4), width: r * 0.7, height: r * 0.42);
  canvas.drawOval(
    spec,
    Paint()
      ..shader = RadialGradient(colors: [
        Colors.white.withValues(alpha: 0.85),
        Colors.white.withValues(alpha: 0),
      ]).createShader(spec),
  );
}

/// Dark threaded hole.
void paintHole(Canvas canvas, Offset c, double r) {
  canvas.drawCircle(c, r * 1.05, Paint()..color = Colors.white.withValues(alpha: 0.18));
  canvas.drawCircle(
    c,
    r * 0.9,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.3, 0.4),
        colors: [const Color(0xFF3A2E2A), const Color(0xFF0E0A08)],
      ).createShader(Rect.fromCircle(center: c, radius: r)),
  );
  canvas.drawCircle(
    c,
    r * 0.9,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.12)
      ..color = Colors.black.withValues(alpha: 0.5),
  );
}

/// A screw as a widget (boxes, tray, flights).
class ScrewIcon extends StatelessWidget {
  const ScrewIcon({super.key, required this.color, required this.size, this.angle = 0});
  final Color color;
  final double size;
  final double angle;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _ScrewPainter(color, angle));
}

class _ScrewPainter extends CustomPainter {
  _ScrewPainter(this.color, this.angle);
  final Color color;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) =>
      paintScrew(canvas, size.center(Offset.zero), size.shortestSide / 2 * 0.92, color, angle: angle);

  @override
  bool shouldRepaint(_ScrewPainter old) => old.color != color || old.angle != angle;
}

/// Paints one plate (and its remaining screws). The canvas origin is the
/// plate's bounding-box top-left; [cell] is the cell size in pixels.
class PlatePainter extends CustomPainter {
  PlatePainter({
    required this.plate,
    required this.cell,
    required this.screws,
    required this.removed,
  });

  final SjPlate plate;
  final double cell;
  final List<SjScrew> screws;
  final Set<int> removed;

  static double screwRadius(double cell) => cell * 0.31;

  Path _path() {
    final b = plate.bounds;
    final inset = cell * 0.08;
    final rad = Radius.circular(cell * 0.32);
    Path? p;
    for (final part in plate.parts) {
      final r = Rect.fromLTWH(
        (part.c - b.c) * cell + inset,
        (part.r - b.r) * cell + inset,
        part.w * cell - inset * 2,
        part.h * cell - inset * 2,
      );
      final pp = Path()..addRRect(RRect.fromRectAndRadius(r, rad));
      p = p == null ? pp : Path.combine(PathOperation.union, p, pp);
    }
    return p ?? Path();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path();
    final tint = _plateTints[plate.tint % _plateTints.length];
    final metal = plate.material == 1;
    final base = metal ? Color.lerp(tint, const Color(0xFFB8C2CC), 0.55)! : Color.lerp(tint, const Color(0xFFB07A44), 0.35)!;
    canvas.drawShadow(path, Colors.black, cell * 0.12, false);
    final bounds = Offset.zero & size;
    // Translucent body so screws on lower plates stay visible.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, metal ? 0.45 : 0.25)!.withValues(alpha: 0.86),
            base.withValues(alpha: 0.84),
            Color.lerp(base, Colors.black, metal ? 0.25 : 0.3)!.withValues(alpha: 0.88),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(bounds),
    );
    // Texture: wood grain or brushed metal.
    canvas.save();
    canvas.clipPath(path);
    final tex = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = metal ? 0.7 : 1.1;
    final rnd = math.Random(plate.id * 31 + 7);
    if (metal) {
      for (var y = 0.0; y < size.height; y += 3) {
        tex.color = Colors.white.withValues(alpha: 0.05 + rnd.nextDouble() * 0.07);
        canvas.drawLine(Offset(0, y), Offset(size.width, y + 0.5), tex);
      }
    } else {
      final horizontal = size.width >= size.height;
      final span = horizontal ? size.height : size.width;
      for (var k = 0; k < 7; k++) {
        tex.color = Color.lerp(base, Colors.black, 0.45)!.withValues(alpha: 0.18 + rnd.nextDouble() * 0.12);
        final o = span * (0.08 + k * 0.14) + rnd.nextDouble() * 3;
        final wave = Path();
        final len = horizontal ? size.width : size.height;
        for (var t = 0.0; t <= len; t += 6) {
          final w = math.sin(t / (14 + k * 3) + k) * 1.6;
          final pt = horizontal ? Offset(t, o + w) : Offset(o + w, t);
          if (t == 0) {
            wave.moveTo(pt.dx, pt.dy);
          } else {
            wave.lineTo(pt.dx, pt.dy);
          }
        }
        canvas.drawPath(wave, tex);
      }
    }
    // Top light edge.
    canvas.drawPath(
      path.shift(Offset(cell * 0.03, cell * 0.04)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.07
        ..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, cell * 0.035)
        ..color = Colors.white.withValues(alpha: metal ? 0.6 : 0.4),
    );
    // Holes and screws.
    final b = plate.bounds;
    final r = screwRadius(cell);
    for (final s in screws) {
      final c = Offset((s.c - b.c + 0.5) * cell, (s.r - b.r + 0.5) * cell);
      paintHole(canvas, c, r * 0.8);
      if (!removed.contains(s.id)) paintScrew(canvas, c, r, sjColor(s.color), angle: (s.id * 0.7) % math.pi);
    }
  }

  @override
  bool shouldRepaint(PlatePainter old) =>
      old.plate != plate || old.cell != cell || old.removed.length != removed.length || old.screws != screws;
}

/// Horizontal hole positions (fractions of width) of a toolbox.
const sjBoxHoleX = [0.22, 0.5, 0.78];
const sjBoxHoleY = 0.6;

/// Colored toolbox with a handle and three sockets.
class ToolboxPainter extends CustomPainter {
  ToolboxPainter({required this.color, required this.filled});
  final Color color;

  /// Colors visible in each socket (null = empty).
  final List<Color?> filled;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(0, h * 0.22, w, h * 0.78), Radius.circular(h * 0.18));
    // Handle.
    final handle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.09
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(color, Colors.black, 0.35)!;
    final hp = Path()
      ..moveTo(w * 0.33, h * 0.26)
      ..lineTo(w * 0.36, h * 0.06)
      ..lineTo(w * 0.64, h * 0.06)
      ..lineTo(w * 0.67, h * 0.26);
    canvas.drawPath(hp, handle);
    canvas.drawShadow(Path()..addRRect(body), Colors.black, 5, false);
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.35)!,
            color,
            Color.lerp(color, Colors.black, 0.4)!,
          ],
        ).createShader(body.outerRect),
    );
    // Lid seam.
    canvas.drawLine(
      Offset(w * 0.04, h * 0.38),
      Offset(w * 0.96, h * 0.38),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..strokeWidth = 1.5,
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.5),
    );
    final r = h * 0.2;
    for (var i = 0; i < sjBoxHoleX.length; i++) {
      final c = Offset(w * sjBoxHoleX[i], h * sjBoxHoleY);
      paintHole(canvas, c, r * 0.85);
      final f = i < filled.length ? filled[i] : null;
      if (f != null) paintScrew(canvas, c, r, f, angle: i * 0.5);
    }
  }

  @override
  bool shouldRepaint(ToolboxPainter old) =>
      old.color != color || old.filled.length != filled.length || !_same(old.filled, filled);

  static bool _same(List<Color?> a, List<Color?> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Pegboard background behind the plates.
class BoardPainter extends CustomPainter {
  BoardPainter(this.cell);
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * 0.4));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B3F52), Color(0xFF262838), Color(0xFF1B1C28)],
        ).createShader(Offset.zero & size),
    );
    final dot = Paint()..color = Colors.black.withValues(alpha: 0.35);
    final hi = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (var y = cell * 0.5; y < size.height; y += cell * 0.5) {
      for (var x = cell * 0.5; x < size.width; x += cell * 0.5) {
        canvas.drawCircle(Offset(x, y + 0.8), cell * 0.045, hi);
        canvas.drawCircle(Offset(x, y), cell * 0.045, dot);
      }
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.12),
    );
  }

  @override
  bool shouldRepaint(BoardPainter old) => old.cell != cell;
}
