import 'package:flutter/material.dart';

import 'logic/tile_match_logic.dart';

/// Game accent colors.
const tmAccent = Color(0xFF34D399);
const tmAccentHot = Color(0xFF10B981);

/// Tile icons: emoji + a matching tint used for the badge behind it, so
/// identical tiles are recognisable even at a glance.
const List<(String, Color)> kTmIcons = [
  ('🍎', Color(0xFFEF4444)),
  ('🍊', Color(0xFFF97316)),
  ('🍋', Color(0xFFEAB308)),
  ('🍇', Color(0xFF8B5CF6)),
  ('🍓', Color(0xFFE11D48)),
  ('🍒', Color(0xFFBE123C)),
  ('🍑', Color(0xFFFB923C)),
  ('🥝', Color(0xFF65A30D)),
  ('🍍', Color(0xFFCA8A04)),
  ('🥥', Color(0xFF92400E)),
  ('🍉', Color(0xFF16A34A)),
  ('🍌', Color(0xFFFACC15)),
  ('🥕', Color(0xFFEA580C)),
  ('🌽', Color(0xFFD97706)),
  ('🍄', Color(0xFFDC2626)),
  ('🌸', Color(0xFFEC4899)),
  ('🌻', Color(0xFFF59E0B)),
  ('🍀', Color(0xFF22C55E)),
  ('🐱', Color(0xFFF472B6)),
  ('🐶', Color(0xFFA16207)),
  ('🐸', Color(0xFF4ADE80)),
  ('🐼', Color(0xFF64748B)),
  ('🦊', Color(0xFFF97316)),
  ('🐝', Color(0xFFFBBF24)),
];

(String, Color) tmIcon(int i) => kTmIcons[i % kTmIcons.length];

/// Ratio of a tile's visible side (thickness) to its face size.
const kTmDepth = 0.13;

/// Glossy 3D mahjong-style tile. The widget is [size] wide and
/// `size * (1 + kTmDepth)` tall: the face on top, the side below.
class TileView extends StatelessWidget {
  const TileView({super.key, required this.icon, required this.size, this.covered = false, this.glow});
  final int icon;
  final double size;
  final bool covered;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final (emoji, tint) = tmIcon(icon);
    final r = BorderRadius.circular(size * 0.2);
    final depth = size * kTmDepth;
    return SizedBox(
      width: size,
      height: size + depth,
      child: Stack(children: [
        // Side / thickness with drop shadow.
        Positioned(
          left: 0,
          right: 0,
          top: depth,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFC9B48E), Color(0xFF8C7652)],
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: size * 0.14, offset: Offset(size * 0.04, size * 0.08)),
                if (glow != null) BoxShadow(color: glow!.withValues(alpha: 0.8), blurRadius: size * 0.3, spreadRadius: 1),
              ],
            ),
          ),
        ),
        // Face.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFEF8), Color(0xFFF6EDD9), Color(0xFFE9DCC0)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: size * 0.025),
            ),
            child: Padding(
              padding: EdgeInsets.all(size * 0.1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [tint.withValues(alpha: 0.30), tint.withValues(alpha: 0.10)],
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(emoji, style: TextStyle(fontSize: size * 0.52, height: 1.1)),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Gloss highlight on the upper half of the face.
        Positioned(
          left: size * 0.06,
          right: size * 0.06,
          top: size * 0.04,
          height: size * 0.42,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(size * 0.17), bottom: Radius.circular(size * 0.3)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.65), Colors.white.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
        ),
        if (covered)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(borderRadius: r, color: const Color(0xFF0B0820).withValues(alpha: 0.55)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Board metrics for one level at a given unit size. The board box is the
/// bounding box of the tiles (plus room for the 3D layer offsets).
class TmBoardMetrics {
  TmBoardMetrics(this.level, this.unit) : bounds = boundsOf(level);
  final TmLevel level;
  final double unit;

  /// (minX, minY, spanX, spanY) in units.
  final (int, int, int, int) bounds;

  static (int, int, int, int) boundsOf(TmLevel level) {
    if (level.tiles.isEmpty) return (0, 0, 2, 2);
    var x0 = 1 << 30, y0 = 1 << 30, x1 = 0, y1 = 0;
    for (final t in level.tiles) {
      if (t.x < x0) x0 = t.x;
      if (t.y < y0) y0 = t.y;
      if (t.x + 2 > x1) x1 = t.x + 2;
      if (t.y + 2 > y1) y1 = t.y + 2;
    }
    return (x0, y0, x1 - x0, y1 - y0);
  }

  double get gap => unit * 0.08;
  double get tileSize => unit * 2 - gap;
  double get lift => unit * 0.2;
  double get depth => tileSize * kTmDepth;
  double get width => bounds.$3 * unit + (level.layers - 1) * lift;
  double get height => bounds.$4 * unit + depth + (level.layers - 1) * lift;

  /// Top-left of a tile's face inside the board box.
  Offset origin(TmTile t) {
    final shift = (level.layers - 1 - t.z) * lift;
    return Offset((t.x - bounds.$1) * unit + shift + gap / 2, (t.y - bounds.$2) * unit + shift + gap / 2);
  }

  static double unitFor(TmLevel level, Size avail) {
    final b = boundsOf(level);
    final extra = (level.layers - 1) * 0.2;
    final uw = avail.width / (b.$3 + extra);
    final uh = avail.height / (b.$4 + extra + 2 * kTmDepth);
    return uw < uh ? uw : uh;
  }
}
