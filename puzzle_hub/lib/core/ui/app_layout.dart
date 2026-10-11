import 'package:flutter/foundation.dart';

import '../i18n/i18n.dart';
import '../storage.dart';

/// Home screen layouts the player can pick in Settings.
enum AppLayout {
  /// The original dark premium glass layout.
  classic,

  /// Indian-festival look: toran header, saree-border cards, thali banner.
  festive;

  /// Localised label (keys `home.layout.<name>`).
  String get label => tr('home.layout.$name');
}

/// Global (not per-user) home layout choice, stored under `set.layout`.
/// [current] is a [ValueNotifier] so the games tab and settings rebuild on change.
class AppLayoutController {
  AppLayoutController._();

  static const kLayout = 'set.layout';

  static final ValueNotifier<AppLayout> current = ValueNotifier<AppLayout>(AppLayout.classic);

  static AppLayout get layout => current.value;
  static bool get festive => current.value == AppLayout.festive;

  /// Loads the saved layout (called from [AppThemeController.init]).
  static Future<void> init() async {
    final s = Storage.globalString(kLayout);
    current.value = AppLayout.values.firstWhere((l) => l.name == s, orElse: () => AppLayout.classic);
  }

  static Future<void> select(AppLayout l) async {
    current.value = l;
    await Storage.setGlobalString(kLayout, l.name);
  }
}
