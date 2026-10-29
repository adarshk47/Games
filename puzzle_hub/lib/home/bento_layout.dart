import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/game_info.dart';
import '../core/i18n/i18n.dart';
import '../core/ui/app_theme.dart';
import '../core/ui/ui.dart';
import 'theme_styles.dart';

/// "Bento" home (goes with the new themes): category tabs, then every game
/// on one screen – big tiles for new games and the game of the day, small
/// tiles in a 3-column grid for the rest. No sideways scrolling.
class BentoHome extends StatefulWidget {
  const BentoHome({
    super.key,
    required this.header,
    required this.games,
    required this.big,
    required this.categories,
    required this.onOpen,
    this.bottomInset = 0,
  });

  final Widget header;
  final List<GameInfo> games;

  /// Games shown as big (2-column) tiles at the top of "All".
  final List<GameInfo> big;

  /// (label, emoji, game ids) per tab after "All".
  final List<(String, String, List<String>)> categories;
  final ValueChanged<GameInfo> onOpen;
  final double bottomInset;

  @override
  State<BentoHome> createState() => _BentoHomeState();
}

class _BentoHomeState extends State<BentoHome> {
  int _tab = 0; // 0 = All

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hPad = width < 360 ? 12.0 : 16.0;
    const gap = 10.0;
    final inner = width - hPad * 2;
    final small = (inner - gap * 2) / 3;
    final bigW = small * 2 + gap;
    final tileH = small * 1.12;

    final List<GameInfo> list;
    final List<GameInfo> big;
    if (_tab == 0) {
      big = widget.big;
      list = [for (final g in widget.games) if (!big.contains(g)) g];
    } else {
      final ids = widget.categories[_tab - 1].$3;
      big = const [];
      list = [for (final g in widget.games) if (ids.contains(g.id)) g];
    }
    final t = AppThemeController.theme;

    return CustomScrollView(
      key: const ValueKey('bento_layout'),
      slivers: [
        SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 4), child: widget.header)),
        if (ThemeStyle.greeting() case final greet?)
          SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0), child: greet)),
        // Category tabs.
        SliverToBoxAdapter(
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 4),
              children: [
                for (var i = 0; i <= widget.categories.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Pressable(
                      key: ValueKey('bento_tab_$i'),
                      onTap: () => setState(() => _tab = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: i == _tab ? LinearGradient(colors: [t.accent, Color.lerp(t.accent, t.orb2, 0.5)!]) : null,
                          color: i == _tab ? null : Colors.white.withValues(alpha: 0.08),
                          border: Border.all(color: i == _tab ? t.highlight : Pal.glassBorder),
                        ),
                        child: Text(
                          i == 0 ? '✨ ${tr('home.bento.all')}' : '${widget.categories[i - 1].$2} ${widget.categories[i - 1].$1}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, widget.bottomInset + 20),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (i, g) in big.indexed)
                  _BentoTile(key: ValueKey('game_${g.id}'), g: g, width: i.isEven ? bigW : small, height: tileH, big: i.isEven, onTap: () => widget.onOpen(g)),
                for (final g in list) _BentoTile(key: ValueKey('game_${g.id}'), g: g, width: small, height: tileH, onTap: () => widget.onOpen(g)),
              ].animate(interval: 25.ms).fadeIn(duration: 250.ms).scale(begin: const Offset(0.95, 0.95)),
            ),
          ),
        ),
      ],
    );
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({super.key, required this.g, required this.width, required this.height, required this.onTap, this.big = false});
  final GameInfo g;
  final double width, height;
  final bool big;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = g.color;
    final tile = Pressable(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(c, Colors.white, 0.18)!, Color.lerp(c, Colors.black, 0.4)!],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: big
            ? Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    _badge(g.comingSoon ? '🔒' : (g.featured ? tr('home.new_badge') : '⭐')),
                    const SizedBox(height: 6),
                    Text(g.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.1)),
                    const SizedBox(height: 4),
                    Text(g.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5, height: 1.2)),
                  ]),
                ),
                _art(height * 0.55),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Expanded(child: Center(child: _art(height * 0.42))),
                Text(g.title, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.1)),
              ]),
      ),
    );
    return Stack(children: [
      ThemeStyle.frame(tile),
      if (g.comingSoon && !big)
        Positioned(top: 6, right: 6, child: _badge('🔒')),
    ]);
  }

  Widget _art(double size) => g.emoji != null
      ? Text(g.emoji!, style: TextStyle(fontSize: size * 0.8))
      : Icon(g.icon, color: Colors.white, size: size * 0.8);

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
      );
}
