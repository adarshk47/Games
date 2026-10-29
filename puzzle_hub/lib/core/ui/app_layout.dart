import 'package:flutter/foundation.dart';

import '../release_stage.dart';
import '../i18n/i18n.dart';
import '../storage.dart';

/// Home screen layouts the player can pick in Settings.
enum AppLayout {
  /// Big cards for new games, then a shelf per category (default).
  arcade,

  /// The original dark premium glass layout.
  classic,

  /// Indian-festival look: toran header, saree-border cards, thali banner.
  festive,

  /// Festive look with every game on rings around a lit diya.
  chakra,

  /// Category tabs + every game on one screen in big / small tiles (goes
  /// with the new themes; 2.7.0+).
  bento,

  /// One big swipeable game card with a Play button (2.7.0+).
  spotlight,

  /// Personal list: each game with your progress, most played first (2.7.0+).
  journey;

  /// Layouts added in 2.7.0 ("Coming soon" in earlier releases).
  bool get isNew => index >= AppLayout.bento.index;
  bool get available => !isNew || kStage >= kNewLayoutsStage;

  /// Localised label (keys `home.layout.<name>`).
  String get label => tr('home.layout.$name');
}

/// Global (not per-user) home layout choice, stored under `set.layout`.
/// [current] is a [ValueNotifier] so the games tab and settings rebuild on change.
class AppLayoutController {
  AppLayoutController._();

  static const kLayout = 'set.layout';

  static final ValueNotifier<AppLayout> current = ValueNotifier<AppLayout>(
    AppLayout.arcade,
  );

  /// Set once the new Arcade layout has been made the default (2.1).
  static const _kArcadeMigrated = 'set.layout.arcade';

  static AppLayout get layout => current.value;
  static bool get festive => current.value == AppLayout.festive || current.value == AppLayout.chakra;

  /// Loads the saved layout (called from [AppThemeController.init]).
  static Future<void> init() async {
    // Move to the new Arcade home once; Settings can switch back.
    // (Only players still on the old default chakra; a layout picked on
    // purpose in Settings is kept.)
    if (!Storage.globalBool(_kArcadeMigrated)) {
      await Storage.setGlobalBool(_kArcadeMigrated, true);
      final old = Storage.globalString(kLayout);
      if (old == null || old == AppLayout.chakra.name) {
        await Storage.setGlobalString(kLayout, AppLayout.arcade.name);
      }
    }
    final s = Storage.globalString(kLayout);
    final l = AppLayout.values.firstWhere(
      (l) => l.name == s,
      orElse: () => AppLayout.arcade,
    );
    current.value = l.available ? l : AppLayout.arcade;
  }

  static Future<void> select(AppLayout l) async {
    if (!l.available) l = AppLayout.arcade;
    current.value = l;
    await Storage.setGlobalString(kLayout, l.name);
  }
}
