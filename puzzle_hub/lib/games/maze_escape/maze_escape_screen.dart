import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/economy/level_gate.dart';
import '../../core/i18n/i18n.dart';
import '../../core/ui/ui.dart';
import 'labyrinth_game.dart';
import 'logic/levels.dart';
import 'memory_maze_game.dart';
import 'progress.dart';

const Color kMazeTint = Color(0xFFFFC857);

/// Localized tier name ("Easy", ...).
String mazeTierLabel(MazeTier t) => tr('common.tier.${t.name}');

/// Localized mode name ("Labyrinth" / "Memory Maze").
String mazeModeLabel(MazeMode m) => tr('maze_escape.mode.${m.name}');

/// Maze Escape: pick a mode, a tier, a level, then find the one way out.
class MazeEscapeScreen extends StatelessWidget {
  const MazeEscapeScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ModeMenu();
}

void openMazeLevel(BuildContext context, MazeTier tier, int level, {bool replace = false, MazeMode mode = MazeMode.labyrinth}) {
  final route = MaterialPageRoute<void>(
    builder: (_) => mode == MazeMode.memory ? MemoryMazeGame(tier: tier, level: level) : LabyrinthGame(tier: tier, level: level),
  );
  final nav = Navigator.of(context);
  replace ? nav.pushReplacement(route) : nav.push(route);
}

/// Makes sure [level] may be played: free levels pass; a locked level must be
/// bought with coins via [LevelGate] (or still have bought plays left).
Future<bool> ensureMazeLevel(BuildContext context, MazeTier tier, int level, {MazeMode mode = MazeMode.labyrinth}) async {
  if (MazeProgress.canPlay(tier, level, mode: mode)) return true;
  final ok = await LevelGate.buy(context,
      prefix: MazeProgress.gatePrefix(tier, mode: mode), freeUpTo: MazeProgress.freeUpTo(tier, mode: mode), level: level);
  MazeProgress.tick.value++;
  return ok;
}

/// Tapping a locked tile: skip ahead with coins (100 per skipped level, a
/// limited number of plays), then open it.
Future<void> buyMazeLevel(BuildContext context, MazeTier tier, int level, {MazeMode mode = MazeMode.labyrinth}) async {
  final ok = await ensureMazeLevel(context, tier, level, mode: mode);
  if (!ok || !context.mounted) return;
  openMazeLevel(context, tier, level, mode: mode);
}

const _kColor = Color(0xFF7C5CFF);
const kMemColor = Color(0xFF2EC4FF);

Color _modeColor(MazeMode m) => m == MazeMode.memory ? kMemColor : _kColor;

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
  if (mode == MazeMode.memory) {
    final a = MemLevel.minSize(t), b = MemLevel.maxSize(t);
    final l = MemLevel.of(t, 1);
    final peeks = l.peeks == 0
        ? tr('maze_escape.no_peeks')
        : tr(l.peeks == 1 ? 'maze_escape.peeks_one' : 'maze_escape.peeks_many', {'n': l.peeks});
    final extra = l.maxBumps > 0 ? ' ${tr('maze_escape.bumps_out', {'n': l.maxBumps})}' : '';
    return '${tr('maze_escape.mem_blurb', {'a': a, 'b': b, 's': MemLevel.baseSeconds(t)})} $peeks$extra';
  }
  final a = LabLevel.of(t, 1).size, b = LabLevel.of(t, kLevelCount).size;
  return tr('maze_escape.blurb.${t.name}', {'a': a, 'b': b});
}

int _levelSize(MazeMode mode, MazeTier t, int level) =>
    mode == MazeMode.memory ? MemLevel.of(t, level).size : LabLevel.of(t, level).size;

// ---------------------------------------------------------------------------
// Mode menu
// ---------------------------------------------------------------------------

class _ModeMenu extends StatefulWidget {
  const _ModeMenu();

  @override
  State<_ModeMenu> createState() => _ModeMenuState();
}

class _ModeMenuState extends State<_ModeMenu> {
  @override
  Widget build(BuildContext context) {
    final last = MazeProgress.lastMode;
    return GameScaffold(
      title: tr('maze_escape.title'),
      tint: kMazeTint,
      body: ValueListenableBuilder<int>(
        valueListenable: MazeProgress.tick,
        builder: (context, _, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(tr('maze_escape.intro'),
                style: const TextStyle(color: Pal.textDim, fontSize: 15, height: 1.4)),
            const SizedBox(height: 18),
            _hero(
              context,
              MazeMode.labyrinth,
              icon: Icons.route_rounded,
              tagline: tr('maze_escape.tagline.labyrinth'),
              isLast: last == MazeMode.labyrinth,
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
            const SizedBox(height: 16),
            _hero(
              context,
              MazeMode.memory,
              icon: Icons.psychology_rounded,
              tagline: tr('maze_escape.tagline.memory'),
              isLast: last == MazeMode.memory,
              isNew: MazeProgress.modeStars(MazeMode.memory) == 0,
            ).animate().fadeIn(delay: 120.ms, duration: 350.ms).slideY(begin: 0.08, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, MazeMode mode,
      {required IconData icon, required String tagline, bool isLast = false, bool isNew = false}) {
    final c = _modeColor(mode);
    final stars = MazeProgress.modeStars(mode);
    final max = MazeProgress.modeMaxStars();
    return GlassCard(
      key: ValueKey('mode-${mode.name}'),
      glow: isLast ? c : null,
      radius: 28,
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c.withValues(alpha: 0.55), c.withValues(alpha: 0.10)],
      ),
      onTap: () {
        MazeProgress.lastMode = mode;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => _TierSelect(mode: mode))).then((_) {
          if (mounted) setState(() {});
        });
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.withValues(alpha: 0.25),
              border: Border.all(color: c, width: 2),
              boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 18, spreadRadius: -4)],
            ),
            child: Icon(icon, color: Pal.text, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(mazeModeLabel(mode), style: const TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w900)),
                if (isNew) _badge(tr('maze_escape.badge_new'), Pal.gold) else if (isLast) _badge(tr('common.last_played').toUpperCase(), c),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.star_rounded, color: Pal.gold, size: 18),
                const SizedBox(width: 4),
                Text('$stars / $max',
                    style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w800, fontSize: 14)),
              ]),
            ]),
          ),
          const Icon(Icons.arrow_forward_rounded, color: Pal.text),
        ]),
        const SizedBox(height: 14),
        Text(tagline, style: const TextStyle(color: Pal.textDim, fontSize: 13.5, height: 1.35)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: max == 0 ? 0 : stars / max,
            minHeight: 6,
            backgroundColor: Colors.black.withValues(alpha: 0.25),
            valueColor: AlwaysStoppedAnimation(c),
          ),
        ),
      ]),
    );
  }

  Widget _badge(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: c)),
        child: Text(t, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
      );
}

// ---------------------------------------------------------------------------
// Tier select (shared by both modes)
// ---------------------------------------------------------------------------

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
    final last = MazeProgress.lastTierOf(mode);
    return GameScaffold(
      title: mazeModeLabel(mode),
      tint: _modeColor(mode),
      body: ValueListenableBuilder<int>(
        valueListenable: MazeProgress.tick,
        builder: (context, _, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              tr('maze_escape.sub.${mode.name}'),
              style: const TextStyle(color: Pal.textDim, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 14),
            Text(tr('maze_escape.choose_difficulty'), style: const TextStyle(color: Pal.textDim, fontSize: 15)),
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
    final mode = widget.mode;
    final c = _tierColor[t]!;
    final stars = MazeProgress.totalStars(t, mode: mode);
    final done = MazeProgress.completed(t, mode: mode);
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
        MazeProgress.setLastTier(mode, t);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => _LevelSelect(tier: t, mode: mode))).then((_) {
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
              Flexible(
                child: Text(mazeTierLabel(t),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              if (isLast) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(tr('common.last_played').toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Text(_tierBlurb(mode, t), style: const TextStyle(color: Pal.textDim, fontSize: 12.5, height: 1.3)),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded, color: Pal.gold, size: 16),
                const SizedBox(width: 3),
                Text('$stars / ${kLevelCount * 3}', style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w800, fontSize: 12.5)),
              ]),
              Text('$done / $kLevelCount', style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ]),
          ]),
        ),
        const Icon(Icons.arrow_forward_rounded, color: Pal.text),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Level grid (shared by both modes)
// ---------------------------------------------------------------------------

class _LevelSelect extends StatelessWidget {
  const _LevelSelect({required this.tier, required this.mode});
  final MazeTier tier;
  final MazeMode mode;

  @override
  Widget build(BuildContext context) {
    final color = _modeColor(mode);
    return GameScaffold(
      title: tr('maze_escape.grid_title', {'mode': mazeModeLabel(mode), 'tier': mazeTierLabel(tier)}),
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
            final free = MazeProgress.unlocked(tier, level, mode: mode);
            final plays = free ? 0 : MazeProgress.playsLeft(tier, level, mode: mode);
            final open = free || plays > 0;
            final stars = MazeProgress.stars(tier, level, mode: mode);
            final size = _levelSize(mode, tier, level);
            return Opacity(
              key: ValueKey('maze-level-$level'),
              opacity: open ? 1 : 0.7,
              child: GlassCard(
                blur: 0,
                radius: 20,
                padding: const EdgeInsets.all(8),
                glow: stars > 0 ? color : (plays > 0 ? Pal.gold : null),
                onTap: open
                    ? () => openMazeLevel(context, tier, level, mode: mode)
                    : () => buyMazeLevel(context, tier, level, mode: mode),
                child: Stack(fit: StackFit.expand, children: [
                  FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (plays > 0) _boughtBadge(),
                    Text('$level',
                        style: TextStyle(color: open ? Pal.text : Pal.textDim, fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('${size}x$size', style: const TextStyle(color: Pal.textDim, fontSize: 11)),
                    const SizedBox(height: 4),
                    if (plays > 0)
                      Text(tr('common.skip.plays_left', {'n': plays}),
                          style: const TextStyle(color: Pal.gold, fontSize: 11, fontWeight: FontWeight.w800))
                    else
                      StarRow(stars: stars, size: 14),
                  ]),
                  ),
                  if (!open)
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(Icons.lock_rounded, size: 12, color: Pal.textDim),
                    ),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

Widget _boughtBadge() => Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
          color: Pal.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Pal.gold)),
      child: Text(tr('maze_escape.bought'),
          style: const TextStyle(color: Pal.gold, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
    );
