import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'festive_palette.dart';

/// Festive overlay for the animated background: two slowly turning rangoli
/// rings, rising diya glows, drifting marigold petals and twinkling sparkles.
///
/// [t] is the background controller value in `[0, 1)`; every motion uses whole
/// cycles per period so the loop is seamless. Particles are precomputed once,
/// so a frame is only a few dozen cheap draw calls (no blur filters).
void paintFestiveLayer(Canvas canvas, Size s, double t, {required Color glow, required Color accent}) {
  if (s.isEmpty) return;
  final tau = 2 * math.pi;
  final side = math.min(s.width, s.height);

  // ---------------------------------------------------------------- rangoli
  _rangoli(canvas, Offset(s.width * 0.92, s.height * 0.1), side * 0.42, t * tau, 0.11);
  _rangoli(canvas, Offset(s.width * 0.06, s.height * 0.86), side * 0.5, -t * tau, 0.09);

  // ---------------------------------------------------------------- diyas
  for (final d in _diyas) {
    final rise = (d.seed + t * d.speed) % 1.0;
    final y = s.height * (1.08 - rise * 1.2);
    final x = s.width * (d.x + 0.025 * math.sin(tau * (t * 2 + d.phase)));
    final flicker = 1 + 0.12 * math.sin(tau * (t * 37 + d.phase));
    // Fade in at the bottom and out near the top.
    final fade = math.min(1.0, math.min(rise * 5, (1 - rise) * 4)).clamp(0.0, 1.0);
    final c = Offset(x, y);
    final r = d.size * 3.2 * flicker;
    _glow.shader = RadialGradient(colors: [
      Color.lerp(Festive.flame, glow, 0.25)!.withValues(alpha: 0.42 * fade),
      Festive.flame.withValues(alpha: 0),
    ]).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, _glow);
    // Clay lamp + flame.
    _fill.color = Festive.marigoldDeep.withValues(alpha: 0.85 * fade);
    canvas.drawArc(Rect.fromCenter(center: c.translate(0, d.size * 0.35), width: d.size * 1.9, height: d.size * 1.1),
        0, math.pi, true, _fill);
    _fill.color = Festive.zariLight.withValues(alpha: 0.95 * fade);
    canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, -d.size * 0.25), width: d.size * 0.55, height: d.size * 1.05 * flicker),
        _fill);
  }

  // ---------------------------------------------------------------- petals
  for (final p in _petals) {
    final fall = (p.seed + t * p.speed) % 1.0;
    final y = s.height * (fall * 1.2 - 0.1);
    final x = s.width * (p.x + 0.05 * math.sin(tau * (t * 3 + p.phase)));
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(tau * (t * p.spin + p.phase));
    _fill.color = p.color.withValues(alpha: 0.7);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: p.size * 1.8, height: p.size), _fill);
    _fill.color = Festive.haldi.withValues(alpha: 0.5);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: p.size * 0.7, height: p.size * 0.35), _fill);
    canvas.restore();
  }

  // ---------------------------------------------------------------- sparkles
  for (final sp in _sparkles) {
    final a = math.pow(math.max(0.0, math.sin(tau * (t * sp.speed + sp.phase))), 3).toDouble();
    if (a < 0.02) continue;
    canvas.save();
    canvas.translate(s.width * sp.x, s.height * sp.y);
    canvas.scale(sp.size * (0.6 + 0.4 * a));
    _fill.color = Color.lerp(Festive.zariLight, accent, 0.2)!.withValues(alpha: 0.85 * a);
    canvas.drawPath(_star, _fill);
    canvas.restore();
  }
}

final _glow = Paint();
final _fill = Paint()..isAntiAlias = true;
final _stroke = Paint()
  ..style = PaintingStyle.stroke
  ..isAntiAlias = true;

/// Unit four-point sparkle centred on the origin.
final Path _star = () {
  const k = 0.18;
  return Path()
    ..moveTo(0, -1)
    ..quadraticBezierTo(k, -k, 1, 0)
    ..quadraticBezierTo(k, k, 0, 1)
    ..quadraticBezierTo(-k, k, -1, 0)
    ..quadraticBezierTo(-k, -k, 0, -1)
    ..close();
}();

void _rangoli(Canvas canvas, Offset c, double r, double rot, double alpha) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(rot * 0.25);
  // Outer petal ring.
  for (var i = 0; i < 16; i++) {
    canvas.save();
    canvas.rotate(i * math.pi / 8);
    _fill.color = Festive.rangoli[i % Festive.rangoli.length].withValues(alpha: alpha);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -r * 0.78), width: r * 0.18, height: r * 0.36), _fill);
    canvas.restore();
  }
  // Inner ring, counter-rotated.
  canvas.rotate(-rot * 0.5);
  for (var i = 0; i < 8; i++) {
    canvas.save();
    canvas.rotate(i * math.pi / 4);
    _fill.color = Festive.rangoli[(i + 2) % Festive.rangoli.length].withValues(alpha: alpha * 1.2);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -r * 0.42), width: r * 0.2, height: r * 0.4), _fill);
    canvas.restore();
  }
  _stroke
    ..strokeWidth = math.max(1, r * 0.012)
    ..color = Festive.zariLight.withValues(alpha: alpha * 1.4);
  canvas.drawCircle(Offset.zero, r * 0.6, _stroke);
  canvas.drawCircle(Offset.zero, r * 0.98, _stroke);
  _fill.color = Festive.haldi.withValues(alpha: alpha * 1.5);
  for (var i = 0; i < 24; i++) {
    final a = i * math.pi / 12;
    canvas.drawCircle(Offset(math.cos(a), math.sin(a)) * (r * 1.06), r * 0.018 + 0.8, _fill);
  }
  _fill.color = Festive.kumkum.withValues(alpha: alpha * 1.5);
  canvas.drawCircle(Offset.zero, r * 0.14, _fill);
  canvas.restore();
}

class _Particle {
  const _Particle(this.x, this.y, this.seed, this.speed, this.phase, this.size, this.spin, this.color);
  final double x, y, seed, phase, size;
  final int speed, spin;
  final Color color;
}

List<_Particle> _make(int n, int seed, double minSize, double maxSize, List<int> speeds) {
  final r = math.Random(seed);
  const colors = [Festive.marigold, Festive.marigoldDeep, Festive.haldi, Festive.kumkum, Festive.marigold];
  return [
    for (var i = 0; i < n; i++)
      _Particle(
        (i + r.nextDouble()) / n, // spread across the width
        r.nextDouble(),
        r.nextDouble(),
        speeds[r.nextInt(speeds.length)],
        r.nextDouble(),
        minSize + r.nextDouble() * (maxSize - minSize),
        1 + r.nextInt(3),
        colors[r.nextInt(colors.length)],
      ),
  ];
}

final _diyas = _make(7, 11, 7, 11, const [1, 2]);
final _petals = _make(14, 23, 6, 10, const [1, 2, 3]);
final _sparkles = _make(18, 37, 3, 6, const [2, 3, 4, 5]);
