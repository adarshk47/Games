// Renders the Master G icon / store PNGs with Flutter itself.
//
// Skipped by default. Regenerate with:
//   flutter test test/tool/render_icons_test.dart --dart-define=RENDER_ICONS=true
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ui/app_logo.dart';

const _render = bool.fromEnvironment('RENDER_ICONS');
const _font = 'MGRoboto';

typedef _Paint = void Function(Canvas canvas, Size size);

Future<void> _write(String path, int w, int h, _Paint paint) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
  paint(canvas, Size(w.toDouble(), h.toDouble()));
  final image = await recorder.endRecording().toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _loadFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? r'D:\flutter'}/bin/cache/artifacts/material_fonts';
  final loader = FontLoader(_font);
  for (final f in ['roboto-black.ttf', 'roboto-medium.ttf']) {
    final file = File('$dir/$f');
    if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

void _featureGraphic(Canvas canvas, Size size) {
  MasterGLogoPainter.paintBackground(canvas, size);
  // Extra faint puzzle pieces on the right.
  for (final (dx, dy, a, rot) in [(0.86, 0.22, 150.0, 0.3), (0.95, 0.85, 110.0, -0.4), (0.62, 0.95, 80.0, 0.6)]) {
    canvas.save();
    canvas.translate(size.width * dx, size.height * dy);
    canvas.rotate(rot);
    canvas.drawPath(MasterGLogoPainter.puzzlePiecePath(a), Paint()..color = Colors.white.withValues(alpha: 0.05));
    canvas.restore();
  }
  // Logo tile.
  const tile = 300.0;
  final tileRect = Rect.fromLTWH(90, (size.height - tile) / 2, tile, tile);
  final rrect = RRect.fromRectAndRadius(tileRect, const Radius.circular(tile * 0.23));
  canvas.drawRRect(
    rrect.shift(const Offset(0, 10)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
  );
  canvas.save();
  canvas.clipRRect(rrect);
  canvas.translate(tileRect.left, tileRect.top);
  const MasterGLogoPainter(fontFamily: _font).paint(canvas, tileRect.size);
  canvas.restore();
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFFFD369).withValues(alpha: 0.5),
  );
  // Wordmark + tagline.
  final word = TextPainter(
    textDirection: TextDirection.ltr,
    text: const TextSpan(
      style: TextStyle(fontFamily: _font, fontSize: 104, fontWeight: FontWeight.w900, color: Color(0xFFF4F1FF), letterSpacing: 1),
      children: [
        TextSpan(text: 'M', style: TextStyle(fontSize: 150, color: Color(0xFFFFD369))),
        TextSpan(text: 'aster', style: TextStyle(fontSize: 76)),
        TextSpan(text: ' G', style: TextStyle(fontSize: 108, color: Color(0xFFFFD369))),
      ],
    ),
  )..layout();
  final tag = TextPainter(
    textDirection: TextDirection.ltr,
    text: const TextSpan(
      text: 'Brain games. Sharp mind.',
      style: TextStyle(fontFamily: _font, fontSize: 40, fontWeight: FontWeight.w500, color: Color(0xFFD9D2FF), letterSpacing: 0.5),
    ),
  )..layout();
  const x = 440.0;
  final total = word.height + 10 + tag.height;
  final y = (size.height - total) / 2;
  word.paint(canvas, Offset(x, y));
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(x + 4, y + word.height - 4, 90, 6), const Radius.circular(3)),
    Paint()..color = const Color(0xFFF5A623),
  );
  tag.paint(canvas, Offset(x, y + word.height + 14));
}

void main() {
  testWidgets('AppLogo paints at small sizes', (tester) async {
    await tester.pumpWidget(const Center(child: AppLogo(size: 48)));
    expect(find.byType(AppLogo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('render icon PNGs', (tester) async {
    await tester.runAsync(() async {
      await _loadFonts();
      const full = MasterGLogoPainter(fontFamily: _font);
      await _write('assets/icon/app_icon.png', 1024, 1024, full.paint);
      await _write('assets/icon/app_icon_background.png', 1024, 1024, (c, s) => MasterGLogoPainter.paintBackground(c, s));
      await _write('assets/icon/app_icon_foreground.png', 1024, 1024,
          const MasterGLogoPainter(background: false, glyphScale: 0.48, fontFamily: _font).paint);
      await _write('assets/icon/app_icon_monochrome.png', 1024, 1024,
          const MasterGLogoPainter(background: false, monochrome: true, glyphScale: 0.48, fontFamily: _font).paint);
      await _write('store_assets/play_icon_512.png', 512, 512, full.paint);
      await _write('store_assets/feature_graphic_1024x500.png', 1024, 500, _featureGraphic);
    });
  }, skip: !_render);
}
