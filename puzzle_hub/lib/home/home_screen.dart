import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/daily/daily_hub_screen.dart';
import '../core/shop/shop_screen.dart';
import '../core/ui/app_theme.dart';
import '../core/ui/ui.dart';
import 'games_tab.dart';
import 'profile_screen.dart';

/// Height of the floating bottom navigation bar (without its outer margin).
const double kNavBarHeight = 66;
const double _kNavMargin = 12;

/// Space the floating bar occupies at the bottom of the screen; tab bodies keep
/// at least this much bottom padding so content is never hidden behind it.
double navBarInset(BuildContext context) =>
    kNavBarHeight + _kNavMargin * 2 + MediaQuery.paddingOf(context).bottom;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);

  static const _items = <_NavItem>[
    _NavItem('games', 'Games', Icons.sports_esports_outlined, Icons.sports_esports_rounded),
    _NavItem('daily', 'Daily', Icons.calendar_today_outlined, Icons.calendar_month_rounded),
    _NavItem('shop', 'Shop', Icons.storefront_outlined, Icons.storefront_rounded),
    _NavItem('profile', 'Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  void _select(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = navBarInset(context);
    // External tab bodies get plain bottom padding; the games tab scrolls under
    // the glass bar and pads its own last sliver instead.
    Widget padded(Widget w) => Padding(padding: EdgeInsets.only(bottom: inset), child: w);

    return Scaffold(
      backgroundColor: AppThemeController.theme.bg0,
      body: AnimatedBackground(
        child: Stack(children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
                child: IndexedStack(
                  index: _tab,
                  children: [
                    GamesTab(bottomInset: inset, onOpenShop: () => _select(2)),
                    padded(const DailyHubScreen()),
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
            child: _BottomNav(items: _items, index: _tab, onTap: _select),
          ),
        ]),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.id, this.label, this.icon, this.activeIcon);
  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Floating frosted-glass navigation bar with a sliding gradient pill.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.items, required this.index, required this.onTap});
  final List<_NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeController.theme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final br = BorderRadius.circular(30);
    return Padding(
      padding: EdgeInsets.fromLTRB(_kNavMargin, 0, _kNavMargin, _kNavMargin + bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: br,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 8)),
                BoxShadow(color: t.accent.withValues(alpha: 0.18), blurRadius: 30, spreadRadius: -6),
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
                      colors: [t.bg1.withValues(alpha: 0.72), t.bg0.withValues(alpha: 0.82)],
                    ),
                    border: Border.all(color: Pal.glassBorder),
                  ),
                  child: LayoutBuilder(builder: (context, c) {
                    final w = c.maxWidth / items.length;
                    return Stack(children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutBack,
                        left: w * index,
                        top: 0,
                        bottom: 0,
                        width: w,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color.lerp(t.accent, Colors.white, 0.15)!, Color.lerp(t.accent, t.orb, 0.5)!],
                              ),
                              boxShadow: [
                                BoxShadow(color: t.accent.withValues(alpha: 0.55), blurRadius: 16, spreadRadius: -4),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavButton(
                              key: ValueKey('nav_${items[i].id}'),
                              item: items[i],
                              selected: i == index,
                              onTap: () => onTap(i),
                            ),
                          ),
                      ]),
                    ]);
                  }),
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
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedScale(
            scale: selected ? 1.12 : 1,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: Icon(selected ? item.activeIcon : item.icon,
                size: 22, color: selected ? Colors.white : Pal.textDim),
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
        ]),
      ),
    );
  }
}
