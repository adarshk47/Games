import 'package:flutter/material.dart';

import 'ui/palette.dart';

/// App is dark-premium only; every screen draws its own animated background.
ThemeData buildTheme(Brightness _) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Pal.bg0,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C5CFF), brightness: Brightness.dark),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Pal.text, displayColor: Pal.text),
  );
}
