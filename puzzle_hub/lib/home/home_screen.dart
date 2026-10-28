import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads/banner_strip.dart';
import '../core/audio.dart';
import '../core/i18n/i18n.dart';
import '../core/shop/shop_screen.dart';
import '../core/ui/app_theme.dart';
import '../core/ui/ui.dart';
import 'games_tab.dart';
import 'profile_screen.dart';
import '../core/account/account_service.dart';
import '../core/game_info.dart';
import '../games/registry.dart';
import '../core/shortcuts/game_shortcuts.dart';

/// Height of the floating bottom navigation bar (without its outer margin).
const double kNavBarHeight = 66;
const double _kNavMargin = 12;

/// Space the floating bar occupies at the bottom of the screen; tab bodies keep
/// at least this much bottom padding so content is never hidden behind it.
double navBarInset(BuildContext context) =>
    kNavBarHeight +
    _kNavMargin * 2 +
    MediaQuery.paddingOf(context).bottom +
    (BannerStrip.showing.value ? BannerStrip.height : 0);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  DateTime? _lastBack;
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  static const _items = <_NavItem>[
    _NavItem(
      'games',
      'home.nav.games',
      Icons.sports_esports_outlined,
      Icons.sports_esports_rounded,
    ),
    // Ludo and Chess open the game directly (no tab of their own).
    _NavItem(
      'ludo',
      'game.ludo.title',
      Icons.casino_outlined,
      Icons.casino_rounded,
    ),
    _NavItem(
      'chess',
      'game.chess.title',
      Icons.castle_outlined,
      Icons.castle_rounded,
    ),
    _NavItem(
      'shop',
      'home.nav.shop',
      Icons.storefront_outlined,
      Icons.storefront_rounded,
    ),
    _NavItem(
      'profile',
      'home.nav.profile',
      Icons.person_outline_rounded,
      Icons.person_rounded,
    ),
  ];

  /// Nav items that open a game instead of switching the tab.
  static const _gameItems = {1: 'ludo', 2: 'chess'};

  void _select(int i) {
    final gameId = _gameItems[i];
    if (gameId != null) {
      final g = games.where((x) => x.id == gameId);
      if (g.isNotEmpty) openGame(context, g.first);
      return;
    }
    if (i == _tab) return;
    setState(() => _tab = i);
    _fade.forward(from: 0);
  }

  /// Shown once per app launch.
  static bool _welcomed = false;

  @override
  void initState() {
    super.initState();
    GameShortcuts.pending.addListener(_openPending);
    unawaited(GameShortcuts.refresh(games));
    final fromShortcut = GameShortcuts.pending.value != null;
    if (!_welcomed) {
      _welcomed = true;
      // Opened from the widget / an icon shortcut: go straight to that game.
      if (!fromShortcut) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcome());
      }
    }
    if (fromShortcut) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
    }
  }

  /// Opens the game a widget tap / icon shortcut asked for.
  void _openPending() {
    final id = GameShortcuts.pending.value;
    if (id == null || !mounted) return;
    GameShortcuts.pending.value = null;
    final g = games.where((x) => x.id == id);
    if (g.isEmpty) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    openGame(context, g.first);
  }

  /// Same pick as the Games tab banner: one game per calendar day.
  GameInfo? get _gameOfDay {
    final list = [for (final g in games) if (!g.comingSoon) g];
    if (list.isEmpty) return null;
    final now = DateTime.now();
    final day = now.difference(DateTime(now.year)).inDays;
    return list[day % list.length];
  }

  Future<void> _showWelcome() async {
    if (!mounted) return;
    final a = AccountService.I;
    // Arrow Maze is the default quick-play game.
    final arrow = games.where((x) => x.id == 'arrow_maze');
    final g = arrow.isNotEmpty ? arrow.first : _gameOfDay;
    await showPremiumDialog(
      context,
      emoji: '👋',
      title: a.justRegistered
          ? tr('home.welcome_new', {'name': a.name})
          : tr('home.welcome_back', {'name': a.name}),
      message: g == null ? null : tr('home.welcome_pick'),
      dismissible: true,
      actions: [
        DialogAction(tr('home.welcome_all_games'), () {}),
        if (g != null)
          DialogAction(
            '${g.emoji ?? '🎮'} ${tr('home.welcome_play_gotd', {'game': g.title})}',
            () {
              if (mounted) {
                openGame(context, g);
              }
            },
            primary: true,
          ),
      ],
    );
  }

  @override
  void dispose() {
    GameShortcuts.pending.removeListener(_openPending);
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: BannerStrip.showing,
    builder: (context, _, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final inset = navBarInset(context);
    // External tab bodies get plain bottom padding; the games tab scrolls under
    // the glass bar and pads its own last sliver instead.
    Widget padded(Widget w) => Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: w,
    );

    // Back: other tabs go to Home; on Home, back twice (within 2 s) exits.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_tab != 0) {
          _select(0);
          return;
        }
        final now = DateTime.now();
        final last = _lastBack;
        _lastBack = now;
        if (last != null && now.difference(last) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(tr('home.back_exit')), duration: const Duration(seconds: 2)));
      },
      child: Scaffold(
      backgroundColor: AppThemeController.theme.bg0,
      body: AnimatedBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _fade,
                    curve: Curves.easeOut,
                  ),
                  child: IndexedStack(
                    index: switch (_tab) { 3 => 1, 4 => 2, _ => 0 },
                    children: [
                      GamesTab(
                        bottomInset: inset,
                        onOpenShop: () => _select(3),
                      ),
                      padded(const ShopScreen()),
                      padded(const ProfileTab()),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              // Banner (menu screens only) sits just above the nav bar.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BannerStrip(),
                  _BottomNav(items: _items, index: _tab, onTap: _select),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _NavItem {
  const _NavItem(this.id, this.labelKey, this.icon, this.activeIcon);
  final String id;
  final String labelKey;
  String get label => tr(labelKey);
  final IconData icon;
  final IconData activeIcon;
}

/// Floating frosted-glass navigation bar with a sliding gradient pill.
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.items,
    required this.index,
    required this.onTap,
  });
  final List<_NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeController.theme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final br = BorderRadius.circular(30);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _kNavMargin,
        0,
        _kNavMargin,
        _kNavMargin + bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: br,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: t.accent.withValues(alpha: 0.18),
                  blurRadius: 30,
                  spreadRadius: -6,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: br,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: kNavBarHeight,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: br,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        t.bg1.withValues(alpha: 0.72),
                        t.bg0.withValues(alpha: 0.82),
                      ],
                    ),
                    border: Border.all(color: Pal.glassBorder),
                  ),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth / items.length;
                      return Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutBack,
                            left: w * index,
                            top: 0,
                            bottom: 0,
                            width: w,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color.lerp(t.accent, Colors.white, 0.15)!,
                                      Color.lerp(t.accent, t.orb, 0.5)!,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: t.accent.withValues(alpha: 0.55),
                                      blurRadius: 16,
                                      spreadRadius: -4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              for (var i = 0; i < items.length; i++)
                                Expanded(
                                  child: _NavButton(
                                    key: ValueKey('nav_${items[i].id}'),
                                    item: items[i],
                                    selected: i == index,
                                    onTap: () => onTap(i),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!selected) AppAudio.play(Sound.tap, volume: 0.5);
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Icon(
                selected ? item.activeIcon : item.icon,
                size: 22,
                color: selected ? Colors.white : Pal.textDim,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  color: selected ? Colors.white : Pal.textDim,
                  letterSpacing: 0.2,
                ),
                child: Text(item.label, maxLines: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
