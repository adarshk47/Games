import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decoration layers of the seasonal themes, painted over the orb background.
/// [t] runs 0→1 over the background loop.
const _tau = 2 * math.pi;
final _p = Paint();
final _stroke = Paint()..style = PaintingStyle.stroke;

double _fade(double v) => math.min(1.0, math.min(v * 4, (1 - v) * 4)).clamp(0.0, 1.0);

/// Snow falling from the top (used by Winter and Christmas).
void _snow(Canvas canvas, Size s, double t, {int count = 34, double alpha = 0.8}) {
  for (var i = 0; i < count; i++) {
    final seed = (i * 0.6180339) % 1.0;
    final speed = 0.6 + (i % 5) * 0.12;
    final fall = (seed + t * speed) % 1.0;
    final x = s.width * ((i * 0.137 + 0.03 * math.sin(_tau * (t * 2 + seed))) % 1.0);
    final y = s.height * (fall * 1.1 - 0.05);
    final r = 1.4 + (i % 4) * 0.9;
    _p
      ..shader = null
      ..color = Colors.white.withValues(alpha: alpha * _fade(fall));
    canvas.drawCircle(Offset(x, y), r, _p);
  }
}

/// A string of twinkling fairy lights across the top.
void _fairyLights(Canvas canvas, Size s, double t, List<Color> colors) {
  final path = Path()..moveTo(0, s.height * 0.035);
  path.quadraticBezierTo(s.width * 0.5, s.height * 0.09, s.width, s.height * 0.035);
  _stroke
    ..color = Colors.white.withValues(alpha: 0.25)
    ..strokeWidth = 1.2;
  canvas.drawPath(path, _stroke);
  const n = 14;
  for (var i = 0; i <= n; i++) {
    final f = i / n;
    final x = s.width * f;
    final y = s.height * (0.035 + 0.11 * f * (1 - f));
    final on = 0.55 + 0.45 * math.sin(_tau * (t * 6 + i * 0.37));
    final c = colors[i % colors.length];
    _p.shader = RadialGradient(colors: [c.withValues(alpha: 0.7 * on), c.withValues(alpha: 0)])
        .createShader(Rect.fromCircle(center: Offset(x, y + 6), radius: 14));
    canvas.drawCircle(Offset(x, y + 6), 14, _p);
    _p
      ..shader = null
      ..color = c.withValues(alpha: 0.6 + 0.4 * on);
    canvas.drawCircle(Offset(x, y + 6), 3.2, _p);
  }
}

void paintWinterLayer(Canvas canvas, Size s, double t) {
  if (s.isEmpty) return;
  _fairyLights(canvas, s, t, const [Color(0xFFBFE9FF), Color(0xFFFFFFFF), Color(0xFF93C5FD)]);
  _snow(canvas, s, t);
  // Soft snow hills at the bottom.
  final hill = Path()
    ..moveTo(0, s.height)
    ..lineTo(0, s.height * 0.93)
    ..quadraticBezierTo(s.width * 0.3, s.height * 0.88, s.width * 0.6, s.height * 0.94)
    ..quadraticBezierTo(s.width * 0.85, s.height * 0.98, s.width, s.height * 0.92)
    ..lineTo(s.width, s.height)
    ..close();
  _p
    ..shader = null
    ..color = Colors.white.withValues(alpha: 0.10);
  canvas.drawPath(hill, _p);
}

void paintChristmasLayer(Canvas canvas, Size s, double t) {
  if (s.isEmpty) return;
  _fairyLights(canvas, s, t, const [Color(0xFFEF4444), Color(0xFFFACC15), Color(0xFF22C55E), Color(0xFF60A5FA)]);
  _snow(canvas, s, t, count: 26, alpha: 0.7);
  // Baubles gently swinging and a star.
  for (var i = 0; i < 6; i++) {
    final seed = (i * 0.37) % 1.0;
    final rise = (seed + t * 0.5) % 1.0;
    final x = s.width * (0.1 + 0.16 * i + 0.02 * math.sin(_tau * (t * 3 + seed)));
    final y = s.height * (1.05 - rise * 1.15);
    final c = i.isEven ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final r = 9.0 + (i % 3) * 3;
    final a = _fade(rise);
    _p.shader = RadialGradient(colors: [Color.lerp(c, Colors.white, 0.45)!.withValues(alpha: 0.75 * a), c.withValues(alpha: 0.55 * a)])
        .createShader(Rect.fromCircle(center: Offset(x - r * 0.3, y - r * 0.3), radius: r * 1.4));
    canvas.drawCircle(Offset(x, y), r, _p);
    _p
      ..shader = null
      ..color = const Color(0xFFFDE68A).withValues(alpha: 0.7 * a);
    canvas.drawRect(Rect.fromCenter(center: Offset(x, y - r - 2), width: r * 0.6, height: 4), _p);
  }
  _starShape(canvas, Offset(s.width * 0.88, s.height * 0.16), 16 + 2 * math.sin(_tau * t * 4), const Color(0xFFFDE68A));
}

void paintNewYearLayer(Canvas canvas, Size s, double t) {
  if (s.isEmpty) return;
  const colors = [Color(0xFFF472B6), Color(0xFFFACC15), Color(0xFF22D3EE), Color(0xFFA78BFA), Color(0xFF34D399)];
  // Fireworks: each bursts, fades, and starts again at its own time.
  for (var i = 0; i < 5; i++) {
    final phase = ((t * 1.6) + i * 0.21) % 1.0;
    final c = Offset(s.width * (0.15 + 0.18 * i), s.height * (0.15 + 0.12 * ((i * 3) % 4)));
    final col = colors[i % colors.length];
    final r = math.min(s.width, s.height) * 0.16 * Curves.easeOut.transform(phase);
    final a = (1 - phase).clamp(0.0, 1.0);
    for (var k = 0; k < 14; k++) {
      final ang = _tau * k / 14 + i;
      final p = c + Offset(math.cos(ang) * r, math.sin(ang) * r + phase * phase * 18);
      _p
        ..shader = null
        ..color = col.withValues(alpha: 0.85 * a);
      canvas.drawCircle(p, 2.4, _p);
    }
    _p.shader = RadialGradient(colors: [col.withValues(alpha: 0.35 * a), col.withValues(alpha: 0)])
        .createShader(Rect.fromCircle(center: c, radius: r + 10));
    canvas.drawCircle(c, r + 10, _p);
  }
  // Confetti drifting down.
  for (var i = 0; i < 28; i++) {
    final seed = (i * 0.6180339) % 1.0;
    final fall = (seed + t * (0.7 + (i % 4) * 0.15)) % 1.0;
    final x = s.width * ((i * 0.173 + 0.04 * math.sin(_tau * (t * 3 + seed))) % 1.0);
    final y = s.height * (fall * 1.1 - 0.05);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(_tau * (t * 4 + seed));
    _p
      ..shader = null
      ..color = colors[i % colors.length].withValues(alpha: 0.75 * _fade(fall));
    canvas.drawRect(const Rect.fromLTWH(-3, -1.5, 6, 3), _p);
    canvas.restore();
  }
}

void paintNeonLayer(Canvas canvas, Size s, double t) {
  if (s.isEmpty) return;
  // Synthwave grid at the bottom, scrolling towards the viewer.
  final horizon = s.height * 0.72;
  const pink = Color(0xFFFF2BD6), cyan = Color(0xFF00F0FF);
  _stroke.strokeWidth = 1.2;
  for (var i = 0; i < 9; i++) {
    final f = ((i + t * 3) % 9) / 9;
    final y = horizon + (s.height - horizon) * f * f;
    _stroke.color = pink.withValues(alpha: 0.18 + 0.35 * f);
    canvas.drawLine(Offset(0, y), Offset(s.width, y), _stroke);
  }
  for (var i = -6; i <= 6; i++) {
    _stroke.color = cyan.withValues(alpha: 0.25);
    canvas.drawLine(Offset(s.width / 2 + i * s.width * 0.03, horizon), Offset(s.width / 2 + i * s.width * 0.25, s.height), _stroke);
  }
  // Glowing sun on the horizon.
  final sun = Offset(s.width * 0.5, horizon);
  _p.shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFD166), pink])
      .createShader(Rect.fromCircle(center: sun, radius: s.width * 0.18));
  canvas.save();
  canvas.clipRect(Rect.fromLTRB(0, 0, s.width, horizon));
  canvas.drawCircle(sun, s.width * 0.18, _p..color = Colors.white.withValues(alpha: 0.35));
  canvas.restore();
  // Floating neon rings.
  for (var i = 0; i < 6; i++) {
    final seed = (i * 0.29) % 1.0;
    final rise = (seed + t * 0.6) % 1.0;
    final c = Offset(s.width * (0.12 + 0.15 * i), s.height * (0.7 - rise * 0.75));
    final col = i.isEven ? pink : cyan;
    _stroke
      ..strokeWidth = 2
      ..color = col.withValues(alpha: 0.55 * _fade(rise));
    canvas.drawCircle(c, 8 + (i % 3) * 4, _stroke);
  }
}

void _starShape(Canvas canvas, Offset c, double size, Color color) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? size : size * 0.42;
    final a = -math.pi / 2 + i * math.pi / 5;
    final p = c + Offset(r * math.cos(a), r * math.sin(a));
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  _p.shader = RadialGradient(colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0)])
      .createShader(Rect.fromCircle(center: c, radius: size * 2.2));
  canvas.drawCircle(c, size * 2.2, _p);
  _p
    ..shader = null
    ..color = color;
  canvas.drawPath(path, _p);
}
