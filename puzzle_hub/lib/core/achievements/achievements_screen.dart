import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../daily/daily_reward.dart';
import '../i18n/i18n.dart';
import '../ui/ui.dart';
import 'achievements.dart';

/// Full screen grid of badges (locked / unlocked) with progress bars.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  @override
  void initState() {
    super.initState();
    Achievements.evaluate();
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: tr('ach.title'),
      tint: Pal.gold,
      body: ValueListenableBuilder<int>(
        valueListenable: dailyChanged,
        builder: (context, _, _) {
          final stats = AchStats.load();
          final list = Achievements.all();
          final have = Achievements.unlocked;
          // Unlocked first, then by closest to completion.
          list.sort((a, b) {
            final ua = have.contains(a.id), ub = have.contains(b.id);
            if (ua != ub) return ua ? -1 : 1;
            return b.fraction(stats).compareTo(a.fraction(stats));
          });
          final done = list.where((a) => have.contains(a.id)).length;
          return CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              sliver: SliverToBoxAdapter(child: _Summary(done: done, total: list.length)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _BadgeTile(a: list[i], stats: stats, unlocked: have.contains(list[i].id))
                      .animate()
                      .fadeIn(delay: (30 * i).clamp(0, 600).ms, duration: 300.ms)
                      .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), curve: Curves.easeOutBack),
                  childCount: list.length,
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.done, required this.total});
  final int done, total;

  @override
  Widget build(BuildContext context) {
    final f = total == 0 ? 0.0 : done / total;
    return GlassCard(
      glow: Pal.gold,
      child: Row(children: [
        const Text('🏅', style: TextStyle(fontSize: 40)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('ach.badges', {'done': done, 'total': total}), style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ProgressBar(value: f, color: Pal.gold, height: 10),
          ]),
        ),
      ]),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.a, required this.stats, required this.unlocked});
  final Achievement a;
  final AchStats stats;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final cur = a.current(stats);
    Widget medal = Container(
      width: 70,
      height: 70,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: unlocked
            ? Pal.accent(a.color)
            : const LinearGradient(colors: [Color(0xFF3C3860), Color(0xFF26223F)]),
        border: Border.all(color: unlocked ? Colors.white.withValues(alpha: 0.7) : Pal.glassBorder, width: 2),
        boxShadow: unlocked ? [BoxShadow(color: a.color.withValues(alpha: 0.6), blurRadius: 22, spreadRadius: 1)] : null,
      ),
      child: unlocked
          ? Text(a.emoji, style: const TextStyle(fontSize: 32))
          : Stack(alignment: Alignment.center, children: [
              Opacity(opacity: 0.25, child: Text(a.emoji, style: const TextStyle(fontSize: 30))),
              const Icon(Icons.lock_rounded, color: Pal.textDim, size: 24),
            ]),
    );
    if (unlocked) {
      medal = medal
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 2200.ms, color: Colors.white.withValues(alpha: 0.35));
    }
    return GlassCard(
      blur: 0,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      glow: unlocked ? a.color : null,
      child: Column(children: [
        medal,
        const SizedBox(height: 10),
        Text(a.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: unlocked ? Pal.text : Pal.textDim, fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(height: 4),
        Expanded(
          child: Text(a.desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pal.textDim, fontSize: 11, height: 1.25)),
        ),
        if (unlocked)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_rounded, color: Pal.success, size: 16),
            const SizedBox(width: 4),
            Text('+${a.reward} 🪙', style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w800, fontSize: 12)),
          ])
        else ...[
          ProgressBar(value: a.fraction(stats), color: a.color, height: 6),
          const SizedBox(height: 4),
          Text('$cur / ${a.target}  ·  ${a.reward} 🪙',
              style: const TextStyle(color: Pal.textDim, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }
}

/// Rounded glowing progress bar shared by the daily and achievement screens.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, required this.color, this.height = 8});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(height)),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: v),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, x, _) => FractionallySizedBox(
          widthFactor: x,
          child: Container(
            decoration: BoxDecoration(
              gradient: Pal.accent(color),
              borderRadius: BorderRadius.circular(height),
              boxShadow: x > 0 ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)] : null,
            ),
          ),
        ),
      ),
    );
  }
}
