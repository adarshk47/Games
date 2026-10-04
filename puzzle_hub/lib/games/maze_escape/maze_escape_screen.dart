import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';
import 'labyrinth_game.dart';
import 'logic/levels.dart';
import 'progress.dart';

const Color kMazeTint = Color(0xFFFFC857);

/// Maze Escape: pick a tier, pick a level, find the one way out.
class MazeEscapeScreen extends StatelessWidget {
  const MazeEscapeScreen({super.key});

  @override
  Widget build(BuildContext context) => const _TierSelect();
}

void openMazeLevel(BuildContext context, MazeTier tier, int level, {bool replace = false}) {
  final route = MaterialPageRoute<void>(builder: (_) => LabyrinthGame(tier: tier, level: level));
  final nav = Navigator.of(context);
  replace ? nav.pushReplacement(route) : nav.push(route);
}

const _kColor = Color(0xFF7C5CFF);

const _tierColor = {
  MazeTier.easy: Color(0xFF3DDC97),
  MazeTier.medium: Color(0xFFFFC857),
  MazeTier.hard: Color(0xFFFF8A4C),
  MazeTier.extreme: Color(0xFFFF4D6D),
};
const _tierIcon = {
  MazeTier.easy: Icons.spa_rounded,
  MazeTier.medium: Icons.explore_rounded,
  MazeTier.hard: Icons.local_fire_department_rounded,
  MazeTier.extreme: Icons.bolt_rounded,
};

String _tierBlurb(MazeTier t) {
  final a = LabLevel.of(t, 1).size, b = LabLevel.of(t, kLevelCount).size;
  return switch (t) {
    MazeTier.easy => '${a}x$a to ${b}x$b mazes. Clear view, 3 torches.',
    MazeTier.medium => '${a}x$a to ${b}x$b mazes. Light fog later on, 3 torches.',
    MazeTier.hard => '${a}x$a to ${b}x$b mazes. Fog, move limits, 2 torches.',
    MazeTier.extreme => '${a}x$a to ${b}x$b mazes. Thick fog, tight move limit, 1 torch.',
  };
}

class _TierSelect extends StatefulWidget {
  const _TierSelect();

  @override
  State<_TierSelect> createState() => _TierSelectState();
}

class _TierSelectState extends State<_TierSelect> {
  @override
  Widget build(BuildContext context) {
    final last = MazeProgress.lastTier;
    return GameScaffold(
      title: 'Maze Escape',
      tint: kMazeTint,
      body: ValueListenableBuilder<int>(
        valueListenable: MazeProgress.tick,
        builder: (context, _, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text('Tum phanse ho. Raaste bahut hain,\nbahar ka sirf ek hai.',
                style: TextStyle(color: Pal.textDim, fontSize: 15, height: 1.4)),
            const SizedBox(height: 14),
            const Text('Choose your difficulty', style: TextStyle(color: Pal.textDim, fontSize: 15)),
            const SizedBox(height: 14),
            for (final t in MazeTier.values) ...[
              _tierCard(context, t, t == last),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tierCard(BuildContext context, MazeTier t, bool isLast) {
    final c = _tierColor[t]!;
    final stars = MazeProgress.totalStars(t);
    final done = MazeProgress.completed(t);
    return GlassCard(
      glow: isLast ? c : null,
      radius: 24,
      padding: const EdgeInsets.all(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c.withValues(alpha: 0.4), c.withValues(alpha: 0.08)],
      ),
      onTap: () {
        MazeProgress.lastTier = t;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => _LevelSelect(tier: t))).then((_) {
          if (mounted) setState(() {});
        });
      },
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: 0.25), border: Border.all(color: c, width: 1.5)),
          child: Icon(_tierIcon[t], color: c, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(t.label, style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900)),
              if (isLast) ...[
                const SizedBox(width: 8),
                Text('LAST PLAYED', style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              ],
            ]),
            const SizedBox(height: 3),
            Text(_tierBlurb(t), style: const TextStyle(color: Pal.textDim, fontSize: 12.5, height: 1.3)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.star_rounded, color: Pal.gold, size: 16),
              const SizedBox(width: 3),
              Text('$stars / ${kLevelCount * 3}', style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w800, fontSize: 12.5)),
              const SizedBox(width: 12),
              Text('$done / $kLevelCount', style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ]),
          ]),
        ),
        const Icon(Icons.arrow_forward_rounded, color: Pal.text),
      ]),
    );
  }
}

class _LevelSelect extends StatelessWidget {
  const _LevelSelect({required this.tier});
  final MazeTier tier;

  @override
  Widget build(BuildContext context) {
    const color = _kColor;
    return GameScaffold(
      title: 'Labyrinth - ${tier.label}',
      tint: color,
      body: ValueListenableBuilder<int>(
        valueListenable: MazeProgress.tick,
        builder: (context, _, _) => GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85),
          itemCount: kLevelCount,
          itemBuilder: (context, i) {
            final level = i + 1;
            final open = MazeProgress.unlocked(tier, level);
            final stars = MazeProgress.stars(tier, level);
            final sub = '${LabLevel.of(tier, level).size}x${LabLevel.of(tier, level).size}';
            return Opacity(
              opacity: open ? 1 : 0.45,
              child: GlassCard(
                blur: 0,
                radius: 20,
                padding: const EdgeInsets.all(8),
                glow: stars > 0 ? color : null,
                onTap: open ? () => openMazeLevel(context, tier, level) : () {},
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  open
                      ? Text('$level', style: const TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w900))
                      : const Icon(Icons.lock_rounded, color: Pal.textDim, size: 24),
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(color: Pal.textDim, fontSize: 11)),
                  const SizedBox(height: 4),
                  StarRow(stars: stars, size: 14),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}
