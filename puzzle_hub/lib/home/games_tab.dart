import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/account/account_service.dart';
import '../core/daily/daily_hub_screen.dart';
import '../core/game_info.dart';
import '../core/i18n/i18n.dart';
import '../core/rewards.dart';
import '../core/ui/app_logo.dart';
import '../core/ui/app_layout.dart';
import '../core/ui/app_theme.dart';
import '../core/ui/festive/festive_painters.dart';
import '../core/ui/festive/festive_palette.dart';
import '../core/ui/ui.dart';
import '../games/registry.dart';
import 'game_chakra.dart';

/// "Game of the day" pick: rotates through [list] by calendar date.
GameInfo gameOfTheDay(List<GameInfo> list, [DateTime? now]) {
  final d = now ?? DateTime.now();
  final day = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2024)).inDays;
  return list[day % list.length];
}

/// Opens [g] with the hub's fade + slide transition.
Future<void> openGame(BuildContext context, GameInfo g) => Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (ctx, _, _) => g.builder(ctx),
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ));

/// Home "Games" tab: header, featured / game-of-the-day banner, game grid.
class GamesTab extends StatefulWidget {
  const GamesTab({super.key, this.bottomInset = 0, this.onOpenShop});

  /// Extra bottom padding so the last row clears the floating nav bar.
  final double bottomInset;
  final VoidCallback? onOpenShop;

  @override
  State<GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<GamesTab> {
  /// Entrance animations only run for widgets built in the first frame, so
  /// cards scrolling into view later do not replay them.
  bool _intro = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _intro = false);
  }

  Future<void> _open(GameInfo g) async {
    await openGame(context, g);
    if (mounted) setState(() {}); // refresh level / best stats
  }

  Widget _enter(Widget w, int delayMs, {double dy = 0.15}) => _intro
      ? w.animate(delay: delayMs.ms).fadeIn(duration: 450.ms).slideY(begin: dy, end: 0, curve: Curves.easeOutCubic)
      : w;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLayout>(
      valueListenable: AppLayoutController.current,
      builder: (context, layout, _) =>
          switch (layout) {
            AppLayout.classic => _buildClassic(context),
            AppLayout.festive => _buildFestive(context),
            AppLayout.chakra => _buildChakra(context),
          },
    );
  }

  Widget _buildClassic(BuildContext context) {
    final featured = games.where((g) => g.featured).toList();
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
    final hPad = width < 360 ? 14.0 : 18.0;

    return CustomScrollView(key: const ValueKey('classic_layout'), slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 4),
          child: _Header(onOpenShop: widget.onOpenShop),
        ),
      ),
      if (games.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
            child: _enter(
              featured.isNotEmpty
                  ? _FeaturedCarousel(list: featured, onOpen: _open, banner: _classicBanner)
                  : _Banner(g: gameOfTheDay(games), label: tr('home.game_of_the_day'), onTap: () => _open(gameOfTheDay(games))),
              200,
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad + 4, 22, hPad, 10),
          child: Row(children: [
            Flexible(
              child: Text(tr('home.all_games'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Pal.text, fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppThemeController.theme.accent.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${games.length}',
                  style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, widget.bottomInset + 16),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 204,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => _enter(
              _GameCard(key: ValueKey('game_${games[i].id}'), g: games[i], onTap: () => _open(games[i])),
              300 + i * 70,
              dy: 0.2,
            ),
            childCount: games.length,
          ),
        ),
      ),
    ]);
  }

  static Widget _classicBanner(GameInfo g, String label, VoidCallback onTap) =>
      _Banner(g: g, label: label, onTap: onTap);

  static Widget _thaliBanner(GameInfo g, String label, VoidCallback onTap) =>
      _ThaliBanner(g: g, label: label, onTap: onTap);

  /// Festive header and banner, then every game on a diya chakra.
  Widget _buildChakra(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hPad = width < 360 ? 14.0 : 18.0;
    final size = math.min(width - hPad * 2, 460.0);
    final gotd = gameOfTheDay(games);
    final extra = GameChakra.overflowOf(games, size);

    return CustomScrollView(key: const ValueKey('chakra_layout'), slivers: [
      const SliverToBoxAdapter(
        child: RepaintBoundary(
          child: SizedBox(
            height: 44,
            width: double.infinity,
            child: CustomPaint(painter: ToranPainter()),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 2, hPad, 4),
          child: _Header(onOpenShop: widget.onOpenShop, festive: true),
        ),
      ),
      if (games.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
            child: _enter(
              _ThaliBanner(g: gotd, label: tr('home.game_of_the_day'), onTap: () => _open(gotd)),
              200,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad + 2, 20, hPad, 4),
            child: Row(children: [
              const SizedBox(width: 18, height: 22, child: CustomPaint(painter: DiyaPainter())),
              const SizedBox(width: 8),
              Flexible(
                child: Text(tr('home.all_games'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Festive.zariLight, fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tr('home.chakra_hint'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: Pal.textDim, fontSize: 12)),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _enter(
                GameChakra(list: games, onOpen: _open, gameOfDay: gotd, size: size),
                300,
                dy: 0.05,
              ),
            ),
          ),
        ),
      ],
      SliverPadding(
        padding: EdgeInsets.fromLTRB(hPad, 14, hPad, widget.bottomInset + 16),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: width >= 600 ? 3 : 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 216,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => _FestiveGameCard(key: ValueKey('game_${extra[i].id}'), g: extra[i], onTap: () => _open(extra[i])),
            childCount: extra.length,
          ),
        ),
      ),
    ]);
  }

  /// Indian-festival layout: toran header, thali banner, saree-border cards.
  Widget _buildFestive(BuildContext context) {
    final featured = games.where((g) => g.featured).toList();
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
    final hPad = width < 360 ? 14.0 : 18.0;
    final t = AppThemeController.theme;

    return CustomScrollView(key: const ValueKey('festive_layout'), slivers: [
      const SliverToBoxAdapter(
        child: RepaintBoundary(
          child: SizedBox(
            key: ValueKey('festive_toran'),
            height: 44,
            width: double.infinity,
            child: CustomPaint(painter: ToranPainter()),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 2, hPad, 4),
          child: _Header(onOpenShop: widget.onOpenShop, festive: true),
        ),
      ),
      if (games.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
            child: _enter(
              featured.isNotEmpty
                  ? _FeaturedCarousel(list: featured, onOpen: _open, banner: _thaliBanner)
                  : _ThaliBanner(
                      g: gameOfTheDay(games), label: tr('home.game_of_the_day'), onTap: () => _open(gameOfTheDay(games))),
              200,
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad + 2, 22, hPad, 10),
          child: Row(children: [
            const SizedBox(width: 18, height: 22, child: CustomPaint(painter: DiyaPainter())),
            const SizedBox(width: 8),
            Flexible(
              child: Text(tr('home.all_games'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Festive.zariLight, fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Festive.marigoldDeep, Festive.kumkum]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Festive.zari.withValues(alpha: 0.8)),
              ),
              child: Text('${games.length}',
                  style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1.6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Festive.zari, t.highlight.withValues(alpha: 0)]),
                ),
              ),
            ),
          ]),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, widget.bottomInset + 16),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 216,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => _enter(
              _FestiveGameCard(key: ValueKey('game_${games[i].id}'), g: games[i], onTap: () => _open(games[i])),
              300 + i * 70,
              dy: 0.2,
            ),
            childCount: games.length,
          ),
        ),
      ),
    ]);
  }
}

/// Short stat line for a game card and whether the game is still unplayed.
(String, bool) _statOf(GameInfo g) {
  final levels = Rewards.levels(g.id);
  final best = Rewards.best(g.id);
  final plays = Rewards.plays(g.id);
  if (levels > 0) return ('⭐ $levels', false);
  if (best > 0) return ('🏆 $best', false);
  if (plays > 0) return ('▶ $plays', false);
  return (tr('home.new_badge'), true);
}

class _Header extends StatelessWidget {
  const _Header({this.onOpenShop, this.festive = false});
  final VoidCallback? onOpenShop;
  final bool festive;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeController.theme;
    final a = AccountService.I;
    final name = a.name.trim().isEmpty ? tr('home.player') : a.name.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const AppLogo(size: 44),
        const SizedBox(width: 10),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ShaderMask(
                shaderCallback: (r) => (festive
                        ? const LinearGradient(colors: [Festive.zariLight, Festive.marigold, Festive.zari])
                        : t.wordmark)
                    .createShader(r),
                child: const Text('Master G',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.4)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        CoinPill(onTap: onOpenShop),
        const SizedBox(width: 8),
        GlassCard(
          key: const ValueKey('home_daily'),
          blur: 0,
          radius: 18,
          padding: const EdgeInsets.all(9),
          onTap: () => DailyPage.open(context),
          child: const Icon(Icons.calendar_month_rounded, color: Pal.text, size: 22),
        ),
        const SizedBox(width: 8),
        GlassCard(
          key: const ValueKey('home_settings'),
          blur: 0,
          radius: 18,
          padding: const EdgeInsets.all(9),
          onTap: () => showSettingsSheet(context),
          child: const Icon(Icons.tune_rounded, color: Pal.text, size: 22),
        ),
      ]).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05, end: 0),
      const SizedBox(height: 14),
      Text(
        a.justRegistered ? tr('home.welcome_new', {'name': name}) : tr('home.welcome_back', {'name': name}),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: festive ? Festive.zariLight : Pal.text, fontSize: 20, fontWeight: FontWeight.w800),
      ).animate(delay: 100.ms).fadeIn(duration: 450.ms),
      const SizedBox(height: 2),
      Text(tr('home.tagline'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: festive ? _sandal : Pal.textDim, fontSize: 14))
          .animate(delay: 150.ms)
          .fadeIn(duration: 450.ms),
    ]);
  }
}

class _FeaturedCarousel extends StatefulWidget {
  const _FeaturedCarousel({required this.list, required this.onOpen, required this.banner});
  final List<GameInfo> list;
  final ValueChanged<GameInfo> onOpen;

  /// Builds one page (classic glass banner or festive thali card).
  final Widget Function(GameInfo g, String label, VoidCallback onTap) banner;

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.list;
    if (l.length == 1) return widget.banner(l.first, tr('home.featured'), () => widget.onOpen(l.first));
    return Column(children: [
      SizedBox(
        height: _Banner.height,
        child: PageView.builder(
          controller: _pc,
          itemCount: l.length,
          onPageChanged: (p) => setState(() => _page = p),
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: widget.banner(l[i], tr('home.featured'), () => widget.onOpen(l[i])),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < l.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _page ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _page ? AppThemeController.theme.highlight : Pal.glassBorder,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ]),
    ]);
  }
}

/// Wide banner card for a featured game or the game of the day.
class _Banner extends StatelessWidget {
  const _Banner({required this.g, required this.label, required this.onTap});
  static const double height = 150;
  final GameInfo g;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeController.theme;
    final levels = Rewards.levels(g.id);
    return SizedBox(
      height: height,
      child: GlassCard(
        key: const ValueKey('home_banner'),
        onTap: onTap,
        glow: g.color,
        blur: 0,
        radius: 26,
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [g.color.withValues(alpha: 0.6), t.accent.withValues(alpha: 0.35), t.bg1.withValues(alpha: 0.5)],
        ),
        child: Row(children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Pal.accent(g.color),
              boxShadow: [BoxShadow(color: g.color.withValues(alpha: 0.7), blurRadius: 24, spreadRadius: -2)],
              border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.5),
            ),
            child: g.emoji != null
                ? Text(g.emoji!, style: const TextStyle(fontSize: 42))
                : Icon(g.icon, size: 44, color: Colors.white),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: -3, end: 3, duration: 1800.ms, curve: Curves.easeInOut),
          const SizedBox(width: 14),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: t.highlight, borderRadius: BorderRadius.circular(20)),
                child: Text(label,
                    style: TextStyle(
                        color: Color.lerp(t.highlight, Colors.black, 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2)),
              ),
              const SizedBox(height: 6),
              Text(g.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 2),
              Text(g.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Pal.text, fontSize: 12.5, height: 1.25)),
              if (levels > 0) ...[
                const SizedBox(height: 4),
                Text(tr('home.levels_cleared', {'n': levels}),
                    style: const TextStyle(color: Pal.gold, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ],
            ]),
          ),
          const SizedBox(width: 6),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18)),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
          ),
        ]),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({super.key, required this.g, required this.onTap});
  final GameInfo g;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (stat, isNew) = _statOf(g);
    return GlassCard(
      onTap: onTap,
      glow: g.color,
      blur: 0,
      radius: 24,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [g.color.withValues(alpha: 0.42), g.color.withValues(alpha: 0.10), Colors.black.withValues(alpha: 0.12)],
      ),
      child: Column(children: [
        Align(
          alignment: Alignment.topRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (isNew ? Pal.success : Pal.gold).withValues(alpha: 0.6)),
            ),
            child: Text(stat,
                style: TextStyle(
                    color: isNew ? Pal.success : Pal.gold, fontSize: 10.5, fontWeight: FontWeight.w900)),
          ),
        ),
        const Spacer(),
        Container(
          width: 66,
          height: 66,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: Pal.accent(g.color),
            boxShadow: [BoxShadow(color: g.color.withValues(alpha: 0.6), blurRadius: 20, spreadRadius: -2)],
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
          ),
          child: g.emoji != null
              ? Text(g.emoji!, style: const TextStyle(fontSize: 32))
              : Icon(g.icon, size: 34, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(g.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 3),
        Text(g.subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Pal.textDim, fontSize: 11.5, height: 1.25)),
        const Spacer(),
      ]),
    );
  }
}

/// Sandalwood tone for secondary text on festive surfaces.
const _sandal = Color(0xFFF3D9B1);

/// Game emoji in a gradient disc surrounded by a painted mandala ring.
class _MandalaEmoji extends StatelessWidget {
  const _MandalaEmoji({required this.g, required this.size});
  final GameInfo g;
  final double size;

  @override
  Widget build(BuildContext context) {
    final inner = size * 0.6;
    return SizedBox.square(
      dimension: size,
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(child: CustomPaint(painter: MandalaRingPainter(color: g.color))),
        Container(
          width: inner,
          height: inner,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: Pal.accent(g.color),
            boxShadow: [BoxShadow(color: g.color.withValues(alpha: 0.6), blurRadius: 14, spreadRadius: -2)],
          ),
          child: g.emoji != null
              ? Text(g.emoji!, style: TextStyle(fontSize: inner * 0.56))
              : Icon(g.icon, size: inner * 0.6, color: Colors.white),
        ),
      ]),
    );
  }
}

/// Festive game card: silk-saree body with a temple border, paisley pallu,
/// rangoli corners, zari edges and a mandala around the emoji.
class _FestiveGameCard extends StatelessWidget {
  const _FestiveGameCard({super.key, required this.g, required this.onTap});
  final GameInfo g;
  final VoidCallback onTap;

  static const double _band = 24;

  @override
  Widget build(BuildContext context) {
    final (stat, isNew) = _statOf(g);
    final t = AppThemeController.theme;
    return Pressable(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: g.color.withValues(alpha: 0.3), blurRadius: 24, spreadRadius: -6),
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: CustomPaint(
          painter: SareeCardPainter(color: g.color, base: t.bg1, band: _band),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, _band + 4),
            child: Column(children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Festive.sindoor.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (isNew ? Pal.success : Festive.zari).withValues(alpha: 0.8)),
                  ),
                  child: Text(stat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: isNew ? Pal.success : Festive.zariLight, fontSize: 10.5, fontWeight: FontWeight.w900)),
                ),
              ),
              const Spacer(),
              _MandalaEmoji(g: g, size: 78),
              const SizedBox(height: 6),
              Text(g.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 2),
              Flexible(
                child: Text(g.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _sandal, fontSize: 11.5, height: 1.25)),
              ),
              const Spacer(),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Festive "game of the day" / featured card: a decorated pooja thali with the
/// game in the centre, on a gota-lace framed banner.
class _ThaliBanner extends StatelessWidget {
  const _ThaliBanner({required this.g, required this.label, required this.onTap});
  final GameInfo g;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeController.theme;
    final levels = Rewards.levels(g.id);
    return SizedBox(
      height: _Banner.height,
      child: Pressable(
        key: const ValueKey('home_banner'),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: Festive.marigold.withValues(alpha: 0.3), blurRadius: 28, spreadRadius: -4)],
          ),
          child: CustomPaint(
            painter: GotaFramePainter(color: g.color, base: t.bg1),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              child: LayoutBuilder(builder: (context, box) {
                final plate = math.min(108.0, math.min(box.maxHeight, box.maxWidth * 0.34));
                return Row(children: [
                  SizedBox.square(
                    dimension: plate,
                    child: Stack(alignment: Alignment.center, children: [
                      Positioned.fill(child: CustomPaint(painter: ThaliPainter(color: g.color))),
                      Container(
                        width: plate * 0.48,
                        height: plate * 0.48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: Pal.accent(g.color),
                          border: Border.all(color: Festive.zariLight, width: 1.5),
                          boxShadow: [BoxShadow(color: g.color.withValues(alpha: 0.7), blurRadius: 14, spreadRadius: -2)],
                        ),
                        child: g.emoji != null
                            ? Text(g.emoji!, style: TextStyle(fontSize: plate * 0.26))
                            : Icon(g.icon, size: plate * 0.28, color: Colors.white),
                      ),
                    ]),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(begin: -2.5, end: 2.5, duration: 2000.ms, curve: Curves.easeInOut),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Festive.marigold, Festive.haldi]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Festive.zariLight.withValues(alpha: 0.8)),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(label,
                                  maxLines: 1,
                                  style: const TextStyle(
                                      color: Festive.sindoor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(g.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 2),
                          Flexible(
                            child: Text(g.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: _sandal, fontSize: 12.5, height: 1.25)),
                          ),
                          if (levels > 0) ...[
                            const SizedBox(height: 4),
                            Text(tr('home.levels_cleared', {'n': levels}),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Festive.zariLight, fontSize: 11.5, fontWeight: FontWeight.w800)),
                          ],
                        ]),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: Festive.zariGradient,
                      boxShadow: [BoxShadow(color: Festive.zari.withValues(alpha: 0.5), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Festive.sindoor, size: 24),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}