// Renders previews of the new icon concepts (skipped unless asked):
//   flutter test test/tool/icon_preview_test.dart --dart-define=ICON_PREVIEW=true
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ui/app_icon_designs.dart';

const _on = bool.fromEnvironment('ICON_PREVIEW');

void main() {
  testWidgets('icon concept previews', (t) async {
    await t.runAsync(() async {
      final dir = '${Platform.environment['FLUTTER_ROOT'] ?? r'D:\flutter'}/bin/cache/artifacts/material_fonts';
      final loader = FontLoader('MGRoboto');
      for (final f in ['roboto-black.ttf']) {
        final file = File('$dir/$f');
        if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      }
      await loader.load();
      // 3 concepts side by side, each as a rounded app icon, plus small sizes.
      const big = 420.0, gap = 40.0;
      final w = 3 * big + 4 * gap, h = big + 180 + 2 * gap;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
      c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFEDEBF5));
      for (var v = 0; v < 3; v++) {
        final x = gap + v * (big + gap);
        for (final (size, dx, dy) in [(big, 0.0, gap), (96.0, 60.0, big + gap + 50), (48.0, 220.0, big + gap + 74)]) {
          final r = RRect.fromRectAndRadius(Rect.fromLTWH(x + dx, dy, size, size), Radius.circular(size * 0.22));
          c.save();
          c.clipRRect(r);
          c.translate(x + dx, dy);
          AppIconDesign(v).paint(c, Size(size, size));
          c.restore();
        }
        final tp = TextPainter(
          text: TextSpan(text: 'ABC'[v], style: const TextStyle(fontFamily: 'MGRoboto', fontSize: 48, color: Color(0xFF333333))),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, Offset(x + 320, big + gap + 60));
      }
      final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/icon_concepts.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }, skip: !_on);
}
