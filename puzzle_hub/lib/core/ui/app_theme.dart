import 'package:flutter/foundation.dart';

/// Selectable app colour themes (filled in by the theme work).
class AppThemeController {
  AppThemeController._();

  static final ValueNotifier<int> current = ValueNotifier<int>(0);

  static Future<void> init() async {}
}
