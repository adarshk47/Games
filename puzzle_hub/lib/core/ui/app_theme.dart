import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../rewards.dart';
import '../storage.dart';
import 'app_layout.dart';

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
    this.festive = false,
    this.decor,
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

  /// Festive themes paint diya glows, marigold petals, rangoli and sparkles
  /// over the animated background.
  final bool festive;

  /// Extra animated decoration: 'arcade' (floating game pieces), 'winter',
  /// 'neon', 'christmas' or 'newyear'.
  final String? decor;

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
    // Indian festival themes (appended so saved indices stay valid).
    AppThemeData(
      id: 'utsav',
      name: 'Utsav',
      bg0: Color(0xFF1C0805), // deep kumkum
      bg1: Color(0xFF4A1410), // sindoor maroon
      orb: Color(0xFFE8590C), // marigold
      orb2: Color(0xFF0F8A84), // peacock teal
      accent: Color(0xFFFF8F1F), // genda orange
      highlight: Color(0xFFFFC93C), // haldi
      festive: true,
    ),
    AppThemeData(
      id: 'diwali',
      name: 'Diwali Night',
      bg0: Color(0xFF10030E),
      bg1: Color(0xFF3A0A2E), // maroon-purple night
      orb: Color(0xFF6B1E5A),
      orb2: Color(0xFFFF9F1C), // diya flame
      accent: Color(0xFFE0A526), // zari gold
      highlight: Color(0xFFFFE08A),
      price: 500,
      festive: true,
    ),
    AppThemeData(
      id: 'arcade',
      name: 'Master Arcade',
      bg0: Color(0xFF080522), // night indigo
      bg1: Color(0xFF241066), // icon purple
      orb: Color(0xFF5B2BD6),
      orb2: Color(0xFF22D3EE), // cyan
      accent: Color(0xFF8B5CF6),
      highlight: Color(0xFFFFD369), // M-coin gold
      decor: 'arcade',
    ),
    AppThemeData(
      id: 'winter',
      name: 'Winter Lights',
      bg0: Color(0xFF040D1F),
      bg1: Color(0xFF0E2A52),
      orb: Color(0xFF1E4C8F),
      orb2: Color(0xFFA5F3FC),
      accent: Color(0xFF60A5FA),
      highlight: Color(0xFFE0F2FE),
      decor: 'winter',
    ),
    AppThemeData(
      id: 'neon',
      name: 'Neon Night',
      bg0: Color(0xFF05010D),
      bg1: Color(0xFF1A0633),
      orb: Color(0xFF7A00D6),
      orb2: Color(0xFF00F0FF),
      accent: Color(0xFFFF2BD6),
      highlight: Color(0xFF00F0FF),
      decor: 'neon',
    ),
    AppThemeData(
      id: 'christmas',
      name: 'Merry Christmas',
      bg0: Color(0xFF06140C),
      bg1: Color(0xFF14402A),
      orb: Color(0xFFB91C1C),
      orb2: Color(0xFFF59E0B),
      accent: Color(0xFFDC2626),
      highlight: Color(0xFFFDE68A),
      decor: 'christmas',
    ),
    AppThemeData(
      id: 'newyear',
      name: 'Happy New Year',
      bg0: Color(0xFF07071A),
      bg1: Color(0xFF1F1147),
      orb: Color(0xFF7C3AED),
      orb2: Color(0xFFF472B6),
      accent: Color(0xFFF59E0B),
      highlight: Color(0xFFFDE68A),
      decor: 'newyear',
    ),
  ];

  /// Festive Utsav until Diwali season ends, then Master Arcade.
  static final DateTime festiveEnds = DateTime(2026, 11, 16);

  /// The season's theme for players who never picked one themselves:
  /// Utsav (Diwali season 2026), Winter Lights (1–17 Dec and January),
  /// Merry Christmas (18–27 Dec), Happy New Year (28 Dec – 3 Jan), else
  /// Master Arcade.
  static String seasonalId(DateTime now) {
    if (now.isBefore(festiveEnds)) return 'utsav';
    final m = now.month, d = now.day;
    if (m == 12 && d >= 28 || m == 1 && d <= 3) return 'newyear';
    if (m == 12 && d >= 18) return 'christmas';
    if (m == 12 || m == 1) return 'winter';
    return 'arcade';
  }

  static int get defaultIndex => themes.indexWhere((t) => t.id == seasonalId(DateTime.now()));
  static final ValueNotifier<int> current = ValueNotifier<int>(defaultIndex);

  /// Bumped whenever the unlocked set changes (so pickers can refresh).
  static final ValueNotifier<int> unlocks = ValueNotifier<int>(0);

  /// The active theme.
  static AppThemeData get theme => themes[current.value.clamp(0, themes.length - 1)];

  static Future<void> init() async {
    // Players who never picked a theme follow the season: Utsav during
    // Diwali, Master Arcade afterwards.
    final i = int.tryParse(Storage.globalString(_kTheme) ?? '') ?? defaultIndex;
    current.value = (i >= 0 && i < themes.length) ? i : defaultIndex;
    await AppLayoutController.init();
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
