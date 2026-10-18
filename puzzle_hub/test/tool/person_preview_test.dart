// Renders the Bus Jam passenger styles (skipped unless asked):
//   flutter test test/tool/person_preview_test.dart --dart-define=ART_PREVIEW=true
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/bus_jam/bus_art.dart';

const _on = bool.fromEnvironment('ART_PREVIEW');

void main() {
  testWidgets('bus jam person preview', (t) async {
    await t.runAsync(() async {
      const cell = 110.0;
      const w = cell * 8, h = cell * 3;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));
      c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF3A4A5C));
      for (var r = 0; r < 3; r++) {
        for (var i = 0; i < 8; i++) {
          c.save();
          c.translate(i * cell + 5, r * cell + 5);
          PersonPainter(color: bjColor(i), seed: i + r * 8, walking: r == 1, phase: i * 0.7, dim: r == 2 && i.isEven, facing: r == 1 ? 1.2 : 0)
              .paint(c, const Size(cell - 10, cell - 10));
          c.restore();
        }
      }
      final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/person_preview.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }, skip: !_on);
}
