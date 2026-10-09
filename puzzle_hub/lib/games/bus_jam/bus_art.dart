import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Accent colors of the Bus Jam screens.
const bjAccent = Color(0xFFF59E0B);
const bjAccentHot = Color(0xFFFFB020);

const _colors = <Color>[
  Color(0xFFFF4D5E), // red
  Color(0xFF3B9BFF), // blue
  Color(0xFF34D27B), // green
  Color(0xFFFFD23F), // yellow
  Color(0xFFA66BFF), // purple
  Color(0xFFFF8A2A), // orange
  Color(0xFFFF6FC8), // pink
  Color(0xFF2EE6E0), // cyan
];

Color bjColor(int i) => _colors[i % _colors.length];

const _skins = <Color>[Color(0xFFFFD7B5), Color(0xFFF1B98C), Color(0xFFC98B5E), Color(0xFF8D5A3B)];
const _hairs = <Color>[Color(0xFF2B1B12), Color(0xFF5A3A22), Color(0xFF1A1A1A), Color(0xFFB0702E), Color(0xFF3A2A1E)];

/// Cute top-down person: shoulders in the passenger color, swinging arms,
/// a round head with hair. [phase] (radians) drives the walk cycle.
class PersonPainter extends CustomPainter {
  PersonPainter({required this.color, this.seed = 0, this.phase = 0, this.walking = false, this.facing = 0, this.dim = false});
  final Color color;
  final int seed;
  final double phase;
  final bool walking;

  /// Rotation in radians (0 = facing up, toward the exit).
  final double facing;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final c = size.center(Offset.zero);
    final bob = walking ? math.sin(phase * 2).abs() * s * 0.04 : 0.0;
    final swing = walking ? math.sin(phase) * s * 0.12 : 0.0;
    final body = dim ? Color.lerp(color, const Color(0xFF555566), 0.55)! : color;

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(0, s * 0.06), width: s * 0.78, height: s * 0.5),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.04),
    );

    canvas.save();
    canvas.translate(c.dx, c.dy - bob);
    canvas.rotate(facing);

    // Arms (hands) swinging opposite each other.
    final arm = Paint()..color = Color.lerp(body, Colors.black, 0.18)!;
    final hand = Paint()..color = _skins[seed % _skins.length];
    for (final side in [-1.0, 1.0]) {
      final o = Offset(side * s * 0.33, -side * swing);
      canvas.drawCircle(o, s * 0.11, arm);
      canvas.drawCircle(o + Offset(0, -s * 0.05 - side * swing * 0.2), s * 0.065, hand);
    }

    // Shoulders / torso.
    final torso = Rect.fromCenter(center: Offset(0, s * 0.03), width: s * 0.66, height: s * 0.42);
    canvas.drawOval(
      torso,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.5),
          radius: 0.9,
          colors: [Color.lerp(body, Colors.white, 0.45)!, body, Color.lerp(body, Colors.black, 0.35)!],
          stops: const [0, 0.55, 1],
        ).createShader(torso),
    );
    canvas.drawOval(
      torso,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.025
        ..color = Color.lerp(body, Colors.black, 0.45)!,
    );

    // Head with hair.
    final hr = s * 0.19;
    final head = Offset(0, -s * 0.02);
    final skin = _skins[seed % _skins.length];
    canvas.drawCircle(head, hr, Paint()..color = Color.lerp(skin, Colors.black, 0.2)!);
    canvas.drawCircle(head, hr * 0.92, Paint()..color = skin);
    final hair = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [Color.lerp(_hairs[seed % _hairs.length], Colors.white, 0.25)!, _hairs[seed % _hairs.length]],
      ).createShader(Rect.fromCircle(center: head, radius: hr));
    // Hair covers the back of the head (we look from above, facing up).
    canvas.drawCircle(head + Offset(0, hr * 0.2), hr * 0.86, hair);
    if (seed % 3 == 0) {
      // Little bun / cap.
      canvas.drawCircle(head + Offset(0, hr * 0.75), hr * 0.38, hair);
    }
    canvas.drawCircle(head + Offset(-hr * 0.35, -hr * 0.1), hr * 0.18, Paint()..color = Colors.white.withValues(alpha: 0.35));
    canvas.restore();
  }

  @override
  bool shouldRepaint(PersonPainter o) =>
      o.color != color || o.phase != phase || o.walking != walking || o.seed != seed || o.facing != facing || o.dim != dim;
}

/// Glossy side-view bus facing left with [kSeats] windows; [riders] holds the
/// color of the passenger in each seat (null = empty).
class BusPainter extends CustomPainter {
  BusPainter({required this.color, required this.riders, this.wheelTurn = 0});
  final Color color;
  final List<Color?> riders;
  final double wheelTurn;

  /// Seat window centers as fractions of the bus size.
  static const seatX = [0.36, 0.56, 0.76];
  static const seatY = 0.4;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bodyRect = Rect.fromLTWH(w * 0.02, h * 0.06, w * 0.96, h * 0.7);
    final body = RRect.fromRectAndCorners(bodyRect,
        topLeft: Radius.circular(h * 0.3),
        bottomLeft: Radius.circular(h * 0.14),
        topRight: Radius.circular(h * 0.16),
        bottomRight: Radius.circular(h * 0.12));

    // Shadow.
    canvas.drawRRect(
      body.shift(Offset(0, h * 0.08)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.06),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.4)!, color, Color.lerp(color, Colors.black, 0.35)!],
          stops: const [0, 0.45, 1],
        ).createShader(bodyRect),
    );
    // Stripe.
    canvas.drawRect(
      Rect.fromLTWH(bodyRect.left + h * 0.1, h * 0.6, bodyRect.width - h * 0.14, h * 0.05),
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
    // Gloss.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.1, h * 0.1, w * 0.84, h * 0.08), Radius.circular(h * 0.05)),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    // Windshield.
    final ws = RRect.fromRectAndCorners(Rect.fromLTWH(w * 0.05, h * 0.18, w * 0.15, h * 0.34),
        topLeft: Radius.circular(h * 0.2), bottomLeft: Radius.circular(h * 0.05), topRight: Radius.circular(h * 0.05));
    canvas.drawRRect(
      ws,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFBFE9FF), Color(0xFF4A86B8)])
            .createShader(ws.outerRect),
    );
    // Seat windows with riders.
    for (var i = 0; i < seatX.length; i++) {
      final r = Rect.fromCenter(center: Offset(w * seatX[i], h * seatY), width: w * 0.17, height: h * 0.34);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(h * 0.07));
      canvas.drawRRect(
        rr,
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD6F1FF), Color(0xFF5D93C4)]).createShader(r),
      );
      final rider = i < riders.length ? riders[i] : null;
      if (rider != null) {
        canvas.save();
        canvas.clipRRect(rr);
        final hc = Offset(r.center.dx, r.top + r.height * 0.42);
        canvas.drawOval(Rect.fromCenter(center: Offset(hc.dx, r.bottom), width: r.width * 0.9, height: r.height * 0.7),
            Paint()..color = rider);
        canvas.drawCircle(hc, r.height * 0.24, Paint()..color = _skins[i % _skins.length]);
        canvas.drawArc(Rect.fromCircle(center: hc, radius: r.height * 0.25), math.pi, math.pi, true,
            Paint()..color = _hairs[(i * 2) % _hairs.length]);
        canvas.restore();
      }
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.025
          ..color = Color.lerp(color, Colors.black, 0.5)!,
      );
    }
    // Headlight + door outline.
    canvas.drawCircle(Offset(w * 0.06, h * 0.62), h * 0.05, Paint()..color = const Color(0xFFFFF4C2));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.86, h * 0.2, w * 0.08, h * 0.48), Radius.circular(h * 0.03)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.02
        ..color = Colors.black.withValues(alpha: 0.3),
    );
    // Wheels.
    for (final x in [0.22, 0.78]) {
      final c = Offset(w * x, h * 0.78);
      canvas.drawCircle(c, h * 0.15, Paint()..color = const Color(0xFF1C1C22));
      canvas.drawCircle(c, h * 0.075, Paint()..color = const Color(0xFFB8BCC8));
      final sp = Paint()
        ..color = const Color(0xFF6B7080)
        ..strokeWidth = h * 0.02;
      for (var k = 0; k < 3; k++) {
        final a = wheelTurn + k * math.pi / 3;
        canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * h * 0.07, c - Offset(math.cos(a), math.sin(a)) * h * 0.07, sp);
      }
    }
  }

  @override
  bool shouldRepaint(BusPainter o) => o.color != color || o.wheelTurn != wheelTurn || !_same(o.riders, riders);

  static bool _same(List<Color?> a, List<Color?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The plaza: paving tiles, the exit edge on top.
class PlazaPainter extends CustomPainter {
  PlazaPainter({required this.cols, required this.rows, required this.cell});
  final int cols, rows;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.3));
    canvas.drawRRect(
      rr.shift(const Offset(0, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5B6478), Color(0xFF3A4054)],
        ).createShader(rect),
    );
    final pad = (size.width - cols * cell) / 2;
    final tile = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if ((r + c).isEven) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(pad + c * cell + 1.5, pad + r * cell + 1.5, cell - 3, cell - 3), Radius.circular(cell * 0.18)),
            tile,
          );
        }
      }
    }
    // Exit edge: yellow dashes along the top.
    final dash = Paint()
      ..color = const Color(0xFFFFD23F)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var x = pad + 4; x < size.width - pad - 4; x += 14) {
      canvas.drawLine(Offset(x, 2.5), Offset(math.min(x + 7, size.width - pad - 4), 2.5), dash);
    }
  }

  @override
  bool shouldRepaint(PlazaPainter o) => o.cols != cols || o.rows != rows || o.cell != cell;
}

/// Obstacle: a planter box with a round bush.
class PlanterPainter extends CustomPainter {
  PlanterPainter(this.seed);
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final r = Rect.fromCenter(center: size.center(Offset.zero), width: s * 0.86, height: s * 0.86);
    final box = RRect.fromRectAndRadius(r, Radius.circular(s * 0.14));
    canvas.drawRRect(box.shift(Offset(0, s * 0.05)), Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawRRect(
      box,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB98A5E), Color(0xFF7A5232)],
        ).createShader(r),
    );
    final leaf = seed.isEven ? const Color(0xFF3FAE5A) : const Color(0xFF2E9A6E);
    final c = size.center(Offset.zero);
    for (final o in [Offset(-0.14, -0.08), Offset(0.14, -0.06), Offset(0, 0.12), Offset(0, -0.02)]) {
      final p = c + o * s;
      canvas.drawCircle(
        p,
        s * 0.2,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            colors: [Color.lerp(leaf, Colors.white, 0.35)!, leaf, Color.lerp(leaf, Colors.black, 0.3)!],
          ).createShader(Rect.fromCircle(center: p, radius: s * 0.2)),
      );
    }
  }

  @override
  bool shouldRepaint(PlanterPainter o) => o.seed != seed;
}

/// Tunnel: a stone arch opening toward [dir] (0 up, 1 right, 2 down, 3 left),
/// tinted by the next passenger's color.
class TunnelPainter extends CustomPainter {
  TunnelPainter({required this.dir, this.next});
  final int dir;
  final Color? next;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final c = size.center(Offset.zero);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(dir * math.pi / 2);
    final r = Rect.fromCenter(center: Offset.zero, width: s * 0.92, height: s * 0.92);
    final rr = RRect.fromRectAndCorners(r,
        topLeft: Radius.circular(s * 0.46), topRight: Radius.circular(s * 0.46), bottomLeft: Radius.circular(s * 0.1), bottomRight: Radius.circular(s * 0.1));
    canvas.drawRRect(rr.shift(Offset(0, s * 0.04)), Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9AA3B8), Color(0xFF5C6478)],
        ).createShader(r),
    );
    // Dark opening facing "up" (rotated to dir).
    final hole = RRect.fromRectAndCorners(Rect.fromCenter(center: Offset(0, -s * 0.06), width: s * 0.56, height: s * 0.6),
        topLeft: Radius.circular(s * 0.28), topRight: Radius.circular(s * 0.28));
    canvas.drawRRect(hole, Paint()..color = const Color(0xFF15131F));
    if (next != null) {
      canvas.drawCircle(Offset(0, -s * 0.12), s * 0.13, Paint()..color = next!.withValues(alpha: 0.9));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(TunnelPainter o) => o.dir != dir || o.next != next;
}

/// Small static bus icon (tier select header).
class BusIcon extends StatelessWidget {
  const BusIcon({super.key, required this.color, this.width = 48});
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(width, width * 0.5),
        painter: BusPainter(color: color, riders: const [null, null, null]),
      );
}

/// Small static person icon.
class PersonIcon extends StatelessWidget {
  const PersonIcon({super.key, required this.color, this.size = 28, this.seed = 0});
  final Color color;
  final double size;
  final int seed;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: PersonPainter(color: color, seed: seed));
}
