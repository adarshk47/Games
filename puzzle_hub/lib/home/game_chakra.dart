import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/game_info.dart';
import '../core/i18n/i18n.dart';
import '../core/ui/festive/festive_painters.dart';
import '../core/ui/festive/festive_palette.dart';

/// Games arranged on rings around a lit diya, like a chakra. Drag anywhere on
/// it to turn the wheel; tap a medallion to play, tap the diya for the game of
/// the day. Games that do not fit on the rings are returned by [overflowOf]
/// so the caller can list them below.
class GameChakra extends StatefulWidget {
  const GameChakra({
    super.key,
    required this.list,
    required this.onOpen,
    required this.gameOfDay,
    required this.size,
  });

  final List<GameInfo> list;
  final ValueChanged<GameInfo> onOpen;
  final GameInfo gameOfDay;

  /// Side of the square wheel.
  final double size;

  @override
  State<GameChakra> createState() => _GameChakraState();

  /// Largest medallion diameter (72 down to 40) at which [count] games fit
  /// on the rings of a wheel of side [size].
  static double itemSize(double size, [int count = 0]) {
    final start = (size * 0.17).clamp(48.0, 72.0);
    for (var d = start; d >= 40; d -= 2) {
      final caps = radii(size, d).map((r) => capacity(r, d));
      if (caps.fold<int>(0, (a, b) => a + b) >= count) return d;
    }
    return 40;
  }

  static double _labelGap(double d) => d * 0.62;

  /// Radii of the rings for medallions of size [d], outer first. An inner
  /// ring is added while it stays clear of the diya in the centre.
  static List<double> radii(double size, [double? d]) {
    final m = d ?? itemSize(size);
    final outer = size / 2 - _labelGap(m);
    final rings = <double>[outer];
    final hubR = size * 0.13;
    var r = outer - m * 1.35;
    while (r - m / 2 >= hubR + 2) {
      rings.add(r);
      r -= m * 1.35;
    }
    return rings;
  }

  static int capacity(double radius, double d) =>
      (2 * math.pi * radius / (d * 1.18)).floor();

  /// How many games go on each ring (outer first); the sum may be less than
  /// [count] when even the smallest medallions do not fit.
  static List<int> split(int count, double size) {
    final d = itemSize(size, count);
    final rs = radii(size, d);
    final caps = [for (final r in rs) capacity(r, d)];
    final out = List<int>.filled(rs.length, 0);
    var left = count;
    // Fill inner rings with a balanced share, the outer ring takes the rest.
    final total = caps.fold<int>(0, (a, b) => a + b);
    for (var i = rs.length - 1; i >= 1 && left > 0; i--) {
      final share = (count * caps[i] / total).floor();
      out[i] = math.min(caps[i], math.min(share, left));
      left -= out[i];
    }
    out[0] = math.min(caps[0], left);
    left -= out[0];
    for (var i = 1; i < rs.length && left > 0; i++) {
      final more = math.min(caps[i] - out[i], left);
      out[i] += more;
      left -= more;
    }
    return out;
  }

  /// Games that do not fit on the wheel.
  static List<GameInfo> overflowOf(List<GameInfo> list, double size) {
    final placed = split(list.length, size).fold<int>(0, (a, b) => a + b);
    return list.sublist(placed);
  }
}

class _GameChakraState extends State<GameChakra> {
  double _angle = 0;
  Offset? _last;

  Offset get _center => Offset(widget.size / 2, widget.size / 2);

  void _onPanStart(DragStartDetails d) => _last = d.localPosition;

  void _onPanUpdate(DragUpdateDetails d) {
    final last = _last;
    _last = d.localPosition;
    if (last == null) return;
    final a0 = (last - _center).direction;
    final a1 = (d.localPosition - _center).direction;
    var delta = a1 - a0;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    setState(() => _angle += delta);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final d = GameChakra.itemSize(size, widget.list.length);
    final rs = GameChakra.radii(size, d);
    final counts = GameChakra.split(widget.list.length, size);
    final hub = size * 0.26;

    final items = <Widget>[];
    var gi = 0;
    for (var ring = 0; ring < rs.length; ring++) {
      final n = counts[ring];
      // Alternate rings turn in opposite directions, like a spinning chakra.
      final spin = ring.isEven ? _angle : -_angle * 0.8;
      final offset = ring.isEven ? 0.0 : math.pi / math.max(n, 1);
      for (var k = 0; k < n; k++) {
        final g = widget.list[gi++];
        final th = -math.pi / 2 + 2 * math.pi * k / n + spin + offset;
        final p = _center + Offset(math.cos(th), math.sin(th)) * rs[ring];
        final w = d * 1.5;
        items.add(
          Positioned(
            left: p.dx - w / 2,
            top: p.dy - d / 2,
            width: w,
            child: _Medallion(
              key: ValueKey('game_${g.id}'),
              g: g,
              d: d,
              onTap: () => widget.onOpen(g),
            ),
          ),
        );
      }
    }

    return GestureDetector(
      key: const ValueKey('game_chakra'),
      behavior: HitTestBehavior.translucent,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: (_) => _last = null,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ChakraPainter(
                    angle: _angle,
                    radii: rs,
                    hub: hub / 2,
                  ),
                ),
              ),
            ),
            Positioned(
              left: (size - hub) / 2,
              top: (size - hub) / 2,
              width: hub,
              height: hub,
              child: _Hub(
                g: widget.gameOfDay,
                onTap: () => widget.onOpen(widget.gameOfDay),
              ),
            ),
            ...items,
          ],
        ),
      ),
    );
  }
}

/// Centre: a big lit diya; tap opens the game of the day.
class _Hub extends StatelessWidget {
  const _Hub({required this.g, required this.onTap});
  final GameInfo g;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${tr('home.game_of_the_day')}: ${g.title}',
      child: GestureDetector(
        key: const ValueKey('chakra_hub'),
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, c) {
            final s = c.maxWidth;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: s * 0.5,
                  height: s * 0.5,
                  child: const CustomPaint(painter: DiyaPainter()),
                ),
                const SizedBox(height: 2),
                Text(g.emoji ?? '🎮', style: TextStyle(fontSize: s * 0.16)),
                SizedBox(
                  width: s * 0.9,
                  child: Text(
                    g.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Festive.zariLight,
                      fontSize: (s * 0.1).clamp(9.0, 13.0),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One game on the wheel: round medallion with a zari rim and its name.
class _Medallion extends StatelessWidget {
  const _Medallion({
    super.key,
    required this.g,
    required this.d,
    required this.onTap,
  });
  final GameInfo g;
  final double d;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: g.title,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: d,
              height: d,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color.lerp(g.color, Colors.white, 0.25)!,
                    Color.lerp(g.color, Festive.sindoor, 0.45)!,
                  ],
                ),
                border: Border.all(color: Festive.zari, width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: Festive.marigold.withValues(alpha: 0.45),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: g.emoji != null
                  ? Text(g.emoji!, style: TextStyle(fontSize: d * 0.46))
                  : Icon(g.icon, color: Colors.white, size: d * 0.5),
            ),
            const SizedBox(height: 3),
            Text(
              g.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: (d * 0.17).clamp(9.0, 12.0),
                fontWeight: FontWeight.w800,
                shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rangoli wheel behind the games: glowing rings with marigold dots, 24
/// chakra spokes and petals around the hub. Turns with [angle].
class ChakraPainter extends CustomPainter {
  const ChakraPainter({
    required this.angle,
    required this.radii,
    required this.hub,
  });
  final double angle;
  final List<double> radii;
  final double hub;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final outer = s.width / 2;

    // Soft glow disc.
    canvas.drawCircle(
      c,
      outer,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Festive.marigold.withValues(alpha: 0.28),
            Festive.sindoor.withValues(alpha: 0.18),
            Colors.transparent,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: outer)),
    );

    // 24 spokes (Ashoka-chakra style) from the hub to the outer ring.
    final spoke = Paint()
      ..color = Festive.zari.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    final reach = radii.isEmpty ? outer : radii.first;
    for (var i = 0; i < 24; i++) {
      final th = angle * 0.5 + i * math.pi / 12;
      final dir = Offset(math.cos(th), math.sin(th));
      canvas.drawLine(c + dir * hub, c + dir * reach, spoke);
    }

    // Rings with alternating rangoli dots.
    for (var r = 0; r < radii.length; r++) {
      final rad = radii[r];
      canvas.drawCircle(
        c,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Festive.zari.withValues(alpha: 0.7),
      );
      final dots = (2 * math.pi * rad / 14).floor();
      final spin = r.isEven ? angle : -angle * 0.8;
      for (var k = 0; k < dots; k++) {
        final th = spin + 2 * math.pi * k / dots;
        canvas.drawCircle(
          c + Offset(math.cos(th), math.sin(th)) * rad,
          2.2,
          Paint()..color = Festive.rangoli[k % Festive.rangoli.length],
        );
      }
    }

    // Lotus petals around the hub.
    final petal = Paint()..color = Festive.kumkum.withValues(alpha: 0.75);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Festive.zariLight.withValues(alpha: 0.8);
    for (var i = 0; i < 12; i++) {
      final th = -angle * 0.3 + i * math.pi / 6;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(th);
      final path = Path()
        ..moveTo(hub * 0.95, 0)
        ..quadraticBezierTo(hub * 1.2, -hub * 0.16, hub * 1.42, 0)
        ..quadraticBezierTo(hub * 1.2, hub * 0.16, hub * 0.95, 0);
      canvas.drawPath(path, petal);
      canvas.drawPath(path, rim);
      canvas.restore();
    }
    canvas.drawCircle(
      c,
      hub,
      Paint()
        ..shader = RadialGradient(
          colors: [Festive.sindoor, Festive.sindoor.withValues(alpha: 0.6)],
        ).createShader(Rect.fromCircle(center: c, radius: hub)),
    );
    canvas.drawCircle(
      c,
      hub,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Festive.zari,
    );
  }

  @override
  bool shouldRepaint(ChakraPainter o) =>
      o.angle != angle || o.hub != hub || o.radii.length != radii.length;
}

/// Small preview of the chakra layout for the settings selector.
class ChakraPreviewPainter extends CustomPainter {
  const ChakraPreviewPainter({required this.bg0, required this.bg1});
  final Color bg0, bg1;

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(colors: [bg1, bg0]).createShader(rect),
    );
    final c = s.center(Offset.zero);
    final r = math.min(s.width, s.height) * 0.42;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Festive.zari,
    );
    for (var i = 0; i < 10; i++) {
      final th = -math.pi / 2 + i * math.pi / 5;
      canvas.drawCircle(
        c + Offset(math.cos(th), math.sin(th)) * r,
        r * 0.17,
        Paint()..color = Festive.rangoli[i % Festive.rangoli.length],
      );
    }
    canvas.drawCircle(c, r * 0.32, Paint()..color = Festive.sindoor);
    canvas.drawCircle(
      c.translate(0, -r * 0.05),
      r * 0.12,
      Paint()..color = Festive.flame,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(ChakraPreviewPainter o) => o.bg0 != bg0 || o.bg1 != bg1;
}
