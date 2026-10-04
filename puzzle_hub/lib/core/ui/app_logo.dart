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

/// Purple-gold "Master G" logo: game motifs above the M-aster-G wordmark.
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
    this.fontFamily,
  });

  final bool background;
  final bool glyph;
  final bool monochrome;
  final double glyphScale;

  /// Font for the wordmark / 2048 tile (null = platform default).
  final String? fontFamily;

  static const bgLight = Color(0xFF7C5CFF);
  static const bgDark = Color(0xFF2D1B69);
  static const gold = Color(0xFFFFD369);
  static const goldDeep = Color(0xFFF5A623);

  @override
  void paint(Canvas canvas, Size size) {
    if (background && !monochrome) paintBackground(canvas, size);
    if (glyph) _paintArt(canvas, size);
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


  /// Game motifs (snake arrow, 2048 tile, rows of blocks) above the
  /// "Master G" wordmark: big M, small "aster", medium G.
  void _paintArt(Canvas canvas, Size size) {
    final s = size.shortestSide;
    // Content box: glyphScale 0.60 = full icon; smaller values (adaptive
    // foreground) shrink everything to stay inside the safe zone.
    final b = s * 0.84 * (glyphScale / 0.60);
    final o = size.center(Offset.zero) - Offset(b / 2, b / 2);
    Offset at(double x, double y) => o + Offset(x * b, y * b);
    final white = Colors.white;

    // --- Snake arrow (left) ---
    final arrow = Path()
      ..moveTo(at(0.07, 0.50).dx, at(0.07, 0.50).dy)
      ..lineTo(at(0.07, 0.27).dx, at(0.07, 0.27).dy)
      ..lineTo(at(0.21, 0.27).dx, at(0.21, 0.27).dy)
      ..lineTo(at(0.21, 0.13).dx, at(0.21, 0.13).dy);
    final arrowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = b * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final head = Path()
      ..moveTo(at(0.21, 0.04).dx, at(0.21, 0.04).dy)
      ..lineTo(at(0.30, 0.15).dx, at(0.30, 0.15).dy)
      ..lineTo(at(0.12, 0.15).dx, at(0.12, 0.15).dy)
      ..close();
    if (monochrome) {
      canvas.drawPath(arrow, arrowPaint..color = white);
      canvas.drawPath(head, Paint()..color = white);
    } else {
      canvas.drawPath(arrow, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = b * 0.075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF5EEAD4).withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, b * 0.02));
      canvas.drawPath(arrow, arrowPaint..color = const Color(0xFF5EEAD4));
      canvas.drawPath(head, Paint()..color = const Color(0xFF5EEAD4));
    }

    // --- 2048 tile (centre) ---
    final tile = RRect.fromRectAndRadius(Rect.fromPoints(at(0.33, 0.05), at(0.70, 0.42)), Radius.circular(b * 0.07));
    if (monochrome) {
      canvas.drawRRect(tile, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = b * 0.03
        ..color = white);
    } else {
      canvas.drawRRect(tile.shift(Offset(0, b * 0.015)), Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, b * 0.02));
      canvas.drawRRect(tile, Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE08A), goldDeep, Color(0xFFE2711D)],
        ).createShader(tile.outerRect));
      canvas.drawRRect(tile, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, b * 0.008)
        ..color = Colors.white.withValues(alpha: 0.55));
    }
    final num = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: '2048',
        style: TextStyle(fontFamily: fontFamily, fontSize: b * 0.125, fontWeight: FontWeight.w900, color: white, height: 1),
      ),
    )..layout();
    num.paint(canvas, tile.center - Offset(num.width / 2, num.height / 2));

    // --- Rows of blocks (right) ---
    const rows = [
      [Color(0xFFFF6FB5), Color(0xFFFF6FB5)],
      [Color(0xFF4DA8FF), Color(0xFF4DA8FF)],
      [Color(0xFF4ADE80), Color(0xFF4ADE80)],
    ];
    final cell = b * 0.095, gap = b * 0.022;
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < 2; c++) {
        final tl = at(0.76, 0.08) + Offset(c * (cell + gap), r * (cell + gap));
        final rr = RRect.fromRectAndRadius(tl & Size(cell, cell), Radius.circular(cell * 0.25));
        canvas.drawRRect(rr, Paint()..color = monochrome ? white : rows[r][c]);
        if (!monochrome) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(tl.dx + cell * 0.15, tl.dy + cell * 0.12, cell * 0.7, cell * 0.22),
                  Radius.circular(cell * 0.1)),
              Paint()..color = Colors.white.withValues(alpha: 0.35));
        }
      }
    }

    // --- Wordmark: big M, small "aster", medium G (all on one baseline) ---
    final goldShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFF0BE), gold, goldDeep],
    ).createShader(Rect.fromLTWH(0, 0, b, b * 0.36)); // text-local coords (painted after translate)
    final shadow = monochrome ? null : [Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: b * 0.02, offset: Offset(0, b * 0.01))];
    TextStyle st(double size, {bool goldText = false}) => TextStyle(
          fontFamily: fontFamily,
          fontSize: b * size,
          fontWeight: FontWeight.w900,
          height: 1,
          shadows: shadow,
          foreground: Paint()
            ..shader = (goldText && !monochrome) ? goldShader : null
            ..color = (goldText && !monochrome) ? gold : white,
        );
    final word = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(children: [
        TextSpan(text: 'M', style: st(0.36, goldText: true)),
        TextSpan(text: 'aster', style: st(0.17)),
        TextSpan(text: ' G', style: st(0.25, goldText: true)),
      ]),
    )..layout();
    // Shrink to fit the content width if the font is wide.
    final scale = math.min(1.0, b * 0.98 / word.width);
    canvas.save();
    final pos = at(0.5, 0.95) - Offset(word.width * scale / 2, word.height * scale);
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(scale);
    word.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(MasterGLogoPainter old) =>
      old.background != background || old.glyph != glyph || old.monochrome != monochrome || old.glyphScale != glyphScale || old.fontFamily != fontFamily;
}
