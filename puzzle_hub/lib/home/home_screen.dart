import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/game_info.dart';
import '../core/ui/ui.dart';
import '../games/registry.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, GameInfo g) =>
      Navigator.of(context).push(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (ctx, _, _) => g.builder(ctx),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final featured = games.where((g) => g.featured).toList();
    final rest = games.where((g) => !g.featured).toList();
    return Scaffold(
      backgroundColor: Pal.bg0,
      body: AnimatedBackground(
        child: SafeArea(
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(colors: [Pal.gold, Color(0xFFFF8FB8), Color(0xFFB794FF)]).createShader(r),
                    child: const Text('Puzzle Hub',
                        style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                  ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 4),
                  const Text('Khelo. Socho. Yaaddasht badhao ✨', style: TextStyle(color: Pal.textDim, fontSize: 15))
                      .animate(delay: 150.ms)
                      .fadeIn(duration: 500.ms),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              sliver: SliverList.list(children: [
                for (var i = 0; i < featured.length; i++)
                  _FeaturedCard(g: featured[i], onTap: () => _open(context, featured[i]))
                      .animate(delay: (200 + i * 100).ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
              ]),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.92,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _GameCard(g: rest[i], onTap: () => _open(context, rest[i]))
                      .animate(delay: (350 + i * 80).ms)
                      .fadeIn(duration: 450.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                  childCount: rest.length,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.g, required this.onTap});
  final GameInfo g;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      glow: g.color,
      blur: 0,
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [g.color.withValues(alpha: 0.55), const Color(0xFF7C5CFF).withValues(alpha: 0.35)],
      ),
      child: Row(children: [
        Text(g.emoji ?? '', style: const TextStyle(fontSize: 56))
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: -4, end: 4, duration: 1600.ms, curve: Curves.easeInOut),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Pal.gold, borderRadius: BorderRadius.circular(20)),
              child: const Text('SPECIAL', style: TextStyle(color: Color(0xFF3B2A00), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 6),
            Text(g.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 2),
            Text(g.subtitle, style: const TextStyle(color: Pal.text, fontSize: 13, height: 1.3)),
          ]),
        ),
        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
      ]),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.g, required this.onTap});
  final GameInfo g;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      glow: g.color,
      blur: 0,
      padding: const EdgeInsets.all(14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [g.color.withValues(alpha: 0.38), g.color.withValues(alpha: 0.08)],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: Pal.accent(g.color),
            boxShadow: [BoxShadow(color: g.color.withValues(alpha: 0.6), blurRadius: 22, spreadRadius: -2)],
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
          ),
          child: g.emoji != null
              ? Text(g.emoji!, style: const TextStyle(fontSize: 36))
              : Icon(g.icon, size: 38, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(g.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 4),
        Text(g.subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Pal.textDim, fontSize: 11.5, height: 1.25)),
      ]),
    );
  }
}
