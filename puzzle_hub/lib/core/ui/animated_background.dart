import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'palette.dart';

/// Deep gradient with slowly drifting glow orbs. Cheap: one AnimationController,
/// one CustomPaint. [tint] shifts the glow color per game.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key, this.tint, this.child});
  final Color? tint;
  final Widget? child;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(painter: _OrbPainter(_c.value, widget.tint ?? Pal.bg2)),
        ),
      ),
      if (widget.child != null) widget.child!,
    ]);
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.t, this.tint);
  final double t;
  final Color tint;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Pal.bg0, Pal.bg1, Pal.bg0],
        ).createShader(Offset.zero & s),
    );
    final a = t * 2 * math.pi;
    void orb(double fx, double fy, double r, Color c, double phase) {
      final center = Offset(
        s.width * (fx + 0.12 * math.sin(a + phase)),
        s.height * (fy + 0.08 * math.cos(a * 1.3 + phase)),
      );
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(colors: [c.withValues(alpha: 0.55), c.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    orb(0.15, 0.12, s.width * 0.7, tint, 0);
    orb(0.9, 0.45, s.width * 0.6, Color.lerp(tint, Pal.gold, 0.35)!, 2);
    orb(0.2, 0.9, s.width * 0.75, Color.lerp(tint, const Color(0xFFFF6FB5), 0.4)!, 4);
  }

  @override
  bool shouldRepaint(_OrbPainter o) => o.t != t || o.tint != tint;
}
