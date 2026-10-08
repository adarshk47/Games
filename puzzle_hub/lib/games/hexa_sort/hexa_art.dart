import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'logic/hexa_sort_logic.dart';

/// Accent colors of the game.
const hsAccent = Color(0xFFF472B6);
const hsAccentHot = Color(0xFFFF8FCB);

/// Tile palette.
const hsColors = <Color>[
  Color(0xFFFF5A6E), // red
  Color(0xFF4D8DFF), // blue
  Color(0xFF3DDC84), // green
  Color(0xFFFFD23F), // yellow
  Color(0xFFB06BFF), // purple
  Color(0xFFFF9A3C), // orange
  Color(0xFF2ED3E6), // cyan
  Color(0xFFFF7BC8), // pink
];

Color hsColor(int i) => hsColors[i % hsColors.length];

const _sqrt3 = 1.7320508075688772;

/// Pixel geometry of a board with hex radius [r] (pointy-top, odd-r layout).
class HsGeometry {
  const HsGeometry(this.board, this.r);
  final HsBoard board;
  final double r;

  /// Extra room above the top row for tall stacks.
  double get headroom => r * 1.1;

  double get width => _sqrt3 * r * board.cols;
  double get height => headroom + r * (1.5 * (board.rows - 1) + 2);

  Offset center(int i) {
    final row = board.row(i), col = board.col(i);
    return Offset(_sqrt3 * r * (col + 0.5 * (row & 1)) + _sqrt3 * r / 2, headroom + r * 1.5 * row + r);
  }

  /// Hex radius that fits [w] x [h].
  static double fit(HsBoard b, double w, double h) =>
      math.min(w / (_sqrt3 * b.cols), h / (1.1 + 1.5 * (b.rows - 1) + 2));

  /// Nearest cell to [p] within one radius, or null.
  int? cellAt(Offset p) {
    int? best;
    var bestD = double.infinity;
    for (final i in board.allCells) {
      final d = (center(i) - p).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return bestD <= r ? best : null;
  }
}

/// Pointy-top hexagon path.
Path hexPath(Offset c, double r, {double squash = 1}) {
  final p = Path();
  for (var k = 0; k < 6; k++) {
    final a = math.pi / 180 * (60 * k - 90);
    final v = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a) * squash);
    k == 0 ? p.moveTo(v.dx, v.dy) : p.lineTo(v.dx, v.dy);
  }
  return p..close();
}

/// Tile thickness for a stack of [n] tiles with board radius [r].
double hsThickness(double r, int n) => math.min(r * 0.2, n <= 1 ? r * 0.2 : r * 2.4 / n);

/// Center of layer [k] (0 = bottom) of a stack based at [base].
Offset hsLayer(Offset base, double r, int k, int n) => base - Offset(0, hsThickness(r, n) * k);

/// Paints one glossy 3D hex tile whose top face is centered at [c].
void paintHexTile(Canvas canvas, Offset c, double r, Color color, double thick, {bool face = true}) {
  final tr = r * 0.88;
  // Body (side wall) below the face.
  final body = hexPath(c + Offset(0, thick), tr, squash: 0.82);
  canvas.drawPath(
    body,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(color, Colors.black, 0.35)!, Color.lerp(color, Colors.black, 0.6)!],
      ).createShader(Rect.fromCircle(center: c + Offset(0, thick), radius: tr)),
  );
  // Side seam.
  canvas.drawPath(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.03)
      ..color = Colors.black.withValues(alpha: 0.25),
  );
  if (!face) return;
  final top = hexPath(c, tr, squash: 0.82);
  final rect = Rect.fromCircle(center: c, radius: tr);
  canvas.drawPath(
    top,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, 0.42)!, color, Color.lerp(color, Colors.black, 0.18)!],
        stops: const [0, 0.55, 1],
      ).createShader(rect),
  );
  // Gloss.
  final gloss = hexPath(c - Offset(tr * 0.12, tr * 0.16), tr * 0.55, squash: 0.6);
  canvas.drawPath(
    gloss,
    Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c - Offset(tr * 0.12, tr * 0.16), radius: tr * 0.6)),
  );
  canvas.drawPath(
    top,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, r * 0.045)
      ..color = Colors.white.withValues(alpha: 0.5),
  );
}

/// Paints a whole stack based (bottom tile face) at [base].
void paintHexStack(Canvas canvas, Offset base, double r, List<int> tiles,
    {bool label = true, double shadow = 1, int? glowColor}) {
  final n = tiles.length;
  if (n == 0) return;
  final t = hsThickness(r, n);
  if (shadow > 0) {
    canvas.drawPath(
      hexPath(base + Offset(r * 0.06, t + r * 0.12), r * 0.9, squash: 0.82),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4 * shadow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.15),
    );
  }
  for (var k = 0; k < n; k++) {
    paintHexTile(canvas, hsLayer(base, r, k, n), r, hsColor(tiles[k]), t, face: k == n - 1 || t >= r * 0.2);
  }
  final topC = hsLayer(base, r, n - 1, n);
  if (glowColor != null) {
    canvas.drawPath(
      hexPath(topC, r * 0.95, squash: 0.82),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..color = hsColor(glowColor).withValues(alpha: 0.8)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );
  }
  if (label) {
    final run = hsTopRun(tiles);
    if (run >= 2) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$run',
          style: TextStyle(
            color: Colors.white,
            fontSize: r * 0.62,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, topC - Offset(tp.width / 2, tp.height / 2));
    }
  }
}

/// Board background: hex slots, stone cells and drop highlights.
class HsBoardPainter extends CustomPainter {
  HsBoardPainter({required this.geo, required this.empty, this.highlight, this.targets = const {}});
  final HsGeometry geo;
  final Set<int> empty;
  final int? highlight;
  final Set<int> targets;

  @override
  void paint(Canvas canvas, Size size) {
    final r = geo.r;
    // Soft plate behind the whole board.
    for (final i in geo.board.allCells) {
      canvas.drawPath(
        hexPath(geo.center(i), r * 1.08),
        Paint()..color = const Color(0xFF120B30).withValues(alpha: 0.55),
      );
    }
    for (final i in geo.board.allCells) {
      final c = geo.center(i);
      if (geo.board.blocked.contains(i)) {
        _stone(canvas, c, r);
        continue;
      }
      final slot = hexPath(c, r * 0.93);
      canvas.drawPath(
        slot,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -0.3),
            colors: [const Color(0xFF3A2C78).withValues(alpha: 0.9), const Color(0xFF1C1444).withValues(alpha: 0.95)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      final isHi = highlight == i;
      final isTarget = targets.contains(i) && empty.contains(i);
      canvas.drawPath(
        slot,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isHi ? r * 0.12 : math.max(1, r * 0.05)
          ..color = isHi
              ? Colors.white
              : isTarget
                  ? hsAccentHot.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.12),
      );
      if (isHi) {
        canvas.drawPath(
          slot,
          Paint()
            ..color = hsAccentHot.withValues(alpha: 0.35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.2),
        );
      }
    }
  }

  void _stone(Canvas canvas, Offset c, double r) {
    final p = hexPath(c, r * 0.93);
    canvas.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B8FA3), Color(0xFF4A4E60), Color(0xFF2E3140)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final crack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * 0.05)
      ..color = Colors.black.withValues(alpha: 0.35);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * 0.45, c.dy - r * 0.2)
        ..lineTo(c.dx - r * 0.1, c.dy + r * 0.05)
        ..lineTo(c.dx + r * 0.05, c.dy - r * 0.3)
        ..moveTo(c.dx - r * 0.1, c.dy + r * 0.05)
        ..lineTo(c.dx + r * 0.3, c.dy + r * 0.4),
      crack,
    );
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.05)
        ..color = Colors.white.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(HsBoardPainter old) =>
      old.geo.r != geo.r || old.highlight != highlight || old.empty.length != empty.length || old.targets != targets;
}

/// One stack (for board cells, offers and the drag ghost). The base is at
/// the bottom-center of the box minus [bottomPad].
class HsStackPainter extends CustomPainter {
  HsStackPainter({required this.tiles, required this.r, this.glow, this.label = true});
  final List<int> tiles;
  final double r;
  final int? glow;
  final bool label;

  @override
  void paint(Canvas canvas, Size size) {
    paintHexStack(canvas, Offset(size.width / 2, size.height - r), r, tiles, label: label, glowColor: glow);
  }

  @override
  bool shouldRepaint(HsStackPainter old) =>
      old.r != r || old.glow != glow || old.tiles.length != tiles.length || !_same(old.tiles, tiles);

  static bool _same(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A single tile (flights).
class HsTilePainter extends CustomPainter {
  HsTilePainter(this.color, this.r);
  final Color color;
  final double r;

  @override
  void paint(Canvas canvas, Size size) => paintHexTile(canvas, size.center(Offset.zero), r, color, r * 0.2);

  @override
  bool shouldRepaint(HsTilePainter old) => old.color != color || old.r != r;
}

/// Clear burst: expanding ring plus hex shards. [t] in 0..1.
class HsBurstPainter extends CustomPainter {
  HsBurstPainter(this.color, this.t, this.r);
  final Color color;
  final double t, r;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final e = Curves.easeOut.transform(t);
    canvas.drawCircle(
      c,
      r * (0.6 + 2.0 * e),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.25 * (1 - e)
        ..color = Colors.white.withValues(alpha: (1 - e) * 0.9),
    );
    canvas.drawCircle(
      c,
      r * (0.4 + 1.2 * e),
      Paint()..color = color.withValues(alpha: (1 - e) * 0.45),
    );
    for (var k = 0; k < 12; k++) {
      final a = k * math.pi / 6 + 0.3;
      final d = r * (0.3 + 2.4 * e) * (k.isEven ? 1 : 0.75);
      final p = c + Offset(math.cos(a) * d, math.sin(a) * d - r * 0.6 * e);
      canvas.drawPath(
        hexPath(p, r * 0.22 * (1 - e * 0.7)),
        Paint()..color = (k % 3 == 0 ? Colors.white : color).withValues(alpha: 1 - e),
      );
    }
  }

  @override
  bool shouldRepaint(HsBurstPainter old) => old.t != t;
}

/// Decorative little stack used on the tier screen.
class HexStackIcon extends StatelessWidget {
  const HexStackIcon({super.key, required this.tiles, this.size = 34});
  final List<int> tiles;
  final double size;

  @override
  Widget build(BuildContext context) {
    final r = size / 2;
    return CustomPaint(
      size: Size(size, size + hsThickness(r, tiles.length) * tiles.length + r * 0.2),
      painter: HsStackPainter(tiles: tiles, r: r, label: false),
    );
  }
}
