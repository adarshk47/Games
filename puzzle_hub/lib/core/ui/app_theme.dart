import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../rewards.dart';
import '../storage.dart';

/// One selectable colour theme. Drives the animated background, Material theme,
/// home screen and bottom navigation. Game screens keep using the const [Pal]
/// colours for text/surfaces, which read well on every theme.
@immutable
class AppThemeData {
  const AppThemeData({
    required this.id,
    required String name,
    required this.bg0,
    required this.bg1,
    required this.orb,
    required this.orb2,
    required this.accent,
    required this.highlight,
    this.price = 0,
  // Private fields cannot be named initializing formals.
  // ignore: prefer_initializing_formals
  }) : _name = name;

  final String id;
  final String _name;

  /// Localised theme name (key `home.theme.<id>`), falling back to the given name.
  String get name => tr('home.theme.$id', const {}, _name);

  /// Background gradient (dark edge / lighter middle).
  final Color bg0;
  final Color bg1;

  /// Main glow-orb tint and the secondary orb tint.
  final Color orb;
  final Color orb2;

  /// Primary accent (selected nav pill, buttons) and gold-ish highlight.
  final Color accent;
  final Color highlight;

  /// Coins needed to unlock; 0 = free.
  final int price;

  bool get free => price == 0;

  LinearGradient get swatch => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [bg1, orb, accent],
      );

  LinearGradient get wordmark => LinearGradient(colors: [highlight, orb2, accent]);
}

enum ThemeBuyResult { bought, alreadyOwned, notEnoughCoins }

/// Selectable app colour themes. [current] is the active index (global, key
/// `set.theme`); unlocked themes are stored per user (`theme.unlocked`).
class AppThemeController {
  AppThemeController._();

  static const _kTheme = 'set.theme';
  static const _kUnlocked = 'theme.unlocked';

  static const List<AppThemeData> themes = [
    AppThemeData(
      id: 'royal',
      name: 'Royal Purple',
      bg0: Color(0xFF0B0820),
      bg1: Color(0xFF1B1245),
      orb: Color(0xFF2D1B69),
      orb2: Color(0xFFFF6FB5),
      accent: Color(0xFF7C5CFF),
      highlight: Color(0xFFFFD369),
    ),
    AppThemeData(
      id: 'ocean',
      name: 'Ocean Blue',
      bg0: Color(0xFF04121F),
      bg1: Color(0xFF0A2A4A),
      orb: Color(0xFF1565C0),
      orb2: Color(0xFF2EE6A8),
      accent: Color(0xFF3FA9F5),
      highlight: Color(0xFF7FF3FF),
    ),
    AppThemeData(
      id: 'sunset',
      name: 'Sunset Orange',
      bg0: Color(0xFF1A0A0A),
      bg1: Color(0xFF3D1A12),
      orb: Color(0xFFB4442A),
      orb2: Color(0xFFFF5E8A),
      accent: Color(0xFFFF7A45),
      highlight: Color(0xFFFFD369),
      price: 300,
    ),
    AppThemeData(
      id: 'emerald',
      name: 'Emerald',
      bg0: Color(0xFF03140F),
      bg1: Color(0xFF0B3326),
      orb: Color(0xFF13795B),
      orb2: Color(0xFF4DA8FF),
      accent: Color(0xFF2EE6A8),
      highlight: Color(0xFFD4FF7A),
      price: 450,
    ),
    AppThemeData(
      id: 'rose',
      name: 'Rose Pink',
      bg0: Color(0xFF1A0714),
      bg1: Color(0xFF3D1033),
      orb: Color(0xFFA1286E),
      orb2: Color(0xFFB794FF),
      accent: Color(0xFFFF6FB5),
      highlight: Color(0xFFFFC2E2),
      price: 600,
    ),
    AppThemeData(
      id: 'midnight',
      name: 'Midnight Gold',
      bg0: Color(0xFF050505),
      bg1: Color(0xFF17140C),
      orb: Color(0xFF3A2E10),
      orb2: Color(0xFF8A6B1F),
      accent: Color(0xFFD4AF37),
      highlight: Color(0xFFFFD369),
      price: 800,
    ),
  ];

  static final ValueNotifier<int> current = ValueNotifier<int>(0);

  /// Bumped whenever the unlocked set changes (so pickers can refresh).
  static final ValueNotifier<int> unlocks = ValueNotifier<int>(0);

  /// The active theme.
  static AppThemeData get theme => themes[current.value.clamp(0, themes.length - 1)];

  static Future<void> init() async {
    final i = int.tryParse(Storage.globalString(_kTheme) ?? '') ?? 0;
    current.value = (i >= 0 && i < themes.length) ? i : 0;
  }

  static Set<String> get _unlockedIds =>
      (Storage.getString(_kUnlocked) ?? '').split(',').where((s) => s.isNotEmpty).toSet();

  static bool isUnlocked(int i) => themes[i].free || _unlockedIds.contains(themes[i].id);

  /// Applies theme [i] if it is unlocked. Returns false when locked.
  static Future<bool> select(int i) async {
    if (i < 0 || i >= themes.length || !isUnlocked(i)) return false;
    current.value = i;
    await Storage.setGlobalString(_kTheme, '$i');
    return true;
  }

  /// Spends the theme's price via [Rewards.spend], unlocks it for the current
  /// user and applies it.
  static Future<ThemeBuyResult> buy(int i) async {
    if (isUnlocked(i)) {
      await select(i);
      return ThemeBuyResult.alreadyOwned;
    }
    if (!await Rewards.spend(themes[i].price, reason: 'theme')) return ThemeBuyResult.notEnoughCoins;
    final ids = _unlockedIds..add(themes[i].id);
    await Storage.setString(_kUnlocked, ids.join(','));
    unlocks.value++;
    await select(i);
    return ThemeBuyResult.bought;
  }
}
