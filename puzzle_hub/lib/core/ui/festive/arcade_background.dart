import 'dart:math' as math;

import 'package:flutter/material.dart';

/// "Master Arcade" theme layer: game pieces (dice, Ludo tokens, arrows,
/// puzzle pieces, stars) drifting slowly upward in the four Ludo colours,
/// matching the app icon. Painted over the animated orb background.
void paintArcadeLayer(Canvas canvas, Size s, double t) {
  if (s.isEmpty) return;
  const tau = 2 * math.pi;
  final side = math.min(s.width, s.height);
  for (final p in _pieces) {
    final rise = (p.seed + t * p.speed) % 1.0;
    final y = s.height * (1.1 - rise * 1.25);
    final x = s.width * (p.x + 0.03 * math.sin(tau * (t * 2 + p.phase)));
    final fade = math.min(1.0, math.min(rise * 4, (1 - rise) * 4)).clamp(0.0, 1.0);
    final size = side * p.size;
    final c = Offset(x, y);
    // Soft glow behind every piece.
    _glow.shader = RadialGradient(colors: [p.color.withValues(alpha: 0.28 * fade), p.color.withValues(alpha: 0)])
        .createShader(Rect.fromCircle(center: c, radius: size * 1.6));
    canvas.drawCircle(c, size * 1.6, _glow);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(p.spin * tau * t + p.phase * tau);
    _fill.color = p.color.withValues(alpha: 0.55 * fade);
    _line.color = Colors.white.withValues(alpha: 0.35 * fade);
    switch (p.kind) {
      case 0:
        _dice(canvas, size, fade);
      case 1:
        _token(canvas, size, fade);
      case 2:
        _arrow(canvas, size);
      case 3:
        _puzzle(canvas, size);
      default:
        _star(canvas, size * 0.7);
    }
    canvas.restore();
  }
}

void _dice(Canvas canvas, double size, double fade) {
  final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: size, height: size), Radius.circular(size * 0.22));
  canvas.drawRRect(r, _fill);
  canvas.drawRRect(r, _line);
  _pip.color = Colors.white.withValues(alpha: 0.7 * fade);
  for (final o in const [Offset(-0.25, -0.25), Offset(0, 0), Offset(0.25, 0.25)]) {
    canvas.drawCircle(Offset(o.dx * size, o.dy * size), size * 0.08, _pip);
  }
}

void _token(Canvas canvas, double size, double fade) {
  canvas.drawCircle(Offset.zero, size * 0.5, _fill);
  canvas.drawCircle(Offset.zero, size * 0.5, _line);
  _pip.color = Colors.white.withValues(alpha: 0.45 * fade);
  canvas.drawCircle(Offset.zero, size * 0.22, _pip);
}

void _arrow(Canvas canvas, double size) {
  final h = size * 0.5;
  final path = Path()
    ..moveTo(-h, -h * 0.35)
    ..lineTo(h * 0.1, -h * 0.35)
    ..lineTo(h * 0.1, -h * 0.8)
    ..lineTo(h, 0)
    ..lineTo(h * 0.1, h * 0.8)
    ..lineTo(h * 0.1, h * 0.35)
    ..lineTo(-h, h * 0.35)
    ..close();
  canvas.drawPath(path, _fill);
  canvas.drawPath(path, _line);
}

void _puzzle(Canvas canvas, double size) {
  final h = size * 0.42;
  final path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: h * 2, height: h * 2), Radius.circular(h * 0.25)));
  path.addOval(Rect.fromCircle(center: Offset(0, -h), radius: h * 0.4));
  path.addOval(Rect.fromCircle(center: Offset(h, 0), radius: h * 0.4));
  canvas.drawPath(path, _fill);
}

void _star(Canvas canvas, double size) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? size * 0.5 : size * 0.2;
    final a = -math.pi / 2 + i * math.pi / 5;
    final p = Offset(r * math.cos(a), r * math.sin(a));
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  canvas.drawPath(path, _fill);
}

final _glow = Paint();
final _fill = Paint();
final _pip = Paint();
final _line = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.2;

const _red = Color(0xFFFF5A5F), _green = Color(0xFF34D399), _yellow = Color(0xFFFFD166), _blue = Color(0xFF4DA8FF), _gold = Color(0xFFFFD369);

class _Piece {
  const _Piece(this.kind, this.x, this.seed, this.speed, this.size, this.color, this.spin, this.phase);
  final int kind;
  final double x, seed, speed, size, spin, phase;
  final Color color;
}

const _pieces = [
  _Piece(0, 0.08, 0.00, 0.9, 0.060, _red, 0.4, 0.1),
  _Piece(1, 0.22, 0.35, 1.1, 0.050, _green, 0.0, 0.3),
  _Piece(2, 0.38, 0.70, 0.8, 0.065, _blue, 0.2, 0.5),
  _Piece(3, 0.55, 0.15, 1.0, 0.055, _yellow, 0.3, 0.7),
  _Piece(4, 0.70, 0.50, 1.3, 0.045, _gold, 0.6, 0.2),
  _Piece(0, 0.86, 0.85, 0.95, 0.055, _blue, -0.4, 0.9),
  _Piece(1, 0.94, 0.25, 1.2, 0.045, _red, 0.0, 0.4),
  _Piece(2, 0.15, 0.60, 1.05, 0.050, _yellow, -0.2, 0.6),
  _Piece(3, 0.46, 0.92, 0.85, 0.050, _green, -0.3, 0.8),
  _Piece(4, 0.64, 0.05, 1.15, 0.040, _gold, -0.5, 0.0),
  _Piece(4, 0.30, 0.45, 1.4, 0.030, _gold, 0.7, 0.35),
  _Piece(1, 0.78, 0.68, 0.9, 0.040, _yellow, 0.0, 0.55),
];
