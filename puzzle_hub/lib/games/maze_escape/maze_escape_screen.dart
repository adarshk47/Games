import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/ui/ui.dart';
import 'fork_game.dart';
import 'labyrinth_game.dart';
import 'logic/levels.dart';
import 'progress.dart';

const Color kMazeTint = Color(0xFFFFC857);

/// Maze Escape: pick a mode, pick a level, find the one way out.
class MazeEscapeScreen extends StatelessWidget {
  const MazeEscapeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 16),
            _HeroCard(
              emoji: '🧍🚪',
              title: 'Labyrinth',
              subtitle: 'Swipe through a maze full of dead ends. Fog, torches and move limits on harder levels.',
              color: const Color(0xFF7C5CFF),
              mode: MazeMode.labyrinth,
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.15, end: 0),
            const SizedBox(height: 16),
            _HeroCard(
              emoji: '🌲🔦',
              title: 'Fork Path',
              subtitle: 'At every fork only one trail is right. Remember what you tried - the forest does not forgive.',
              color: const Color(0xFF1FB589),
              mode: MazeMode.fork,
            ).animate(delay: 120.ms).fadeIn(duration: 350.ms).slideY(begin: 0.15, end: 0),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.emoji, required this.title, required this.subtitle, required this.color, required this.mode});
  final String emoji, title, subtitle;
  final Color color;
  final MazeMode mode;

  @override
  Widget build(BuildContext context) {
    var total = 0, done = 0;
    for (final t in MazeTier.values) {
      total += MazeProgress.totalStars(mode, t);
      done += MazeProgress.completed(mode, t);
    }
    const levels = kLevelCount * 4;
    return GlassCard(
      glow: color,
      radius: 28,
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0.12)],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _TierSelect(mode: mode))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 44)),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: Pal.text, fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Pal.textDim, fontSize: 14, height: 1.35)),
        const SizedBox(height: 14),
        Row(children: [
          const Icon(Icons.star_rounded, color: Pal.gold, size: 20),
          const SizedBox(width: 4),
          Text('$total / ${levels * 3}', style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w800)),
          const SizedBox(width: 14),
          Text('$done / $levels levels', style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w600)),
          const Spacer(),
          const Icon(Icons.arrow_forward_rounded, color: Pal.text),
        ]),
      ]),
    );
  }
}

void openMazeLevel(BuildContext context, MazeMode mode, MazeTier tier, int level, {bool replace = false}) {
  final route = MaterialPageRoute<void>(
    builder: (_) => mode == MazeMode.labyrinth ? LabyrinthGame(tier: tier, level: level) : ForkGame(tier: tier, level: level),
  );
  final nav = Navigator.of(context);
  replace ? nav.pushReplacement(route) : nav.push(route);
}

Color _modeColor(MazeMode m) => m == MazeMode.labyrinth ? const Color(0xFF7C5CFF) : const Color(0xFF1FB589);
String _modeTitle(MazeMode m) => m == MazeMode.labyrinth ? 'Labyrinth' : 'Fork Path';

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

String _tierBlurb(MazeMode mode, MazeTier t) {
  if (mode == MazeMode.labyrinth) {
    final a = LabLevel.of(t, 1).size, b = LabLevel.of(t, kLevelCount).size;
    return switch (t) {
      MazeTier.easy => '${a}x$a to ${b}x$b mazes. Clear view, 3 torches.',
      MazeTier.medium => '${a}x$a to ${b}x$b mazes. Light fog later on, 3 torches.',
      MazeTier.hard => '${a}x$a to ${b}x$b mazes. Fog, move limits, 2 torches.',
      MazeTier.extreme => '${a}x$a to ${b}x$b mazes. Thick fog, tight move limit, 1 torch.',
    };
  }
  return switch (t) {
    MazeTier.easy => '3 trails, 3-4 forks. Wrong turns are forgiven.',
    MazeTier.medium => '3-4 trails, 4-6 forks. 2 lanterns.',
    MazeTier.hard => '4-5 trails, up to 8 forks. Deep wrong turns send you back.',
    MazeTier.extreme => '5-6 trails, up to 10 forks. Every wrong turn resets. 1 lantern.',
  };
}

class _TierSelect extends StatefulWidget {
  const _TierSelect({required this.mode});
  final MazeMode mode;

  @override
  State<_TierSelect> createState() => _TierSelectState();
}

class _TierSelectState extends State<_TierSelect> {
  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final last = MazeProgress.lastTier;
    return GameScaffold(
      title: _modeTitle(mode),
      tint: _modeColor(mode),
      body: ValueListenableBuilder<int>(
        valueListenable: MazeProgress.tick,
        builder: (context, _, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
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
    final stars = MazeProgress.totalStars(widget.mode, t);
    final done = MazeProgress.completed(widget.mode, t);
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
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => _LevelSelect(mode: widget.mode, tier: t))).then((_) {
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
            Text(_tierBlurb(widget.mode, t), style: const TextStyle(color: Pal.textDim, fontSize: 12.5, height: 1.3)),
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
  const _LevelSelect({required this.mode, required this.tier});
  final MazeMode mode;
  final MazeTier tier;

  @override
  Widget build(BuildContext context) {
    final lab = mode == MazeMode.labyrinth;
    final color = _modeColor(mode);
    return GameScaffold(
      title: '${_modeTitle(mode)} - ${tier.label}',
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
            final open = MazeProgress.unlocked(mode, tier, level);
            final stars = MazeProgress.stars(mode, tier, level);
            final sub = lab
                ? '${LabLevel.of(tier, level).size}x${LabLevel.of(tier, level).size}'
                : '${ForkLevel.of(tier, level).forks} forks';
            return Opacity(
              opacity: open ? 1 : 0.45,
              child: GlassCard(
                blur: 0,
                radius: 20,
                padding: const EdgeInsets.all(8),
                glow: stars > 0 ? color : null,
                onTap: open ? () => openMazeLevel(context, mode, tier, level) : () {},
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
