import 'package:flutter/material.dart';

import 'ui/app_theme.dart';
import 'ui/palette.dart';

/// App is dark-premium only; every screen draws its own animated background.
/// Colours follow the active [AppThemeController.theme].
ThemeData buildTheme(Brightness _) {
  final t = AppThemeController.theme;
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: t.bg0,
    colorScheme: ColorScheme.fromSeed(seedColor: t.accent, brightness: Brightness.dark),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Pal.text, displayColor: Pal.text),
  );
}
