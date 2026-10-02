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
    final total = MazeProgress.totalStars(mode);
    final done = MazeProgress.completed(mode);
    return GlassCard(
      glow: color,
      radius: 28,
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0.12)],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _LevelSelect(mode: mode))),
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
          Text('$total / ${kLevelCount * 3}', style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w800)),
          const SizedBox(width: 14),
          Text('$done / $kLevelCount levels', style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w600)),
          const Spacer(),
          const Icon(Icons.arrow_forward_rounded, color: Pal.text),
        ]),
      ]),
    );
  }
}

void openMazeLevel(BuildContext context, MazeMode mode, int level, {bool replace = false}) {
  final route = MaterialPageRoute<void>(
    builder: (_) => mode == MazeMode.labyrinth ? LabyrinthGame(level: level) : ForkGame(level: level),
  );
  final nav = Navigator.of(context);
  replace ? nav.pushReplacement(route) : nav.push(route);
}

class _LevelSelect extends StatelessWidget {
  const _LevelSelect({required this.mode});
  final MazeMode mode;

  @override
  Widget build(BuildContext context) {
    final lab = mode == MazeMode.labyrinth;
    final color = lab ? const Color(0xFF7C5CFF) : const Color(0xFF1FB589);
    return GameScaffold(
      title: lab ? 'Labyrinth' : 'Fork Path',
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
            final open = MazeProgress.unlocked(mode, level);
            final stars = MazeProgress.stars(mode, level);
            final sub = lab
                ? '${LabLevel.of(level).size}x${LabLevel.of(level).size}'
                : '${ForkLevel.of(level).forks} forks';
            return Opacity(
              opacity: open ? 1 : 0.45,
              child: GlassCard(
                blur: 0,
                radius: 20,
                padding: const EdgeInsets.all(8),
                glow: stars > 0 ? color : null,
                onTap: open ? () => openMazeLevel(context, mode, level) : () {},
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
