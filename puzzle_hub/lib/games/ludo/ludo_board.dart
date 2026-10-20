import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'logic/ludo_logic.dart';

const ludoColors = [Color(0xFFE53935), Color(0xFF43A047), Color(0xFFFBC02D), Color(0xFF1E88E5)];
const _yardOrigin = [(0, 0), (0, 9), (9, 9), (9, 0)];

/// The classic 15×15 Ludo board with tokens. Tokens in [movable] (of the
/// player to move) glow and can be tapped.
class LudoBoard extends StatelessWidget {
  const LudoBoard({super.key, required this.game, this.movable = const [], this.onToken});
  final LudoGame game;
  final List<int> movable;
  final void Function(int token)? onToken;

  /// Centre of a token in cell units (row, col).
  static Offset _spot(int colour, int progress, int token) {
    if (progress < 0) {
      final (r0, c0) = _yardOrigin[colour];
      final dr = token < 2 ? 1.75 : 4.25, dc = token.isEven ? 1.75 : 4.25;
      return Offset(c0 + dc, r0 + dr);
    }
    if (progress >= Ludo.home) {
      final spread = (token - 1.5) * 0.32;
      return switch (colour) {
        0 => Offset(6.55, 7.5 + spread),
        1 => Offset(7.5 + spread, 6.55),
        2 => Offset(8.45, 7.5 + spread),
        _ => Offset(7.5 + spread, 8.45),
      };
    }
    final (r, c) = Ludo.cellOf(colour, progress)!;
    return Offset(c + 0.5, r + 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, box) {
        final cell = box.maxWidth / 15;
        // Group tokens by cell so stacked tokens are spread a little.
        final byCell = <String, List<(int seat, int token)>>{};
        for (var s = 0; s < game.seats.length; s++) {
          for (var i = 0; i < 4; i++) {
            final p = game.tokens[s][i];
            if (p < 0 || p >= Ludo.home) continue;
            final o = _spot(game.colourOf(s), p, i);
            byCell.putIfAbsent('${o.dx},${o.dy}', () => []).add((s, i));
          }
        }
        final children = <Widget>[
          Positioned.fill(child: CustomPaint(painter: _BoardPainter(game.seats.map((s) => s.colour).toSet()))),
        ];
        final order = <(int, int)>[];
        for (var s = 0; s < game.seats.length; s++) {
          if (s == game.turn) continue;
          for (var i = 0; i < 4; i++) {
            order.add((s, i));
          }
        }
        for (var i = 0; i < 4; i++) {
          order.add((game.turn, i)); // player to move on top
        }
        for (final (s, i) in order) {
          final colour = game.colourOf(s);
          final p = game.tokens[s][i];
          var o = _spot(colour, p, i);
          var size = cell * 0.82;
          if (p >= 0 && p < Ludo.home) {
            final group = byCell['${o.dx},${o.dy}']!;
            if (group.length > 1) {
              final k = group.indexOf((s, i));
              final a = 2 * math.pi * k / group.length;
              o += Offset(math.cos(a), math.sin(a)) * 0.2;
              size = cell * 0.62;
            }
          } else if (p >= Ludo.home) {
            size = cell * 0.5;
          }
          final canMove = s == game.turn && movable.contains(i);
          children.add(AnimatedPositioned(
            key: ValueKey('token_${s}_$i'),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            left: o.dx * cell - size / 2,
            top: o.dy * cell - size / 2,
            width: size,
            height: size,
            child: GestureDetector(
              key: ValueKey('tap_token_${s}_$i'),
              behavior: HitTestBehavior.opaque,
              onTap: canMove ? () => onToken?.call(i) : null,
              child: LudoToken(color: ludoColors[colour], glow: canMove),
            ),
          ));
        }
        return Stack(clipBehavior: Clip.none, children: children);
      }),
    );
  }
}

/// A glossy round pawn top.
class LudoToken extends StatefulWidget {
  const LudoToken({super.key, required this.color, this.glow = false});
  final Color color;
  final bool glow;

  @override
  State<LudoToken> createState() => _LudoTokenState();
}

class _LudoTokenState extends State<LudoToken> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    if (widget.glow) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(LudoToken old) {
    super.didUpdateWidget(old);
    if (widget.glow && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.glow && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Transform.scale(
          scale: 1 + t * 0.12,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.4),
                colors: [Color.lerp(c, Colors.white, 0.55)!, c, Color.lerp(c, Colors.black, 0.35)!],
                stops: const [0, 0.55, 1],
              ),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 4, offset: const Offset(0, 2)),
                if (widget.glow) BoxShadow(color: Colors.white.withValues(alpha: 0.5 + t * 0.4), blurRadius: 6 + t * 8, spreadRadius: 1 + t * 2),
              ],
            ),
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.38,
                heightFactor: 0.38,
                child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.85))),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.colours);
  final Set<int> colours;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;
    Rect r(int row, int col, [int h = 1, int w = 1]) => Rect.fromLTWH(col * cell, row * cell, w * cell, h * cell);
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * 0.6));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFF8E7));

    // Yards.
    for (var c = 0; c < 4; c++) {
      final (r0, c0) = _yardOrigin[c];
      final col = ludoColors[c];
      final yard = r(r0, c0, 6, 6);
      canvas.drawRect(
        yard,
        Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(col, Colors.white, 0.15)!, Color.lerp(col, Colors.black, 0.15)!]).createShader(yard),
      );
      final inner = RRect.fromRectAndRadius(yard.deflate(cell * 0.8), Radius.circular(cell * 0.6));
      canvas.drawRRect(inner, Paint()..color = colours.contains(c) ? Colors.white : Colors.white.withValues(alpha: 0.55));
      for (final (dr, dc) in const [(1.75, 1.75), (1.75, 4.25), (4.25, 1.75), (4.25, 4.25)]) {
        final o = Offset((c0 + dc) * cell, (r0 + dr) * cell);
        canvas.drawCircle(o, cell * 0.55, Paint()..color = col.withValues(alpha: 0.85));
        canvas.drawCircle(o, cell * 0.42, Paint()..color = Color.lerp(col, Colors.white, 0.35)!);
      }
    }

    // Track and home columns.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF9E8C6A);
    for (var i = 0; i < Ludo.trackLen; i++) {
      final (row, col) = Ludo.track[i];
      final rect = r(row, col);
      Color fill = Colors.white;
      for (var c = 0; c < 4; c++) {
        if (i == Ludo.startOf(c)) fill = ludoColors[c];
      }
      canvas.drawRect(rect, Paint()..color = fill);
      canvas.drawRect(rect, line);
      if (Ludo.safe.contains(i) && fill == Colors.white) _star(canvas, rect.center, cell * 0.36, const Color(0xFFB0A080));
      if (fill != Colors.white) _arrowDot(canvas, rect.center, cell);
    }
    for (var c = 0; c < 4; c++) {
      for (var p = 51; p <= 55; p++) {
        final (row, col) = Ludo.homeCell(c, p);
        final rect = r(row, col);
        canvas.drawRect(rect, Paint()..color = ludoColors[c]);
        canvas.drawRect(rect, line);
      }
    }

    // Centre triangles (each colour's home).
    final cx = 7.5 * cell, cy = 7.5 * cell;
    final a = Offset(6 * cell, 6 * cell), b = Offset(9 * cell, 6 * cell), cc = Offset(9 * cell, 9 * cell), d = Offset(6 * cell, 9 * cell);
    final centre = Offset(cx, cy);
    final tris = [
      [a, d], // red, left
      [a, b], // green, top
      [b, cc], // yellow, right
      [cc, d], // blue, bottom
    ];
    for (var c = 0; c < 4; c++) {
      final p = Path()
        ..moveTo(tris[c][0].dx, tris[c][0].dy)
        ..lineTo(tris[c][1].dx, tris[c][1].dy)
        ..lineTo(centre.dx, centre.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = ludoColors[c]);
      canvas.drawPath(p, line);
    }
    _star(canvas, centre, cell * 0.55, Colors.white.withValues(alpha: 0.85));
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.18
        ..color = const Color(0xFF7A5230),
    );
  }

  void _arrowDot(Canvas canvas, Offset c, double cell) => canvas.drawCircle(c, cell * 0.12, Paint()..color = Colors.white.withValues(alpha: 0.9));

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BoardPainter o) => o.colours.length != colours.length;
}

/// Dice face with pips; [rolling] shows a spin.
class LudoDice extends StatelessWidget {
  const LudoDice({super.key, required this.value, required this.color, this.enabled = false, this.onTap, this.rollSeq = 0, this.size = 64});
  final int? value;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;
  final int rollSeq;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(rollSeq),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => Transform.rotate(
          angle: rollSeq == 0 ? 0 : (1 - t) * math.pi * 2,
          child: Transform.scale(
            scale: enabled ? 1.0 + 0.06 * math.sin(t * math.pi) : 0.92,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(size * 0.22),
                border: Border.all(color: color, width: enabled ? 4 : 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
                  if (enabled) BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 16),
                ],
              ),
              child: CustomPaint(painter: _PipPainter(value ?? 0, Color.lerp(color, Colors.black, 0.35)!)),
            ),
          ),
        ),
      ),
    );
  }
}

class _PipPainter extends CustomPainter {
  _PipPainter(this.v, this.color);
  final int v;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (v == 0) {
      final tp = TextPainter(
        text: TextSpan(text: '🎲', style: TextStyle(fontSize: size.width * 0.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, size.center(Offset(-tp.width / 2, -tp.height / 2)));
      return;
    }
    const pos = {
      1: [(1, 1)],
      2: [(0, 0), (2, 2)],
      3: [(0, 0), (1, 1), (2, 2)],
      4: [(0, 0), (0, 2), (2, 0), (2, 2)],
      5: [(0, 0), (0, 2), (1, 1), (2, 0), (2, 2)],
      6: [(0, 0), (0, 2), (1, 0), (1, 2), (2, 0), (2, 2)],
    };
    final s = size.width;
    for (final (r, c) in pos[v]!) {
      canvas.drawCircle(Offset(s * (0.25 + c * 0.25), s * (0.25 + r * 0.25)), s * 0.085, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_PipPainter o) => o.v != v || o.color != color;
}
