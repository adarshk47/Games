// Renders some shaped Arrow Maze levels (skipped unless asked):
//   flutter test test/tool/arrow_shapes_preview_test.dart --dart-define=ART_PREVIEW=true
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/arrow_maze/logic/arrow_maze_logic.dart';

const _on = bool.fromEnvironment('ART_PREVIEW');

void main() {
  testWidgets('arrow shapes preview', (t) async {
    await t.runAsync(() async {
      final levels = [
        for (final (tier, l) in [(MazeTier.easy, 1), (MazeTier.easy, 2), (MazeTier.easy, 30), (MazeTier.medium, 71),
            (MazeTier.hard, 50), (MazeTier.hard, 81), (MazeTier.extreme, 61), (MazeTier.extreme, 98)])
          ArrowMazeLevels.generate(tier, l)
      ];
      const box = 300.0;
      const w = box * 4, h = box * 2 * 1.4;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));
      c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF1B1530));
      const cols = [Color(0xFFFF4D5E), Color(0xFF3B9BFF), Color(0xFF34D27B), Color(0xFFFFD23F), Color(0xFFA66BFF), Color(0xFFFF8A2A)];
      for (var i = 0; i < levels.length; i++) {
        final b = levels[i];
        final ox = (i % 4) * box, oy = (i ~/ 4) * box * 1.4;
        final cell = ((box - 20) / b.cols) < ((box * 1.4 - 20) / b.rows) ? (box - 20) / b.cols : (box * 1.4 - 20) / b.rows;
        for (var k = 0; k < b.rows * b.cols; k++) {
          if (!b.isInside(k)) continue;
          c.drawRect(Rect.fromLTWH(ox + 10 + (k % b.cols) * cell, oy + 10 + (k ~/ b.cols) * cell, cell, cell),
              Paint()..color = const Color(0x22FFFFFF));
        }
        for (final s in b.snakes) {
          final p = Path();
          for (var j = 0; j < s.cells.length; j++) {
            final x = ox + 10 + (s.cells[j] % b.cols + 0.5) * cell, y = oy + 10 + (s.cells[j] ~/ b.cols + 0.5) * cell;
            j == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
          }
          c.drawPath(p, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.3
            ..strokeCap = StrokeCap.round
            ..color = cols[s.id % cols.length]);
        }
      }
      final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/arrow_shapes_preview.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }, skip: !_on);
}
