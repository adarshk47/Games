import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The "Master G" logo mark for in-app use (splash, lock screen, home header).
///
/// Paints the same artwork that is used for the launcher icon (see
/// [MasterGLogoPainter] and test/tool/render_icons_test.dart).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.23),
          child: const CustomPaint(painter: MasterGLogoPainter()),
        ),
      );
}

/// Purple-gold "G" logo.
///
/// * [background] paints the indigo gradient square + puzzle-piece motif.
/// * [glyph] paints the glossy gold G (with glow + sparkle).
/// * [monochrome] paints a flat white G only (Android 13 themed icons).
/// * [glyphScale] is the G's outer diameter as a fraction of the shortest side.
class MasterGLogoPainter extends CustomPainter {
  const MasterGLogoPainter({
    this.background = true,
    this.glyph = true,
    this.monochrome = false,
    this.glyphScale = 0.60,
  });

  final bool background;
  final bool glyph;
  final bool monochrome;
  final double glyphScale;

  static const bgLight = Color(0xFF7C5CFF);
  static const bgDark = Color(0xFF2D1B69);
  static const gold = Color(0xFFFFD369);
  static const goldDeep = Color(0xFFF5A623);

  @override
  void paint(Canvas canvas, Size size) {
    if (background && !monochrome) paintBackground(canvas, size);
    if (glyph) _paintG(canvas, size);
  }

  /// Indigo gradient with soft top light, vignette and a faint puzzle piece.
  static void paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final s = size.shortestSide;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgLight, Color(0xFF4B2FB0), bgDark],
          stops: [0.0, 0.45, 1.0],
        ).createShader(rect),
    );
    // Top light.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.75),
          radius: 0.9,
          colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
        ).createShader(rect),
    );
    // Vignette.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.85,
          colors: [Colors.black.withValues(alpha: 0), const Color(0xFF0B0820).withValues(alpha: 0.45)],
          stops: const [0.6, 1.0],
        ).createShader(rect),
    );
    // Faint puzzle piece behind the G.
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-12 * math.pi / 180);
    final piece = puzzlePiecePath(s * 0.62);
    canvas.drawPath(piece, Paint()..color = Colors.white.withValues(alpha: 0.07));
    canvas.drawPath(
      piece,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.008
        ..color = Colors.white.withValues(alpha: 0.14),
    );
    canvas.restore();
  }

  /// A jigsaw piece centred at the origin with side [a].
  static Path puzzlePiecePath(double a) {
    final r = a * 0.17;
    final h = a / 2;
    var p = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: a, height: a), Radius.circular(a * 0.08)));
    final knobs = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, -h - r * 0.55), radius: r))
      ..addOval(Rect.fromCircle(center: Offset(h + r * 0.55, 0), radius: r));
    p = Path.combine(PathOperation.union, p, knobs);
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(-h + r * 0.55, 0), radius: r))
      ..addOval(Rect.fromCircle(center: Offset(0, h - r * 0.55), radius: r));
    return Path.combine(PathOperation.difference, p, holes);
  }

  /// Geometric G: a thick open ring with rounded top terminal and inner bar.
  static Path gPath(Offset c, double outerRadius) {
    final ro = outerRadius;
    final w = ro * 0.36;
    final ri = ro - w;
    final rm = ro - w / 2;
    const a0 = -42 * math.pi / 180;
    const sweep = -(2 * math.pi + a0); // counter-clockwise, ends at angle 0
    final arc = Path()
      ..arcTo(Rect.fromCircle(center: c, radius: ro), a0, sweep, true)
      ..lineTo(c.dx + ri, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: ri), 0, -sweep, false)
      ..close();
    final terminal = Path()
      ..addOval(Rect.fromCircle(center: c + Offset(math.cos(a0), math.sin(a0)) * rm, radius: w / 2));
    final bar = Path.combine(
      PathOperation.intersect,
      Path()
        ..addRRect(RRect.fromRectAndCorners(
          Rect.fromLTRB(c.dx + ro * 0.04, c.dy, c.dx + ro, c.dy + w * 0.92),
          topLeft: Radius.circular(w * 0.2),
          bottomLeft: Radius.circular(w * 0.2),
        )),
      Path()..addOval(Rect.fromCircle(center: c, radius: ro)),
    );
    return Path.combine(PathOperation.union, Path.combine(PathOperation.union, arc, terminal), bar);
  }

  static Path _sparklePath(Offset c, double r) {
    final p = Path()..moveTo(c.dx, c.dy - r);
    final k = r * 0.22;
    p
      ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
      ..close();
    return p;
  }

  void _paintG(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final ro = s * glyphScale / 2;
    final g = gPath(c, ro);

    if (monochrome) {
      canvas.drawPath(g, Paint()..color = Colors.white);
      return;
    }

    final bounds = g.getBounds();
    // Drop shadow + warm glow.
    canvas.drawPath(
      g.shift(Offset(0, s * 0.012)),
      Paint()
        ..color = const Color(0xFF0B0820).withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.018),
    );
    canvas.drawPath(
      g,
      Paint()
        ..color = const Color(0xFFFFC94D).withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.045),
    );
    // Gold body.
    canvas.drawPath(
      g,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF0BE), gold, goldDeep, Color(0xFFD9811A)],
          stops: [0.0, 0.38, 0.78, 1.0],
        ).createShader(bounds),
    );
    // Gloss on the upper half.
    canvas.save();
    canvas.clipPath(g);
    final gloss = Rect.fromLTRB(bounds.left, bounds.top, bounds.right, bounds.top + bounds.height * 0.5);
    canvas.drawOval(
      gloss.inflate(ro * 0.1).shift(Offset(0, -ro * 0.12)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0.0)],
        ).createShader(gloss),
    );
    canvas.restore();
    // Crisp edge for small sizes.
    canvas.drawPath(
      g,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, s * 0.006)
        ..color = const Color(0xFF9A5A0C).withValues(alpha: 0.55),
    );
    // Sparkle near the terminal.
    final sp = c + Offset(ro * 0.98, -ro * 0.98);
    canvas.drawPath(
      _sparklePath(sp, ro * 0.2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.01),
    );
    canvas.drawPath(_sparklePath(sp, ro * 0.17), Paint()..color = const Color(0xFFFFF6DA));
  }

  @override
  bool shouldRepaint(MasterGLogoPainter old) =>
      old.background != background || old.glyph != glyph || old.monochrome != monochrome || old.glyphScale != glyphScale;
}
